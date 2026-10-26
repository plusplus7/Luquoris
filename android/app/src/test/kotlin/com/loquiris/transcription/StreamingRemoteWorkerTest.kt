package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.*
import org.junit.Test

class StreamingRemoteWorkerTest {
    private val identity = StreamingRemoteIdentity("run", "binding-1")

    @Test fun nonfinalKernelFinishIsAnEngineFailure() {
        val tasks = ArrayDeque<Runnable>()
        val replies = mutableListOf<StreamingRemoteReply>()
        val closes = AtomicInteger()
        val worker = StreamingRemoteWorker(Executor { tasks.add(it) }, Executor { tasks.add(it) }, {
            object : StreamingRemoteKernel {
                override fun decode(frame: PcmCaptureFrame) = error("not used")
                override fun finishUtterance() = StreamingRemoteResult.Text("unfinished", false)
                override fun close() { closes.incrementAndGet() }
            }
        }, replies::add)
        worker.handleRemoteCommand(StreamingRemoteCommand.Open(identity, "a".repeat(64)))
        tasks.removeFirst().run()
        worker.handleRemoteCommand(StreamingRemoteCommand.Finish(identity, 0))
        while (tasks.isNotEmpty()) tasks.removeFirst().run()
        assertFalse(replies.any { it is StreamingRemoteReply.Text })
        assertTrue(replies.contains(StreamingRemoteReply.Failure(identity, StreamingStopCause.ENGINE)))
        assertTrue(replies.last() is StreamingRemoteReply.Released)
        assertEquals(1, closes.get())
    }

    @Test fun finishCannotUseForeignOrRepeatedRequestIdentity() {
        val tasks = ArrayDeque<Runnable>()
        val replies = mutableListOf<StreamingRemoteReply>()
        val finishes = AtomicInteger()
        val worker = StreamingRemoteWorker(Executor { tasks.add(it) }, Executor { tasks.add(it) }, {
            object : StreamingRemoteKernel {
                override fun decode(frame: PcmCaptureFrame) = error("not used")
                override fun finishUtterance(): StreamingRemoteResult.Text {
                    finishes.incrementAndGet()
                    return StreamingRemoteResult.Text("tail", true)
                }
                override fun close() = Unit
            }
        }, replies::add)
        worker.handleRemoteCommand(StreamingRemoteCommand.Open(identity, "a".repeat(64)))
        tasks.removeFirst().run()
        worker.handleRemoteCommand(StreamingRemoteCommand.Finish(identity.copy(epoch = "old"), 0))
        assertTrue(tasks.isEmpty())
        worker.handleRemoteCommand(StreamingRemoteCommand.Finish(identity, 0))
        tasks.removeFirst().run()
        assertEquals(StreamingRemoteReply.Text(identity, 0, "tail", true), replies.last())
        worker.handleRemoteCommand(StreamingRemoteCommand.Finish(identity, 0))
        while (tasks.isNotEmpty()) tasks.removeFirst().run()
        assertEquals(1, finishes.get())
        assertTrue(replies.contains(StreamingRemoteReply.Failure(identity, StreamingStopCause.INVALID_PCM)))
        assertTrue(replies.last() is StreamingRemoteReply.Released)
    }

