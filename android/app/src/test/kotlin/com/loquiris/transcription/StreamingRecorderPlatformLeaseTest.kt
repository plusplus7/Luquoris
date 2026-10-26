package com.loquiris.transcription

import com.loquiris.recording.*
import java.util.concurrent.*
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.*
import org.junit.Test

class StreamingRecorderPlatformLeaseTest {
    @Test fun cancelledLoadingWaitCannotAttachWhenModelReadyArrivesLate() {
        val h = Harness()
        val ready = CompletableFuture<StreamingStopCause?>()
        val observing = CountDownLatch(1)
        val watchdog = StreamingBacklogWatchdog(16000, h.fanOut::inferenceBacklog,
            StreamingReleaseOwner { h.releaseAck },
            StreamingSecondTicker { observing.countDown(); AutoCloseable { } })
        h.start = { cancelled -> awaitStreamingRuntimeReady(ready, cancelled, watchdog) }
        try {
            val starting = h.lease.start().toCompletableFuture()
            assertTrue(observing.await(2, TimeUnit.SECONDS))
            val closed = h.lease.close(StreamingPlatformCloseReason.CANCELLED).toCompletableFuture()
            assertEquals(1, h.cancels.get())
            ready.complete(null)
            assertEquals(StreamingStopCause.ENGINE, starting.get(2, TimeUnit.SECONDS))
            assertTrue(h.releaseRequested.await(2, TimeUnit.SECONDS))
            assertFalse(closed.isDone)
            assertEquals(PcmFanOutPublishResult.accepted,
                h.fanOut.publish(PcmCaptureFrame(0, ByteArray(640), 0)))
            assertTrue(h.fanOut.awaitCanonicalProcessed(1, 2000))
            assertEquals(1, h.fanOut.inferenceBacklog().pendingFrames)
            assertTrue(h.order.isEmpty())
            h.releaseAck.complete(Unit)
            closed.get(2, TimeUnit.SECONDS)
        } finally {
            ready.complete(null)
            watchdog.closeAsync()
            h.close()
        }
    }

    @Test fun captureReplacementDuringNativeWarmupCannotAttachWithStaleBacklogOwner() {
        val h = Harness()
        h.start = {
            h.registry.bindCaptureEndpoint("meeting", object : CaptureInferenceEndpoint {
                override val acceptsInference = true
                override fun replaceInferenceConsumer(consumer: PcmInferenceConsumer?) = h.fanOut.replaceInferenceConsumer(consumer)
                override fun finishInference(consumer: PcmInferenceConsumer, action: () -> Unit) = h.fanOut.finishInference(consumer, action)
                override fun inferenceBacklog() = h.fanOut.inferenceBacklog()
            })
            LiveDraftStartResult.Started
        }
        try {
            assertEquals(StreamingStopCause.ENGINE, h.lease.start().toCompletableFuture().get(2, TimeUnit.SECONDS))
            assertTrue(h.releaseRequested.await(2, TimeUnit.SECONDS))
            h.fanOut.publish(PcmCaptureFrame(0, ByteArray(640), 0))
            assertTrue(h.order.isEmpty())
        } finally { h.close() }
    }

    @Test fun startupRejectionKeepsTypedCauseEvenWhenRegistryClosesSessionFirst() {
        for ((code, expected) in listOf("transcription_live_thermal" to StreamingStopCause.THERMAL,
            "transcription_model_unavailable" to StreamingStopCause.MODEL_UNAVAILABLE)) {
            val h = Harness()
            h.start = { LiveDraftStartResult.Failure(code) }
            try {
                assertEquals(expected, h.lease.start().toCompletableFuture().get(2, TimeUnit.SECONDS))
                assertTrue(h.releaseRequested.await(2, TimeUnit.SECONDS))
            } finally { h.close() }
        }
    }

