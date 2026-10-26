package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test

class StreamingRemoteSessionTest {
    private val owner = StreamingRemoteIdentity("run", "binding-1")

    @Test fun nonfinalFinishReplyCannotClaimCompletionOrRelease() {
        val tasks = ArrayDeque<Runnable>()
        val failures = mutableListOf<StreamingStopCause>()
        val client = StreamingRemoteSession(owner, {}, Executor { tasks.add(it) }, failures::add)
        client.startRemote("a".repeat(64)); tasks.removeFirst().run()
        client.receiveRemote(StreamingRemoteReply.Ready(owner))
        val finish = requireNotNull(client.finishRemoteUtterance())
        tasks.removeFirst().run()
        client.receiveRemote(StreamingRemoteReply.Text(owner, 0, "not final", false))
        assertEquals(listOf(StreamingStopCause.ENGINE), failures)
        assertFalse(finish.toCompletableFuture().isDone)
        assertFalse(client.releaseAcknowledgement.toCompletableFuture().isDone)
        client.receiveRemote(StreamingRemoteReply.Released(owner))
        assertEquals(StreamingRemoteResult.Failed(StreamingStopCause.ENGINE), finish.toCompletableFuture().get())
        assertTrue(client.releaseAcknowledgement.toCompletableFuture().isDone)
    }

    @Test fun finishReservesAdmissionUntilMatchingFinalReply() {
        val tasks = ArrayDeque<Runnable>()
        val sent = mutableListOf<StreamingRemoteCommand>()
        val client = StreamingRemoteSession(owner, { sent.add(it) }, Executor { tasks.add(it) })
        assertNull(client.finishRemoteUtterance())
        client.startRemote("a".repeat(64)); tasks.removeFirst().run()
        client.receiveRemote(StreamingRemoteReply.Ready(owner))
        val finish = client.finishRemoteUtterance()
        assertNotNull("finish must acquire the sole operation slot", finish)
        finish!!
        tasks.removeFirst().run()
        assertEquals(StreamingRemoteCommand.Finish(owner, 0), sent.last())
        assertNull(client.pendingFrame) // Flush padding is not unique captured audio.
        assertNull(client.finishRemoteUtterance())
        assertNull(client.submitRemote(PcmCaptureFrame(0, ByteArray(2), 0)))
        assertFalse(finish.toCompletableFuture().isDone)
        client.receiveRemote(StreamingRemoteReply.Text(owner.copy(epoch = "old"), 0, "stale", true))
        client.receiveRemote(StreamingRemoteReply.Text(owner, 1, "wrong request", true))
        assertFalse(finish.toCompletableFuture().isDone)
        client.receiveRemote(StreamingRemoteReply.Text(owner, 0, "尾部 API", true))
        assertEquals(StreamingRemoteResult.Text("尾部 API", true), finish.toCompletableFuture().get())
        val pcm = client.submitRemote(PcmCaptureFrame(0, ByteArray(2), 100, 1))
        assertNotNull(pcm)
        tasks.removeFirst().run()
        assertEquals(1L, (sent.last() as StreamingRemoteCommand.Pcm).requestId)
        assertNull(client.finishRemoteUtterance())
        client.remoteProcessDied()
    }

    @Test fun closingDuringFinishCannotPublishLateFinal() {
        for (dies in listOf(false, true)) {
            val tasks = ArrayDeque<Runnable>()
            val client = StreamingRemoteSession(owner, {}, Executor { tasks.add(it) })
            client.startRemote("a".repeat(64)); tasks.removeFirst().run()
            client.receiveRemote(StreamingRemoteReply.Ready(owner))
            val finish = client.finishRemoteUtterance()
            assertNotNull("finish must be admitted before close", finish)
            finish!!
            tasks.removeFirst().run()
            val release = client.closeRemote()
            assertFalse(release.toCompletableFuture().isDone)
            client.receiveRemote(StreamingRemoteReply.Text(owner, 0, "late", true))
            assertEquals(StreamingRemoteResult.Cancelled, finish.toCompletableFuture().get())
            assertFalse(release.toCompletableFuture().isDone)
            if (dies) client.remoteProcessDied()
            else client.receiveRemote(StreamingRemoteReply.Released(owner))
            assertTrue(release.toCompletableFuture().isDone)
            assertNull(client.finishRemoteUtterance())
        }
    }