    @Test fun finishRunsOnInferenceAndCloseWaitsForActualRelease() {
        val inference = Executors.newSingleThreadExecutor()
        val cleanup = Executors.newSingleThreadExecutor()
        val ready = CountDownLatch(1)
        val entered = CountDownLatch(1)
        val finishExit = CountDownLatch(1)
        val released = CountDownLatch(1)
        val closes = AtomicInteger()
        val replies = CopyOnWriteArrayList<StreamingRemoteReply>()
        val worker = StreamingRemoteWorker(inference, cleanup, {
            object : StreamingRemoteKernel {
                override fun decode(frame: PcmCaptureFrame) = error("no PCM in this case")
                override fun finishUtterance(): StreamingRemoteResult.Text {
                    entered.countDown()
                    check(finishExit.await(3, TimeUnit.SECONDS))
                    return StreamingRemoteResult.Text("late tail", true)
                }
                override fun close() { closes.incrementAndGet() }
            }
        }, { replies.add(it); if (it is StreamingRemoteReply.Ready) ready.countDown()
            if (it is StreamingRemoteReply.Released) released.countDown() })
        try {
            worker.handleRemoteCommand(StreamingRemoteCommand.Open(identity, "a".repeat(64)))
            assertTrue(ready.await(1, TimeUnit.SECONDS))
            worker.handleRemoteCommand(StreamingRemoteCommand.Finish(identity, 0))
            assertTrue("finish must execute on the inference worker", entered.await(1, TimeUnit.SECONDS))
            worker.closeRemoteWorker()
            assertEquals(0, closes.get())
            assertFalse(released.await(20, TimeUnit.MILLISECONDS))
            finishExit.countDown()
            assertTrue(released.await(2, TimeUnit.SECONDS))
            assertEquals(1, closes.get())
            assertFalse(replies.any { it is StreamingRemoteReply.Text })
        } finally {
            finishExit.countDown(); worker.closeRemoteWorker()
            inference.shutdownNow(); cleanup.shutdownNow()
        }
    }

    @Test fun ownerAdoptionFailureCannotHideFailedNativeCleanup() {
        for (cleanupFails in listOf(false, true)) {
            val tasks = ArrayDeque<Runnable>()
            val replies = mutableListOf<StreamingRemoteReply>()
            val closes = AtomicInteger()
            val worker = StreamingRemoteWorker(Executor { tasks.add(it) }, Executor { tasks.add(it) }, {
                object : StreamingRemoteKernel {
                    override fun finishUtterance() = error("unexpected finish")
                    override fun decode(frame: PcmCaptureFrame) = error("no inference after adoption failure")
                    override fun close() {
                        closes.incrementAndGet()
                        if (cleanupFails) error("native handle might remain live")
                    }
                }
            }, replies::add, wrapOwner = { _, _ -> throw OutOfMemoryError("owner allocation") })
            worker.handleRemoteCommand(StreamingRemoteCommand.Open(identity, "a".repeat(64)))
            tasks.removeFirst().run()
            assertEquals(1, closes.get())
            assertEquals(StreamingRemoteReply.Failure(identity, StreamingStopCause.MEMORY), replies.first())
            assertEquals(!cleanupFails, replies.any { it is StreamingRemoteReply.Released })
            worker.closeRemoteWorker()
            assertEquals(!cleanupFails, replies.any { it is StreamingRemoteReply.Released })
        }
    }

    @Test fun nextRequestMayArriveDuringPreviousReplyDelivery() {
        val tasks = ArrayDeque<Runnable>()
        val replies = mutableListOf<StreamingRemoteReply>()
        lateinit var worker: StreamingRemoteWorker
        worker = StreamingRemoteWorker(Executor { tasks.add(it) }, Executor { tasks.add(it) }, {
            object : StreamingRemoteKernel {
                override fun decode(frame: PcmCaptureFrame) = StreamingRemoteResult.Text("${frame.sequence}", false)
                override fun finishUtterance() = error("unexpected finish")
                override fun close() = Unit
            }
        }, {
            replies.add(it)
            if (it is StreamingRemoteReply.Text && it.requestId == 0L) {
                // The client can send its next request as soon as it receives the ACK.
                worker.handleRemoteCommand(StreamingRemoteCommand.Pcm(identity, 1, PcmCaptureFrame(1, ByteArray(640), 320)))
            }
        })
        worker.handleRemoteCommand(StreamingRemoteCommand.Open(identity, "a".repeat(64)))
        tasks.removeFirst().run()
        worker.handleRemoteCommand(StreamingRemoteCommand.Pcm(identity, 0, PcmCaptureFrame(0, ByteArray(640), 0)))
        while (tasks.isNotEmpty()) tasks.removeFirst().run()
        assertEquals(listOf("0", "1"), replies.filterIsInstance<StreamingRemoteReply.Text>().map { it.text })
        assertFalse(replies.any { it is StreamingRemoteReply.Failure })
        worker.closeRemoteWorker()
        while (tasks.isNotEmpty()) tasks.removeFirst().run()
    }

