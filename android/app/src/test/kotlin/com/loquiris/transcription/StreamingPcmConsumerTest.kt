package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.*
import org.junit.Test

class StreamingPcmConsumerTest {
    private val owner = StreamingRemoteIdentity("meeting-run", "owner-1")

    @Test fun gapFlushesOldTextBeforeAdmittingNewCaptureEpoch() {
        val kernel = Kernel()
        Harness(kernel).use { h ->
            val events = mutableListOf<StreamingCaptureEvent>()
            val consumer = StreamingPcmConsumer(h.remote, { events.addAll(it) })
            consumer.consume(frame(0, 0))
            consumer.consume(frame(1, 6400, 1))
            assertEquals(listOf(
                StreamingCaptureText(owner, 0, "utterance-1", 0, 3200, 0, "first", false),
                StreamingCaptureText(owner, 1, "utterance-1", 0, 3200, 0, "尾部 API", true),
                StreamingCaptureGap(owner, 2, 3200, 6400, 1, StreamingBoundaryReason.DISCONTINUITY),
                StreamingCaptureText(owner, 3, "utterance-2", 6400, 9600, 1, "first", false)), events)
            assertEquals(listOf("decode:0", "finish", "decode:1"), kernel.operations)
            consumer.closeAsync().toCompletableFuture().get(2, TimeUnit.SECONDS)
            assertEquals(1, kernel.closes.get())
        }
    }

    @Test fun explicitPausePreservesZeroLengthEpochBoundary() {
        Harness(Kernel()).use { h ->
            val events = mutableListOf<StreamingCaptureEvent>()
            val consumer = StreamingPcmConsumer(h.remote, { events.addAll(it) })
            consumer.consume(frame(0, 0))
            consumer.finishBoundary(StreamingBoundaryReason.PAUSE)
            consumer.consume(frame(1, 3200, 1))
            assertEquals(4, events.size)
            assertEquals(StreamingCaptureGap(owner, 2, 3200, 3200, 1, StreamingBoundaryReason.PAUSE), events[2])
            assertEquals("utterance-2", (events[3] as StreamingCaptureText).utteranceId)
            consumer.closeAsync().toCompletableFuture().get(2, TimeUnit.SECONDS)
        }
    }

    @Test fun stopFlushesButCancellationNeverInventsFinalText() {
        for (stop in listOf(false, true)) {
            val kernel = Kernel()
            Harness(kernel).use { h ->
                val events = mutableListOf<StreamingCaptureEvent>()
                val consumer = StreamingPcmConsumer(h.remote, { events.addAll(it) })
                consumer.consume(frame(0, 0))
                if (stop) consumer.finishBoundary(StreamingBoundaryReason.STOP)
                consumer.closeAsync().toCompletableFuture().get(2, TimeUnit.SECONDS)
                consumer.consume(frame(1, 3200))
                assertEquals(if (stop) listOf(false, true) else listOf(false),
                    events.filterIsInstance<StreamingCaptureText>().map { it.finalized })
                assertEquals(if (stop) listOf("decode:0", "finish") else listOf("decode:0"), kernel.operations)
                assertEquals(1, kernel.closes.get())
            }
        }
    }

    @Test fun rejectedCoordinatesDegradeBeforeMoreRemoteInference() {
        for (badFrame in listOf(PcmCaptureFrame(1, ByteArray(6400)), frame(1, 3199), frame(1, 3200, 0))) {
            val kernel = Kernel()
            Harness(kernel).use { h ->
                val events = mutableListOf<StreamingCaptureEvent>()
                val failures = mutableListOf<StreamingStopCause>()
                val consumer = StreamingPcmConsumer(h.remote, { events.addAll(it) }, failures::add)
                consumer.consume(frame(0, 0, 1))
                consumer.consume(badFrame)
                consumer.closeAsync().toCompletableFuture().get(2, TimeUnit.SECONDS)
                assertEquals(listOf(StreamingStopCause.INVALID_PCM), failures)
                assertEquals(StreamingStopCause.INVALID_PCM, consumer.stopCause)
                assertEquals(1, events.size)
                assertEquals(listOf("decode:0"), kernel.operations)
                assertEquals(1, kernel.closes.get())
            }
        }
    }