    @Test fun duplicateRunCannotClaimOrCloseAnotherRegistrySession() {
        val h = Harness()
        val delivered = CountDownLatch(1)
        val closes = AtomicInteger()
        val existing = object : LiveDraftSession {
            override fun start() = LiveDraftStartResult.Started
            override fun degrade(code: String) = Unit
            override fun consume(frame: PcmCaptureFrame) { delivered.countDown() }
            override fun close() { closes.incrementAndGet() }
        }
        h.registry.start(LiveDraftRequest("run", "meeting", "probe", TranscriptionLanguageHint.mixed, 1)) { existing }
        h.start = { error("duplicate allocated another runtime") }
        try {
            assertEquals(StreamingStopCause.ENGINE, h.lease.start().toCompletableFuture().get(2, TimeUnit.SECONDS))
            assertTrue(h.releaseRequested.await(2, TimeUnit.SECONDS))
            assertEquals(0, closes.get())
            h.fanOut.publish(PcmCaptureFrame(0, ByteArray(640), 0))
            assertTrue(delivered.await(2, TimeUnit.SECONDS))
        } finally { h.close() }
    }

    @Test fun stopDrainsRetainedFramesBeforeFinalizationAndWaitsForActualRelease() {
        val h = Harness()
        val entered = CountDownLatch(1)
        val releasePcm = CountDownLatch(1)
        h.consume = { entered.countDown(); check(releasePcm.await(2, TimeUnit.SECONDS)); h.order.add("pcm") }
        try {
            assertNull(h.lease.start().toCompletableFuture().get(2, TimeUnit.SECONDS))
            h.fanOut.publish(PcmCaptureFrame(0, ByteArray(640), 0))
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            val closed = h.lease.close(StreamingPlatformCloseReason.STOPPED).toCompletableFuture()
            assertFalse(closed.isDone)
            assertEquals(0, h.cancels.get())
            releasePcm.countDown()
            assertTrue(h.releaseRequested.await(2, TimeUnit.SECONDS))
            assertEquals(listOf("pcm", "STOP"), h.order)
            assertFalse(closed.isDone)
            h.releaseAck.complete(Unit)
            closed.get(2, TimeUnit.SECONDS)
        } finally { releasePcm.countDown(); h.close() }
    }

    @Test fun cancellationUpgradesBlockedStopImmediatelyWithoutForgingRelease() {
        val h = Harness()
        val entered = CountDownLatch(1)
        val releasePcm = CountDownLatch(1)
        h.consume = { entered.countDown(); check(releasePcm.await(2, TimeUnit.SECONDS)) }
        try {
            h.lease.start().toCompletableFuture().get(2, TimeUnit.SECONDS)
            h.fanOut.publish(PcmCaptureFrame(0, ByteArray(640), 0))
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            val stop = h.lease.close(StreamingPlatformCloseReason.STOPPED).toCompletableFuture()
            val cancel = h.lease.close(StreamingPlatformCloseReason.CANCELLED).toCompletableFuture()
            assertEquals(1, h.cancels.get())
            assertTrue(h.releaseRequested.await(2, TimeUnit.SECONDS))
            assertFalse(cancel.isDone); assertFalse(stop.isDone)
            h.releaseAck.complete(Unit)
            cancel.get(2, TimeUnit.SECONDS); stop.get(2, TimeUnit.SECONDS)
            assertTrue(h.order.isEmpty())
        } finally { releasePcm.countDown(); h.close() }
    }

    @Test fun recordingFinalizedBeforeDartCloseStillReleasesOnRecorderStop() {
        val h = Harness()
        try {
            h.lease.start().toCompletableFuture().get(2, TimeUnit.SECONDS)
            h.registry.recordingStopping("meeting")
            val stop = h.fanOut.notifyCaptureBoundary(PcmCaptureBoundary.STOP)
            h.registry.recordingFinalized("meeting")
            assertEquals(PcmInferenceBoundaryResult.completed, stop.toCompletableFuture().get(2, TimeUnit.SECONDS))
            assertTrue(h.releaseRequested.await(2, TimeUnit.SECONDS))
            h.releaseAck.complete(Unit)
            h.lease.close(StreamingPlatformCloseReason.STOPPED).toCompletableFuture().get(2, TimeUnit.SECONDS)
            assertEquals(listOf("STOP"), h.order)
        } finally { h.close() }
    }