    @Test fun closeDuringCreationWaitsForCreatedResourceRelease() {
        val inference = Executors.newSingleThreadExecutor()
        val cleanup = Executors.newSingleThreadExecutor()
        val entered = CountDownLatch(1)
        val createExit = CountDownLatch(1)
        val closed = AtomicInteger()
        val released = CountDownLatch(1)
        val replies = CopyOnWriteArrayList<StreamingRemoteReply>()
        val worker = StreamingRemoteWorker(inference, cleanup, {
            entered.countDown(); check(createExit.await(3, TimeUnit.SECONDS))
            object : StreamingRemoteKernel {
                override fun decode(frame: PcmCaptureFrame) = error("closed-before-ready must never infer")
                override fun finishUtterance() = error("unexpected finish")
                override fun close() { closed.incrementAndGet() }
            }
        }, { replies.add(it); if (it is StreamingRemoteReply.Released) released.countDown() })
        try {
            worker.handleRemoteCommand(StreamingRemoteCommand.Open(identity, "a".repeat(64)))
            assertTrue("creation must start", entered.await(1, TimeUnit.SECONDS))
            worker.handleRemoteCommand(StreamingRemoteCommand.Close(identity))
            assertEquals(0, closed.get())
            assertFalse(released.await(20, TimeUnit.MILLISECONDS))
            createExit.countDown()
            assertTrue(released.await(2, TimeUnit.SECONDS))
            assertEquals(1, closed.get())
            assertFalse(replies.any { it is StreamingRemoteReply.Ready })
            worker.closeRemoteWorker()
            assertEquals(1, closed.get())
        } finally { createExit.countDown(); inference.shutdownNow(); cleanup.shutdownNow() }
    }

    @Test fun closeDuringInferenceKeepsCaptureIndependentAndAcknowledgesActualRelease() {
        val inference = Executors.newSingleThreadExecutor()
        val cleanup = Executors.newSingleThreadExecutor()
        val ready = CountDownLatch(1)
        val entered = CountDownLatch(1)
        val decodeExit = CountDownLatch(1)
        val released = CountDownLatch(1)
        val closed = AtomicInteger()
        val replies = CopyOnWriteArrayList<StreamingRemoteReply>()
        val worker = StreamingRemoteWorker(inference, cleanup, {
            object : StreamingRemoteKernel {
                override fun decode(frame: PcmCaptureFrame): StreamingRemoteResult.Text {
                    entered.countDown(); check(decodeExit.await(3, TimeUnit.SECONDS))
                    return StreamingRemoteResult.Text("must not publish", true)
                }
                override fun finishUtterance() = error("unexpected finish")
                override fun close() { closed.incrementAndGet() }
            }
        }, { replies.add(it); if (it is StreamingRemoteReply.Ready) ready.countDown(); if (it is StreamingRemoteReply.Released) released.countDown() })
        try {
            worker.handleRemoteCommand(StreamingRemoteCommand.Open(identity, "a".repeat(64)))
            assertTrue("creation must acknowledge", ready.await(1, TimeUnit.SECONDS))
            worker.handleRemoteCommand(StreamingRemoteCommand.Pcm(identity, 0, PcmCaptureFrame(0, ByteArray(640), 0)))
            assertTrue(entered.await(1, TimeUnit.SECONDS))
            worker.closeRemoteWorker()
            assertEquals(0, closed.get())
            assertFalse(released.await(20, TimeUnit.MILLISECONDS))
            decodeExit.countDown()
            assertTrue(released.await(2, TimeUnit.SECONDS))
            assertEquals(1, closed.get())
            assertFalse(replies.any { it is StreamingRemoteReply.Text })
        } finally { decodeExit.countDown(); inference.shutdownNow(); cleanup.shutdownNow() }
    }

