package com.loquiris.transcription

import com.loquiris.recording.*
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test

class StreamingRecorderDraftSessionTest {
    @Test fun forwardsFramesAndBoundariesAndSignalsOnlyCompletedStop() {
        val h = Harness()
        assertEquals(LiveDraftStartResult.Started, h.session.start())
        assertEquals(1, h.starts)
        h.session.consume(PcmCaptureFrame(0, ByteArray(640), 0))
        h.session.onCaptureBoundary(PcmCaptureBoundary.PAUSE)
        assertFalse(h.session.stopResult.toCompletableFuture().isDone)
        h.session.onCaptureBoundary(PcmCaptureBoundary.STOP)
        assertEquals(listOf("pcm0", "PAUSE", "STOP"), h.calls)
        assertEquals(PcmInferenceBoundaryResult.completed, h.session.stopResult.toCompletableFuture().get(2, TimeUnit.SECONDS))
        assertEquals(0, h.cancels)
    }

    @Test fun cancelIsImmediateIdempotentAndSuppressesLaterWorkerInput() {
        val h = Harness()
        h.session.start()
        h.session.close(); h.session.close()
        h.session.consume(PcmCaptureFrame(0, ByteArray(640), 0))
        h.session.onCaptureBoundary(PcmCaptureBoundary.STOP)
        assertTrue(h.calls.isEmpty())
        assertEquals(1, h.cancels)
        assertEquals(PcmInferenceBoundaryResult.closed, h.session.stopResult.toCompletableFuture().get(2, TimeUnit.SECONDS))
    }

    @Test fun closeBeforeStartDoesNotAllocateNativeRuntime() {
        val h = Harness()
        h.session.close()
        assertEquals(LiveDraftStartResult.Failure("transcription_live_closed"), h.session.start())
        assertEquals(0, h.starts)
    }

    @Test fun failureNotificationIsFirstCauseOnlyAndAlwaysRequestsCancellation() {
        val h = Harness()
        h.session.onBoundaryRejected(PcmInferenceBoundaryResult.failed)
        h.session.onFailure("later_failure")
        h.session.degrade("later_thermal")
        assertEquals(listOf("transcription_live_boundary_failed"), h.degraded)
        assertEquals(1, h.cancels)
    }

    @Test fun degradedListenerFailureCannotSkipNativeCancellation() {
        var cancels = 0
        val session = StreamingRecorderDraftSession({ LiveDraftStartResult.Started }, { error("no input") },
            { cancels++ }, { error("listener broke") })
        runCatching { session.degrade("thermal") }
        assertEquals(1, cancels)
        assertEquals(PcmInferenceBoundaryResult.closed, session.stopResult.toCompletableFuture().get(2, TimeUnit.SECONDS))
    }

    @Test fun cancelDuringBlockedStopSettlesControlButNeverPretendsStopCompleted() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val input = object : PcmCaptureBoundaryConsumer {
            override fun consume(frame: PcmCaptureFrame) = Unit
            override fun onCaptureBoundary(boundary: PcmCaptureBoundary) { entered.countDown(); check(release.await(2, TimeUnit.SECONDS)) }
            override fun onBoundaryRejected(result: PcmInferenceBoundaryResult) = Unit
        }
        var cancels = 0
        val session = StreamingRecorderDraftSession({ LiveDraftStartResult.Started }, { input }, { cancels++ }, {})
        val worker = Executors.newSingleThreadExecutor()
        try {
            session.start()
            val stop = worker.submit { session.onCaptureBoundary(PcmCaptureBoundary.STOP) }
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            session.close()
            assertEquals(1, cancels)
            assertEquals(PcmInferenceBoundaryResult.closed, session.stopResult.toCompletableFuture().get(2, TimeUnit.SECONDS))
            release.countDown(); stop.get(2, TimeUnit.SECONDS)
            assertEquals(PcmInferenceBoundaryResult.closed, session.stopResult.toCompletableFuture().get())
        } finally { release.countDown(); session.close(); worker.shutdownNow() }
    }

    @Test fun callerCannotForgeStopCompletion() {
        val h = Harness()
        h.session.stopResult.toCompletableFuture().complete(PcmInferenceBoundaryResult.completed)
        assertFalse(h.session.stopResult.toCompletableFuture().isDone)
        h.session.close()
    }

    private class Harness {
        var starts = 0
        var cancels = 0
        val calls = CopyOnWriteArrayList<String>()
        val degraded = CopyOnWriteArrayList<String>()
        private val input = object : PcmCaptureBoundaryConsumer {
            override fun consume(frame: PcmCaptureFrame) { calls.add("pcm${frame.sequence}") }
            override fun onCaptureBoundary(boundary: PcmCaptureBoundary) { calls.add(boundary.name) }
            override fun onBoundaryRejected(result: PcmInferenceBoundaryResult) = Unit
        }
        val session = StreamingRecorderDraftSession({ starts++; LiveDraftStartResult.Started }, { input }, { cancels++ }, degraded::add)
    }
}