    @Test fun explicitRejectionSettlesOnlyTheNeverAdoptedOwner() {
        val tasks = ArrayDeque<Runnable>()
        val failures = mutableListOf<StreamingStopCause>()
        val client = StreamingRemoteSession(owner, {}, Executor { tasks.add(it) }, failures::add)
        client.startRemote("a".repeat(64)); tasks.removeFirst().run()
        client.receiveRemote(StreamingRemoteReply.Rejected(owner, StreamingStopCause.ENGINE))
        assertTrue("positive no-adoption acknowledgement releases the rejected binding", client.closeRemote().toCompletableFuture().isDone)
        assertEquals(listOf(StreamingStopCause.ENGINE), failures)
        val active = StreamingRemoteSession(owner, {}, Executor { tasks.add(it) })
        active.startRemote("a".repeat(64)); tasks.removeFirst().run()
        active.receiveRemote(StreamingRemoteReply.Ready(owner))
        val pending = requireNotNull(active.submitRemote(PcmCaptureFrame(0, ByteArray(640), 0)))
        tasks.removeFirst().run()
        active.receiveRemote(StreamingRemoteReply.Rejected(owner, StreamingStopCause.ENGINE))
        assertFalse(pending.toCompletableFuture().isDone)
        assertNotNull(active.pendingFrame)
        assertFalse(active.closeRemote().toCompletableFuture().isDone)
        active.remoteProcessDied()
    }

    @Test fun transportFailureBeforeOpenCannotInventRemoteOwnership() {
        val tasks = ArrayDeque<Runnable>()
        val failures = mutableListOf<StreamingStopCause>()
        val client = StreamingRemoteSession(owner, {}, Executor { tasks.add(it) }, failures::add)
        client.remoteTransportFailed()
        assertTrue("without an admitted Open there is no native resource to await", client.closeRemote().toCompletableFuture().isDone)
        assertTrue(tasks.isEmpty())
        assertEquals(listOf(StreamingStopCause.ENGINE), failures)
        client.startRemote("a".repeat(64))
        assertTrue(tasks.isEmpty())
    }

    @Test fun releaseAcknowledgementPrecedesPendingResultCallbacks() {
        val delivery = Executors.newSingleThreadExecutor()
        try {
            for (processDeath in listOf(false, true)) {
                val tasks = ArrayDeque<Runnable>()
                val client = StreamingRemoteSession(owner, {}, Executor { tasks.add(it) })
                client.startRemote("a".repeat(64)); tasks.removeFirst().run()
                client.receiveRemote(StreamingRemoteReply.Ready(owner))
                val pending = requireNotNull(client.submitRemote(PcmCaptureFrame(0, ByteArray(640), 0)))
                tasks.removeFirst().run()
                val release = client.closeRemote()
                val callback = pending.thenAccept {
                    // Resource acknowledgement must not depend on this consumer returning.
                    release.toCompletableFuture().get(200, TimeUnit.MILLISECONDS)
                }
                delivery.submit {
                    if (processDeath) client.remoteProcessDied()
                    else client.receiveRemote(StreamingRemoteReply.Released(owner))
                }.get(2, TimeUnit.SECONDS)
                callback.toCompletableFuture().get(2, TimeUnit.SECONDS)
                assertTrue(release.toCompletableFuture().isDone)
            }
        } finally { delivery.shutdownNow() }
    }