    @Test fun memoryFailureRetainsPriorDraftAndReportsTypedCause() {
        val kernel = Kernel(decode = { if (it.sequence == 1L) throw OutOfMemoryError("native")
            StreamingRemoteResult.Text("first", false) })
        Harness(kernel).use { h ->
            val events = mutableListOf<StreamingCaptureEvent>()
            val failures = mutableListOf<StreamingStopCause>()
            val consumer = StreamingPcmConsumer(h.remote, { events.addAll(it) }, failures::add)
            consumer.consume(frame(0, 0))
            consumer.consume(frame(1, 3200))
            consumer.closeAsync().toCompletableFuture().get(2, TimeUnit.SECONDS)
            assertEquals(listOf(StreamingStopCause.MEMORY), failures)
            assertEquals(listOf("first"), events.filterIsInstance<StreamingCaptureText>().map { it.rawText })
            assertEquals(1, kernel.closes.get())
        }
    }

    @Test fun inFlightDecodeCannotBeReleasedOrPublishedByCloseRequest() {
        val entered = CountDownLatch(1)
        val exit = CountDownLatch(1)
        val kernel = Kernel(decode = {
            entered.countDown(); check(exit.await(3, TimeUnit.SECONDS))
            StreamingRemoteResult.Text("late", true)
        })
        Harness(kernel).use { h ->
            val executor = Executors.newSingleThreadExecutor()
            val events = CopyOnWriteArrayList<StreamingCaptureEvent>()
            val consumer = StreamingPcmConsumer(h.remote, { events.addAll(it) })
            try {
                val consuming = executor.submit { consumer.consume(frame(0, 0)) }
                assertTrue(entered.await(2, TimeUnit.SECONDS))
                val ack = consumer.closeAsync().toCompletableFuture()
                assertFalse(ack.isDone)
                assertEquals(0, kernel.closes.get())
                exit.countDown()
                ack.get(2, TimeUnit.SECONDS); consuming.get(2, TimeUnit.SECONDS)
                assertEquals(1, kernel.closes.get())
                assertTrue(events.isEmpty())
            } finally { exit.countDown(); executor.shutdownNow() }
        }
    }

    @Test fun publicationCannotBlockCloseRequestOrOutliveAcknowledgement() {
        val entered = CountDownLatch(1)
        val exit = CountDownLatch(1)
        val kernel = Kernel()
        Harness(kernel).use { h ->
            val executor = Executors.newFixedThreadPool(2)
            val consumer = StreamingPcmConsumer(h.remote, {
                entered.countDown(); check(exit.await(3, TimeUnit.SECONDS))
            })
            try {
                val consuming = executor.submit { consumer.consume(frame(0, 0)) }
                assertTrue(entered.await(2, TimeUnit.SECONDS))
                val ack = executor.submit<java.util.concurrent.CompletionStage<Unit>> { consumer.closeAsync() }
                    .get(300, TimeUnit.MILLISECONDS).toCompletableFuture()
                assertTrue(kernel.closed.await(2, TimeUnit.SECONDS))
                assertFalse("publication still owns a callback lease", ack.isDone)
                exit.countDown(); consuming.get(2, TimeUnit.SECONDS); ack.get(2, TimeUnit.SECONDS)
                assertEquals(1, kernel.closes.get())
            } finally { exit.countDown(); executor.shutdownNow() }
        }
    }

