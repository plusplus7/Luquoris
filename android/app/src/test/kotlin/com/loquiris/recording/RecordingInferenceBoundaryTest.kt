package com.loquiris.recording

import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test

class RecordingInferenceBoundaryTest {
    @Test fun captureEndpointFinalizesOnlyDerivedInputWhileCanonicalRecordingContinues() {
        val h = Harness()
        val delivered = CountDownLatch(1)
        val finalized = CountDownLatch(1)
        val consumer = PcmInferenceConsumer { delivered.countDown() }
        try {
            val endpoint = (h.pipeline as Any) as? CaptureInferenceEndpoint
            assertNotNull("pipeline must expose its existing fan-out, not another source", endpoint)
            assertFalse(endpoint!!.acceptsInference)
            h.pipeline.start()
            assertTrue(endpoint.acceptsInference)
            endpoint.replaceInferenceConsumer(consumer)
            h.source.offer()
            assertTrue(delivered.await(2, TimeUnit.SECONDS))
            assertEquals(PcmInferenceBoundaryResult.completed,
                endpoint.finishInference(consumer) { finalized.countDown() }.toCompletableFuture().get(2, TimeUnit.SECONDS))
            assertEquals(0L, finalized.count)
            h.source.offer()
            assertTrue(h.awaitEncoded(2))
            assertEquals(0, endpoint.inferenceBacklog().pendingFrames)
            assertEquals(RecordingCaptureCommandResult.Success, h.pipeline.finish())
            assertFalse(endpoint.acceptsInference)
        } finally { h.pipeline.close() }
    }
    @Test fun audioFailureStillNotifiesOwnerAfterStopActionHasReturned() {
        val rejected = CopyOnWriteArrayList<PcmInferenceBoundaryResult>()
        val fanOut = PriorityPcmFanOut(4, 4, {})
        val consumer = object : PcmCaptureBoundaryConsumer {
            override fun consume(frame: PcmCaptureFrame) = Unit
            override fun onCaptureBoundary(boundary: PcmCaptureBoundary) = Unit
            override fun onBoundaryRejected(result: PcmInferenceBoundaryResult) { rejected.add(result) }
        }
        try {
            fanOut.replaceInferenceConsumer(consumer)
            val terminal = fanOut.notifyCaptureBoundary(PcmCaptureBoundary.STOP)
            assertEquals(PcmInferenceBoundaryResult.completed, terminal.toCompletableFuture().get(2, TimeUnit.SECONDS))
            // The pipeline may now discover canonical/encoder finalization failure.
            fanOut.abortInference(failed = true)
            assertTrue(rejected.contains(PcmInferenceBoundaryResult.failed))
        } finally { fanOut.close() }
    }
    @Test fun resumeFailureNotifiesInferenceBeforeAnyCallerCleanup() {
        val h = Harness()
        val rejected = CountDownLatch(1)
        h.pipeline.replaceInferenceConsumer(rejectionConsumer(rejected))
        try {
            h.pipeline.start()
            h.pipeline.pause()
            h.source.failResume = true
            assertTrue(h.pipeline.resume() is RecordingCaptureCommandResult.Failure)
            assertTrue(rejected.await(2, TimeUnit.SECONDS))
            assertTrue(h.source.released)
        } finally { h.pipeline.close() }
    }

    @Test fun readFailureNotifiesInferenceWithoutJoiningItsWorker() {
        val h = Harness()
        val rejected = CountDownLatch(1)
        h.pipeline.replaceInferenceConsumer(rejectionConsumer(rejected))
        try {
            h.pipeline.start()
            h.source.failRead = true
            assertTrue(rejected.await(2, TimeUnit.SECONDS))
            assertEquals(RecordingCapturePipelineState.failed, h.pipeline.snapshot().state)
        } finally { h.pipeline.close() }
    }

    private fun rejectionConsumer(rejected: CountDownLatch) = object : PcmCaptureBoundaryConsumer {
        override fun consume(frame: PcmCaptureFrame) = Unit
        override fun onCaptureBoundary(boundary: PcmCaptureBoundary) = Unit
        override fun onBoundaryRejected(result: PcmInferenceBoundaryResult) { rejected.countDown() }
    }