    @Test fun sentPcmRemainsPendingUntilMatchingReply() {
        val tasks = ArrayDeque<Runnable>()
        val sent = mutableListOf<StreamingRemoteCommand>()
        val client = StreamingRemoteSession(owner, { sent.add(it) }, Executor { tasks.add(it) })
        client.startRemote("a".repeat(64))
        assertFalse("opening must dispatch a remote request", tasks.isEmpty())
        tasks.removeFirst().run()
        assertTrue(sent.single() is StreamingRemoteCommand.Open)
        val frame = PcmCaptureFrame(17, ByteArray(640), 1200, 3)
        assertNull(client.submitRemote(frame))
        client.receiveRemote(StreamingRemoteReply.Ready(owner))
        val result = requireNotNull(client.submitRemote(frame))
        tasks.removeFirst().run()
        val command = sent.last() as StreamingRemoteCommand.Pcm
        assertEquals(1200L, client.pendingFrame?.canonicalStartSample)
        assertEquals(1520L, client.pendingFrame?.canonicalEndSampleExclusive)
        assertNull(client.submitRemote(frame))
        assertFalse(result.toCompletableFuture().isDone)
        result.toCompletableFuture().complete(StreamingRemoteResult.Cancelled)
        assertFalse(result.toCompletableFuture().isDone)
        client.receiveRemote(StreamingRemoteReply.Text(owner, command.requestId + 1, "wrong", false))
        assertFalse(result.toCompletableFuture().isDone)
        client.receiveRemote(StreamingRemoteReply.Text(owner, command.requestId, "你好", false))
        assertEquals(StreamingRemoteResult.Text("你好", false), result.toCompletableFuture().get())
        assertNull(client.pendingFrame)
    }

    @Test fun closureSuppressesLateTextAndWaitsForRelease() {
        val tasks = ArrayDeque<Runnable>()
        val sent = mutableListOf<StreamingRemoteCommand>()
        val client = StreamingRemoteSession(owner, { sent.add(it) }, Executor { tasks.add(it) })
        client.startRemote("a".repeat(64)); assertFalse("opening must dispatch", tasks.isEmpty()); tasks.removeFirst().run()
        client.receiveRemote(StreamingRemoteReply.Ready(owner))
        val result = requireNotNull(client.submitRemote(PcmCaptureFrame(0, ByteArray(640), 0)))
        tasks.removeFirst().run()
        val id = (sent.last() as StreamingRemoteCommand.Pcm).requestId
        val released = client.closeRemote()
        assertFalse(released.toCompletableFuture().isDone)
        assertNotNull(client.pendingFrame)
        tasks.removeFirst().run()
        assertTrue(sent.last() is StreamingRemoteCommand.Close)
        client.receiveRemote(StreamingRemoteReply.Text(owner, id, "late", true))
        assertEquals(StreamingRemoteResult.Cancelled, result.toCompletableFuture().get())
        assertFalse(released.toCompletableFuture().isDone)
        assertSame(released, client.closeRemote())
        client.receiveRemote(StreamingRemoteReply.Released(owner))
        assertTrue(released.toCompletableFuture().isDone)
        assertNull(client.submitRemote(PcmCaptureFrame(1, ByteArray(2), 320)))
    }

    @Test fun processDeathSettlesOutstandingWorkExactlyOnce() {
        val tasks = ArrayDeque<Runnable>()
        val failures = mutableListOf<StreamingStopCause>()
        val client = StreamingRemoteSession(owner, {}, Executor { tasks.add(it) }, failures::add)
        client.startRemote("a".repeat(64)); assertFalse("opening must dispatch", tasks.isEmpty()); tasks.removeFirst().run()
        client.receiveRemote(StreamingRemoteReply.Ready(owner))
        val result = requireNotNull(client.submitRemote(PcmCaptureFrame(0, ByteArray(640), 0)))
        tasks.removeFirst().run()
        client.remoteProcessDied(); client.remoteProcessDied()
        assertEquals(listOf(StreamingStopCause.ENGINE), failures)
        assertEquals(StreamingRemoteResult.Failed(StreamingStopCause.ENGINE), result.toCompletableFuture().get())
        assertNull(client.pendingFrame)
        assertTrue(client.closeRemote().toCompletableFuture().isDone)
        client.receiveRemote(StreamingRemoteReply.Ready(owner))
        assertNull(client.submitRemote(PcmCaptureFrame(1, ByteArray(2), 320)))
    }