    @Test fun listenerFailureCannotPreventNativeRelease() {
        val kernel = Kernel()
        Harness(kernel).use { h ->
            val consumer = StreamingPcmConsumer(h.remote, { error("delivery failed") }, { error("notification failed") })
            consumer.consume(frame(0, 0))
            consumer.closeAsync().toCompletableFuture().get(2, TimeUnit.SECONDS)
            assertEquals(StreamingStopCause.ENGINE, consumer.stopCause)
            assertEquals(1, kernel.closes.get())
        }
    }

    @Test fun degradationNotificationMustDrainBeforeReleaseAcknowledgement() {
        val entered = CountDownLatch(1)
        val exit = CountDownLatch(1)
        val kernel = Kernel()
        Harness(kernel).use { h ->
            val executor = Executors.newSingleThreadExecutor()
            lateinit var consumer: StreamingPcmConsumer
            consumer = StreamingPcmConsumer(h.remote, { error("no text expected") }, {
                // Reentrant close requests are safe; waiting here would wait on this callback.
                consumer.closeAsync()
                entered.countDown(); check(exit.await(3, TimeUnit.SECONDS))
            })
            try {
                val degrading = executor.submit { consumer.degrade(StreamingStopCause.THERMAL) }
                assertTrue(entered.await(2, TimeUnit.SECONDS))
                assertTrue(kernel.closed.await(2, TimeUnit.SECONDS))
                val copy = consumer.closeAsync().toCompletableFuture()
                copy.complete(Unit) // A caller cannot forge the real release acknowledgement.
                val ack = consumer.closeAsync().toCompletableFuture()
                assertFalse("degradation callback still owns a publication lease", ack.isDone)
                exit.countDown(); degrading.get(2, TimeUnit.SECONDS); ack.get(2, TimeUnit.SECONDS)
                assertEquals(StreamingStopCause.THERMAL, consumer.stopCause)
                assertEquals(1, kernel.closes.get())
            } finally { exit.countDown(); executor.shutdownNow() }
        }
    }

    private fun frame(sequence: Long, start: Long, epoch: Long = 0) =
        PcmCaptureFrame(sequence, ByteArray(6400), start, epoch)

    private class Kernel(
        val decode: (PcmCaptureFrame) -> StreamingRemoteResult.Text = { StreamingRemoteResult.Text("first", false) },
    ) : StreamingRemoteKernel {
        val operations = CopyOnWriteArrayList<String>()
        val closes = AtomicInteger()
        val closed = CountDownLatch(1)
        override fun decode(frame: PcmCaptureFrame): StreamingRemoteResult.Text {
            operations.add("decode:${frame.sequence}"); return decode.invoke(frame)
        }
        override fun finishUtterance(): StreamingRemoteResult.Text {
            operations.add("finish"); return StreamingRemoteResult.Text("尾部 API", true)
        }
        override fun close() { closes.incrementAndGet(); closed.countDown() }
    }

    private inner class Harness(kernel: StreamingRemoteKernel) : AutoCloseable {
        private val inference = Executors.newSingleThreadExecutor()
        private val cleanup = Executors.newSingleThreadExecutor()
        private val outbound = Executors.newSingleThreadExecutor()
        private val ready = CountDownLatch(1)
        private val worker: StreamingRemoteWorker
        val remote: StreamingRemoteSession
        init {
            lateinit var client: StreamingRemoteSession
            worker = StreamingRemoteWorker(inference, cleanup, { kernel }, {
                client.receiveRemote(it)
                if (it is StreamingRemoteReply.Ready) ready.countDown()
            })
            client = StreamingRemoteSession(owner, StreamingRemoteTransport(worker::handleRemoteCommand), outbound)
            remote = client
            remote.startRemote("a".repeat(64))
            check(ready.await(2, TimeUnit.SECONDS))
        }
        override fun close() {
            try { remote.closeRemote().toCompletableFuture().get(2, TimeUnit.SECONDS) }
            finally { outbound.shutdownNow(); inference.shutdownNow(); cleanup.shutdownNow() }
        }
    }
}