    @Test fun failedAudioFinalizationCancelsInferenceWithoutWaitingForBlockedDecoder() {
        val h = Harness()
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val rejected = CountDownLatch(1)
        h.encoder.failFinish = true
        val consumer = object : PcmCaptureBoundaryConsumer {
            override fun consume(frame: PcmCaptureFrame) { entered.countDown(); awaitGate(release) }
            override fun onCaptureBoundary(boundary: PcmCaptureBoundary) { fail("failed recording finalizer ran") }
            override fun onBoundaryRejected(result: PcmInferenceBoundaryResult) { rejected.countDown() }
        }
        try {
            h.pipeline.replaceInferenceConsumer(consumer)
            h.pipeline.start(); h.source.offer()
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            assertTrue(h.awaitEncoded(1))
            assertTrue(h.pipeline.finish() is RecordingCaptureCommandResult.Failure)
            assertTrue(rejected.await(2, TimeUnit.SECONDS))
            assertTrue(h.source.released)
        } finally { release.countDown(); h.pipeline.close() }
    }

    @Test fun pauseBoundaryPrecedesResumedFramesWithoutBlockingRecordingControls() {
        val h = Harness()
        val oldEntered = CountDownLatch(1)
        val releaseOld = CountDownLatch(1)
        val boundaryEntered = CountDownLatch(1)
        val releaseBoundary = CountDownLatch(1)
        val resumed = CountDownLatch(1)
        val order = CopyOnWriteArrayList<String>()
        val consumer = object : PcmCaptureBoundaryConsumer {
            override fun consume(frame: PcmCaptureFrame) {
                if (frame.sequence == 0L) { oldEntered.countDown(); awaitGate(releaseOld) }
                order.add("pcm${frame.sequence}e${frame.captureEpoch}")
                if (frame.sequence == 2L) resumed.countDown()
            }
            override fun onCaptureBoundary(boundary: PcmCaptureBoundary) {
                order.add(boundary.name)
                if (boundary == PcmCaptureBoundary.PAUSE) { boundaryEntered.countDown(); awaitGate(releaseBoundary) }
            }
            override fun onBoundaryRejected(result: PcmInferenceBoundaryResult) = Unit
        }
        try {
            h.pipeline.replaceInferenceConsumer(consumer)
            assertEquals(RecordingCaptureCommandResult.Success, h.pipeline.start())
            h.source.offer(); assertTrue(oldEntered.await(2, TimeUnit.SECONDS))
            h.source.offer(); assertTrue(h.awaitEncoded(2))
            val before = System.nanoTime()
            assertEquals(RecordingCaptureCommandResult.Success, h.pipeline.pause())
            assertEquals(RecordingCaptureCommandResult.Success, h.pipeline.resume())
            assertTrue(TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - before) < 500)
            h.source.offer(); assertTrue(h.awaitEncoded(3))
            releaseOld.countDown()
            assertTrue(boundaryEntered.await(2, TimeUnit.SECONDS))
            assertEquals(listOf("pcm0e0", "pcm1e0", "PAUSE"), order)
            releaseBoundary.countDown()
            assertTrue(resumed.await(2, TimeUnit.SECONDS))
            assertEquals(listOf("pcm0e0", "pcm1e0", "PAUSE", "pcm2e1"), order)
        } finally { releaseOld.countDown(); releaseBoundary.countDown(); h.pipeline.close() }
    }

    @Test fun finishDurablyClosesAudioBeforeBlockedInferenceEventuallyFinalizes() {
        val h = Harness()
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val stopped = CountDownLatch(1)
        val order = CopyOnWriteArrayList<String>()
        val consumer = object : PcmCaptureBoundaryConsumer {
            override fun consume(frame: PcmCaptureFrame) { entered.countDown(); awaitGate(release); order.add("pcm") }
            override fun onCaptureBoundary(boundary: PcmCaptureBoundary) { order.add(boundary.name); stopped.countDown() }
            override fun onBoundaryRejected(result: PcmInferenceBoundaryResult) = Unit
        }
        try {
            h.pipeline.replaceInferenceConsumer(consumer)
            h.pipeline.start(); h.source.offer()
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            assertTrue(h.awaitEncoded(1))
            val before = System.nanoTime()
            assertEquals(RecordingCaptureCommandResult.Success, h.pipeline.finish())
            assertTrue(TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - before) < 500)
            assertTrue(h.encoder.finished)
            assertTrue(h.source.released)
            assertEquals(1L, stopped.count)
            release.countDown()
            assertTrue(stopped.await(2, TimeUnit.SECONDS))
            assertEquals(listOf("pcm", "STOP"), order)
            assertEquals(1L, h.pipeline.snapshot().fanOut.canonicalProcessedFrames)
        } finally { release.countDown(); h.pipeline.close() }
    }

    @Test fun focusBoundaryIsDistinctAndIdempotentPauseDoesNotRepeatIt() {
        val h = Harness()
        val boundaries = CopyOnWriteArrayList<PcmCaptureBoundary>()
        val focus = CountDownLatch(1)
        val stopped = CountDownLatch(1)
        val consumer = object : PcmCaptureBoundaryConsumer {
            override fun consume(frame: PcmCaptureFrame) = Unit
            override fun onCaptureBoundary(boundary: PcmCaptureBoundary) {
                boundaries.add(boundary)
                if (boundary == PcmCaptureBoundary.AUDIO_FOCUS) focus.countDown()
                if (boundary == PcmCaptureBoundary.STOP) stopped.countDown()
            }
            override fun onBoundaryRejected(result: PcmInferenceBoundaryResult) = Unit
        }
        try {
            h.pipeline.replaceInferenceConsumer(consumer)
            h.pipeline.start()
            assertEquals(RecordingCaptureCommandResult.Success, h.pipeline.pause(PcmCaptureBoundary.AUDIO_FOCUS))
            assertEquals(RecordingCaptureCommandResult.Success, h.pipeline.pause())
            assertTrue(focus.await(2, TimeUnit.SECONDS))
            h.pipeline.resume()
            assertEquals(RecordingCaptureCommandResult.Success, h.pipeline.finish())
            assertTrue(stopped.await(2, TimeUnit.SECONDS))
            assertEquals(listOf(PcmCaptureBoundary.AUDIO_FOCUS, PcmCaptureBoundary.STOP), boundaries)
        } finally { h.pipeline.close() }
    }

    @Test fun abortNotifiesOptionalConsumerEvenWithoutAnOutstandingBoundary() {
        val h = Harness()
        val rejected = CopyOnWriteArrayList<PcmInferenceBoundaryResult>()
        val boundaries = CopyOnWriteArrayList<PcmCaptureBoundary>()
        val consumer = object : PcmCaptureBoundaryConsumer {
            override fun consume(frame: PcmCaptureFrame) = Unit
            override fun onCaptureBoundary(boundary: PcmCaptureBoundary) { boundaries.add(boundary) }
            override fun onBoundaryRejected(result: PcmInferenceBoundaryResult) { rejected.add(result) }
        }
        h.pipeline.replaceInferenceConsumer(consumer)
        h.pipeline.start()
        h.pipeline.close()
        assertTrue(rejected.contains(PcmInferenceBoundaryResult.closed))
        assertTrue(boundaries.isEmpty())
        assertTrue(h.source.released)
    }

    private class Source : PcmCaptureSource {
        private val queue = LinkedBlockingQueue<ByteArray>()
        @Volatile private var running = false
        @Volatile var released = false
        @Volatile var failRead = false
        var failResume = false
        private var starts = 0
        override fun start(): Boolean { if (failResume && starts > 0) return false; starts++; running = true; return true }
        override fun stop(): Boolean { running = false; return true }
        override fun release() { released = true }
        override fun timestampFramePosition(): Long? = null
        override fun read(target: ByteArray): Int {
            while (running) {
                if (failRead) error("synthetic capture read failure")
                val bytes = queue.poll(10, TimeUnit.MILLISECONDS) ?: continue
                bytes.copyInto(target); return bytes.size
            }
            return PcmCaptureSource.READ_STOPPED
        }
        fun offer() { queue.offer(ByteArray(640)) }
    }
    private class Encoder : CanonicalPcmEncoder {
        val frames = CopyOnWriteArrayList<PcmCaptureFrame>()
        @Volatile var finished = false
        var failFinish = false
        override fun appendPcm(frame: PcmCaptureFrame): Boolean { frames.add(frame); return true }
        override fun finish(): Boolean { if (failFinish) return false; finished = true; return true }
        override fun abort() = Unit
        override fun bytesWritten(): Long = frames.size * 640L
    }
    private class Harness {
        val source = Source()
        val encoder = Encoder()
        val pipeline = RecordingCapturePipeline(source, encoder)
        fun awaitEncoded(count: Int): Boolean {
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(2)
            while (System.nanoTime() < deadline) { if (encoder.frames.size >= count) return true; Thread.sleep(1) }
            return false
        }
    }
    private fun awaitGate(latch: CountDownLatch) {
        while (latch.count > 0) try { latch.await(20, TimeUnit.MILLISECONDS) } catch (_: InterruptedException) { }
    }
}