    @Test fun sendFailureDoesNotPretendRemoteResourcesWereReleased() {
        val tasks = ArrayDeque<Runnable>()
        val failures = mutableListOf<StreamingStopCause>()
        var broken = false
        val client = StreamingRemoteSession(owner, { if (broken) error("ambiguous transport failure") }, Executor { tasks.add(it) }, failures::add)
        client.startRemote("a".repeat(64)); assertFalse("opening must dispatch", tasks.isEmpty()); tasks.removeFirst().run()
        client.receiveRemote(StreamingRemoteReply.Ready(owner))
        val result = requireNotNull(client.submitRemote(PcmCaptureFrame(0, ByteArray(640), 0)))
        broken = true; tasks.removeFirst().run()
        assertEquals(listOf(StreamingStopCause.ENGINE), failures)
        assertNotNull(client.pendingFrame)
        assertFalse(result.toCompletableFuture().isDone)
        assertFalse(client.closeRemote().toCompletableFuture().isDone)
        client.remoteProcessDied()
        assertTrue(client.closeRemote().toCompletableFuture().isDone)
        assertEquals(StreamingRemoteResult.Failed(StreamingStopCause.ENGINE), result.toCompletableFuture().get())
        // Dispatcher rejection is equally ambiguous; never acknowledge release.
        val rejected = StreamingRemoteSession(owner, {}, Executor { throw RejectedExecutionException() })
        rejected.startRemote("a".repeat(64))
        assertFalse(rejected.closeRemote().toCompletableFuture().isDone)
        rejected.remoteProcessDied()
        assertTrue(rejected.closeRemote().toCompletableFuture().isDone)
    }

    @Test fun staleAndDuplicateRepliesCannotSettleAnotherOwner() {
        val tasks = ArrayDeque<Runnable>()
        val sent = mutableListOf<StreamingRemoteCommand>()
        val client = StreamingRemoteSession(owner, { sent.add(it) }, Executor { tasks.add(it) })
        client.startRemote("a".repeat(64)); assertFalse("opening must dispatch", tasks.isEmpty()); tasks.removeFirst().run()
        val stale = owner.copy(epoch = "binding-old")
        client.receiveRemote(StreamingRemoteReply.Ready(stale))
        val frame = PcmCaptureFrame(0, ByteArray(640), 0)
        assertNull(client.submitRemote(frame))
        client.receiveRemote(StreamingRemoteReply.Ready(owner))
        val result = requireNotNull(client.submitRemote(frame))
        tasks.removeFirst().run()
        val id = (sent.last() as StreamingRemoteCommand.Pcm).requestId
        client.receiveRemote(StreamingRemoteReply.Text(stale, id, "stale", true))
        client.receiveRemote(StreamingRemoteReply.Released(owner)) // unsolicited release is not a close acknowledgement
        assertNotNull(client.pendingFrame)
        assertFalse(result.toCompletableFuture().isDone)
        client.receiveRemote(StreamingRemoteReply.Text(owner, id, "ok", true))
        client.receiveRemote(StreamingRemoteReply.Text(owner, id, "duplicate", false))
        assertEquals(StreamingRemoteResult.Text("ok", true), result.toCompletableFuture().get())
        val closing = client.closeRemote()
        client.receiveRemote(StreamingRemoteReply.Released(stale))
        assertFalse(closing.toCompletableFuture().isDone)
        client.receiveRemote(StreamingRemoteReply.Released(owner))
        assertTrue(closing.toCompletableFuture().isDone)
    }
}
