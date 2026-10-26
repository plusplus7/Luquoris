package com.loquiris.transcription

import java.util.concurrent.CompletableFuture
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test

class StreamingMicrophoneProbeOwnerTest {
    @Test fun cancellationUpgradesPendingStopAndInterruptsInference() {
        val entered = CountDownLatch(1)
        val stopObserved = CountDownLatch(1)
        val observeCancel = CountDownLatch(1)
        val cancelledObserved = CountDownLatch(1)
        val inferenceClose = CountDownLatch(1)
        val ack = CompletableFuture<Unit>()
        val owner = StreamingMicrophoneProbeOwner({ it(null) }, { wait, cancelled, stopped ->
            entered.countDown()
            wait(60000)
            assertTrue(stopped())
            stopObserved.countDown()
            assertTrue(observeCancel.await(2, TimeUnit.SECONDS))
            assertTrue(cancelled())
            assertFalse(stopped())
            cancelledObserved.countDown()
            report(StreamingMicrophoneProbeStatus.CANCELLED)
        }, { inferenceClose.countDown(); ack }, { CompletableFuture.completedFuture(Unit) }, {}, {})
        try {
            owner.start()
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            owner.close(StreamingPlatformCloseReason.STOPPED)
            assertTrue(stopObserved.await(2, TimeUnit.SECONDS))
            val cancelled = owner.close(StreamingPlatformCloseReason.CANCELLED).toCompletableFuture()
            observeCancel.countDown()
            assertTrue(inferenceClose.await(2, TimeUnit.SECONDS))
            assertTrue(cancelledObserved.await(2, TimeUnit.SECONDS))
            assertFalse(cancelled.isDone)
            ack.complete(Unit)
            cancelled.get(2, TimeUnit.SECONDS)
        } finally { observeCancel.countDown(); ack.complete(Unit); owner.close(StreamingPlatformCloseReason.CANCELLED) }
    }

    @Test fun cancelWakesWindowButCannotForgeNativeRelease() {
        val entered = CountDownLatch(1)
        val ended = CountDownLatch(1)
        val ack = CompletableFuture<Unit>()
        val owner = owner(ack) { wait, cancelled, stopped ->
            entered.countDown()
            assertFalse(wait(60000))
            assertTrue(cancelled())
            assertFalse(stopped())
            ended.countDown()
            report(StreamingMicrophoneProbeStatus.CANCELLED)
        }
        try {
            owner.start()
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            val closing = owner.close(StreamingPlatformCloseReason.CANCELLED).toCompletableFuture()
            assertTrue(ended.await(2, TimeUnit.SECONDS))
            closing.complete(Unit) // Caller-owned copy must not forge owner release.
            assertFalse(owner.close(StreamingPlatformCloseReason.CANCELLED).toCompletableFuture().isDone)
            ack.complete(Unit)
            owner.close(StreamingPlatformCloseReason.CANCELLED).toCompletableFuture().get(2, TimeUnit.SECONDS)
        } finally { ack.complete(Unit); owner.close(StreamingPlatformCloseReason.CANCELLED) }
    }

    @Test fun stopWakesWindowWithoutTurningItIntoCancellation() {
        val entered = CountDownLatch(1)
        val owner = owner { wait, cancelled, stopped ->
            entered.countDown()
            assertFalse(wait(60000))
            assertFalse(cancelled())
            assertTrue(stopped())
            report(StreamingMicrophoneProbeStatus.COMPLETED)
        }
        try {
            owner.start()
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            owner.close(StreamingPlatformCloseReason.STOPPED).toCompletableFuture().get(2, TimeUnit.SECONDS)
        } finally { owner.close(StreamingPlatformCloseReason.CANCELLED) }
    }

    @Test fun closeBeforeReadyNeverStartsCaptureOnLateReadiness() {
        lateinit var ready: (StreamingStopCause?) -> Unit
        val bindEntered = CountDownLatch(1)
        val captures = java.util.concurrent.atomic.AtomicInteger()
        val owner = StreamingMicrophoneProbeOwner(
            startRemote = { ready = it; bindEntered.countDown() },
            runProbe = { _, _, _ -> captures.incrementAndGet(); report(StreamingMicrophoneProbeStatus.COMPLETED) },
            closeInference = { CompletableFuture.completedFuture(Unit) },
            closeRemote = { CompletableFuture.completedFuture(Unit) }, onReport = {}, onFailure = {},
        )
        owner.start()
        assertTrue(bindEntered.await(2, TimeUnit.SECONDS))
        owner.close(StreamingPlatformCloseReason.CANCELLED).toCompletableFuture().get(2, TimeUnit.SECONDS)
        ready(null)
        assertEquals(0, captures.get())
    }

    private fun owner(ack: CompletableFuture<Unit> = CompletableFuture.completedFuture(Unit),
        run: ((Long) -> Boolean, () -> Boolean, () -> Boolean) -> StreamingMicrophoneProbeReport) =
        StreamingMicrophoneProbeOwner({ it(null) }, run, { ack },
            { CompletableFuture.completedFuture(Unit) }, {}, {})

    private fun report(status: StreamingMicrophoneProbeStatus) =
        StreamingMicrophoneProbeReport(status, null, null, emptyList(), false, true)
}