    @Test fun foreignOwnerCannotDecodeOrReleaseTheActiveKernel() {
        val tasks = ArrayDeque<Runnable>()
        val releases = AtomicInteger()
        val replies = mutableListOf<StreamingRemoteReply>()
        val worker = StreamingRemoteWorker(Executor { tasks.add(it) }, Executor { tasks.add(it) }, {
            object : StreamingRemoteKernel {
                override fun decode(frame: PcmCaptureFrame) = StreamingRemoteResult.Text("ok", false)
                override fun finishUtterance() = error("unexpected finish")
                override fun close() { releases.incrementAndGet() }
            }
        }, replies::add)
        worker.handleRemoteCommand(StreamingRemoteCommand.Open(identity, "a".repeat(64)))
        assertFalse("creation must dispatch", tasks.isEmpty()); tasks.removeFirst().run()
        val other = identity.copy(epoch = "foreign")
        worker.handleRemoteCommand(StreamingRemoteCommand.Close(other))
        worker.handleRemoteCommand(StreamingRemoteCommand.Pcm(other, 4, PcmCaptureFrame(0, ByteArray(640), 0)))
        assertTrue(tasks.isEmpty())
        worker.handleRemoteCommand(StreamingRemoteCommand.Pcm(identity, 4, PcmCaptureFrame(0, ByteArray(640), 0)))
        assertFalse(tasks.isEmpty()); tasks.removeFirst().run()
        assertEquals(StreamingRemoteReply.Text(identity, 4, "ok", false), replies.last())
        worker.handleRemoteCommand(StreamingRemoteCommand.Pcm(identity, 4, PcmCaptureFrame(1, ByteArray(640), 320)))
        // Duplicate request must not execute a second decode.
        assertFalse(replies.last() is StreamingRemoteReply.Text)
        while (tasks.isNotEmpty()) tasks.removeFirst().run()
        assertEquals(1, releases.get())
        assertTrue(replies.last() is StreamingRemoteReply.Released)
    }

    @Test fun failedCreationAndCleanupNeverForgeSuccessfulRelease() {
        val tasks = ArrayDeque<Runnable>()
        val replies = mutableListOf<StreamingRemoteReply>()
        val failedLoad = StreamingRemoteWorker(Executor { tasks.add(it) }, Executor { tasks.add(it) }, { throw OutOfMemoryError("native") }, replies::add)
        failedLoad.handleRemoteCommand(StreamingRemoteCommand.Open(identity, "a".repeat(64)))
        assertFalse("creation must dispatch", tasks.isEmpty()); tasks.removeFirst().run()
        assertEquals(StreamingRemoteReply.Failure(identity, StreamingStopCause.MEMORY), replies.first())
        assertTrue(replies.last() is StreamingRemoteReply.Released) // factory owns its partial cleanup
        replies.clear()
        val failedClose = StreamingRemoteWorker(Executor { tasks.add(it) }, Executor { tasks.add(it) }, {
            object : StreamingRemoteKernel {
                override fun decode(frame: PcmCaptureFrame) = StreamingRemoteResult.Text("ok", false)
                override fun finishUtterance() = error("unexpected finish")
                override fun close() { error("native release failed") }
            }
        }, replies::add)
        failedClose.handleRemoteCommand(StreamingRemoteCommand.Open(identity, "a".repeat(64)))
        tasks.removeFirst().run()
        failedClose.closeRemoteWorker()
        while (tasks.isNotEmpty()) tasks.removeFirst().run()
        assertTrue(replies.last() is StreamingRemoteReply.Failure)
        assertFalse(replies.any { it is StreamingRemoteReply.Released })
    }
}