    @Test fun cancelledModelStartCannotAttachOrAcknowledgeBeforeConstructionReturns() {
        val h = Harness()
        val constructing = CountDownLatch(1)
        val leaveConstruction = CountDownLatch(1)
        h.start = { cancelled -> constructing.countDown(); check(leaveConstruction.await(2, TimeUnit.SECONDS));
            assertTrue(cancelled()); LiveDraftStartResult.Started }
        try {
            val ready = h.lease.start().toCompletableFuture()
            assertTrue(constructing.await(2, TimeUnit.SECONDS))
            val closed = h.lease.close(StreamingPlatformCloseReason.CANCELLED).toCompletableFuture()
            assertEquals(1, h.cancels.get())
            assertFalse(closed.isDone)
            assertEquals(1L, h.releaseRequested.count)
            leaveConstruction.countDown()
            assertTrue(h.releaseRequested.await(2, TimeUnit.SECONDS))
            h.releaseAck.complete(Unit); closed.get(2, TimeUnit.SECONDS)
            assertNotNull(ready.get(2, TimeUnit.SECONDS))
            h.fanOut.publish(PcmCaptureFrame(0, ByteArray(640), 0))
            assertTrue(h.order.isEmpty())
        } finally { leaveConstruction.countDown(); h.close() }
    }

    @Test fun stopFenceRejectsBeforeNativeAllocation() {
        val h = Harness()
        h.registry.recordingStopping("meeting")
        h.start = { error("stopped recorder allocated native runtime") }
        try {
            assertEquals(StreamingStopCause.ENGINE, h.lease.start().toCompletableFuture().get(2, TimeUnit.SECONDS))
            assertTrue(h.releaseRequested.await(2, TimeUnit.SECONDS))
        } finally { h.close() }
    }

    @Test fun callerCannotForgeRuntimeReleaseAndRepeatedCloseUsesOneCleanup() {
        val h = Harness()
        try {
            h.lease.start().toCompletableFuture().get(2, TimeUnit.SECONDS)
            h.lease.close(StreamingPlatformCloseReason.CANCELLED).toCompletableFuture().complete(Unit)
            val actual = h.lease.close(StreamingPlatformCloseReason.CANCELLED).toCompletableFuture()
            assertTrue(h.releaseRequested.await(2, TimeUnit.SECONDS))
            assertFalse(actual.isDone)
            assertEquals(1, h.releaseCalls.get())
            h.releaseAck.complete(Unit); actual.get(2, TimeUnit.SECONDS)
        } finally { h.close() }
    }

    private class Harness {
        val registry = LivePcmInferenceRegistry()
        val fanOut = PriorityPcmFanOut(8, 8, {})
        val order = CopyOnWriteArrayList<String>()
        val cancels = AtomicInteger()
        val releaseCalls = AtomicInteger()
        val releaseRequested = CountDownLatch(1)
        val releaseAck = CompletableFuture<Unit>()
        var consume: (PcmCaptureFrame) -> Unit = { order.add("pcm") }
        var start: (() -> Boolean) -> LiveDraftStartResult = { LiveDraftStartResult.Started }
        private val endpoint = object : CaptureInferenceEndpoint {
            override val acceptsInference = true
            override fun replaceInferenceConsumer(consumer: PcmInferenceConsumer?) = fanOut.replaceInferenceConsumer(consumer)
            override fun finishInference(consumer: PcmInferenceConsumer, action: () -> Unit) = fanOut.finishInference(consumer, action)
            override fun inferenceBacklog() = fanOut.inferenceBacklog()
        }
        private val input = object : PcmCaptureBoundaryConsumer {
            override fun consume(frame: PcmCaptureFrame) = consume.invoke(frame)
            override fun onCaptureBoundary(boundary: PcmCaptureBoundary) { order.add(boundary.name) }
            override fun onBoundaryRejected(result: PcmInferenceBoundaryResult) = Unit
        }
        init { registry.bindCaptureEndpoint("meeting", endpoint) }
        val lease = StreamingRecorderPlatformLease(registry,
            LiveDraftRequest("run", "meeting", "probe", TranscriptionLanguageHint.mixed, 1),
            { start(it) }, { input }, { cancels.incrementAndGet() },
            { releaseCalls.incrementAndGet(); releaseRequested.countDown(); releaseAck }, {})
        fun close() {
            releaseAck.complete(Unit)
            lease.close(StreamingPlatformCloseReason.CANCELLED).toCompletableFuture().get(2, TimeUnit.SECONDS)
            registry.closeOwner(); fanOut.close()
        }
    }
}
