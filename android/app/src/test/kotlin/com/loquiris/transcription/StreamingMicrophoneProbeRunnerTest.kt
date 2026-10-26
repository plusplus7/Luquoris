package com.loquiris.transcription

import com.loquiris.recording.*
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.Executors
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test

class StreamingMicrophoneProbeRunnerTest {
    @Test fun asynchronousReleaseOutOfMemoryKeepsMemoryFailure() {
        val h = Harness()
        val ack = CompletableFuture<Unit>()
        ack.completeExceptionally(OutOfMemoryError("synthetic remote cleanup failure"))
        try {
            val report = h.runner(ack = ack).run()
            assertEquals(StreamingStopCause.MEMORY, report.failure)
            assertTrue(report.cleanupFailed)
            assertFalse(report.resourcesReleased)
            assertTrue(h.source.released)
        } finally { h.pipeline?.close() }
    }

    @Test fun stopDuringCaptureDrainsAndFinalizesInsteadOfCancelling() {
        val h = Harness()
        try {
            val report = h.runner(stopAtWindow = 1).run()
            assertEquals(StreamingMicrophoneProbeStatus.COMPLETED, report.status)
            assertEquals(listOf(StreamingBoundaryReason.STOP to 2), h.flushes)
            assertEquals(listOf(10000L), h.windows)
            assertTrue(report.resourcesReleased)
            assertTrue(h.source.released)
        } finally { h.pipeline?.close() }
    }

    @Test fun stopDuringPauseNeverResumesOrDuplicatesFinalText() {
        val h = Harness()
        try {
            val report = h.runner(stopAtWindow = 2).run()
            assertEquals(StreamingMicrophoneProbeStatus.COMPLETED, report.status)
            assertEquals(listOf(StreamingBoundaryReason.PAUSE to 2), h.flushes)
            assertEquals(listOf(10000L, 1000L), h.windows)
            assertEquals(1, h.source.starts)
            assertTrue(report.resourcesReleased)
        } finally { h.pipeline?.close() }
    }

    @Test fun cleanupOutOfMemoryKeepsTypedMemoryFailure() {
        val h = Harness()
        h.encoder.failFinish = true
        try {
            val report = h.runner().run()
            assertEquals(StreamingMicrophoneProbeStatus.FAILED, report.status)
            assertEquals(StreamingStopCause.MEMORY, report.failure)
            assertTrue(report.cleanupFailed)
            assertFalse(report.resourcesReleased)
            assertTrue(h.source.released)
        } finally { h.pipeline?.close() }
    }

    @Test fun cancellationDuringConstructionNeverStartsMicrophone() {
        val h = Harness()
        try {
            val report = h.runner(cancelInFactory = true).run()
            assertEquals(0, h.source.starts)
            assertTrue(h.windows.isEmpty())
            assertTrue(h.flushes.isEmpty())
            assertEquals(StreamingMicrophoneProbeStatus.CANCELLED, report.status)
            assertTrue(h.source.released)
            assertTrue(report.resourcesReleased)
        } finally { h.pipeline?.close() }
    }

    @Test fun captureEpochsAreDurableAndFlushedOnlyAfterInferenceDrains() {
        val h = Harness()
        try {
            val report = h.runner().run()
            assertEquals(StreamingMicrophoneProbeStatus.COMPLETED, report.status)
            assertEquals(listOf(10000L, 1000L, 10000L), h.windows)
            assertEquals(listOf(StreamingBoundaryReason.PAUSE to 2, StreamingBoundaryReason.STOP to 4), h.flushes)
            assertEquals(listOf(0L, 0L, 1L, 1L), h.frames.map { it.captureEpoch })
            assertEquals(listOf(0L, 320L, 640L, 960L), h.frames.map { it.canonicalStartSample })
            assertEquals(4L, report.capture?.fanOut?.canonicalProcessedFrames)
            assertTrue(h.encoder.finished)
            assertTrue(h.source.released)
            assertTrue(report.resourcesReleased)
            assertFalse(report.cleanupFailed)
        } finally { h.pipeline?.close() }
    }

    @Test fun cancellationFinalizesCapturedAudioWithoutManufacturingUtteranceFinal() {
        val h = Harness()
        try {
            val report = h.runner(cancelFirstWindow = true).run()
            assertEquals(StreamingMicrophoneProbeStatus.CANCELLED, report.status)
            assertTrue(h.flushes.isEmpty())
            assertTrue(h.encoder.finished)
            assertTrue(h.source.released)
            assertEquals(2L, report.capture?.fanOut?.canonicalProcessedFrames)
            assertTrue(report.resourcesReleased)
        } finally { h.pipeline?.close() }
    }

    @Test fun failedFlushStillClosesCaptureAndWaitsForInferenceRelease() {
        val h = Harness()
        try {
            val report = h.runner(failFlush = true).run()
            assertEquals(StreamingMicrophoneProbeStatus.FAILED, report.status)
            assertEquals(StreamingStopCause.ENGINE, report.failure)
            assertTrue(h.source.released)
            assertTrue(h.encoder.finished)
            assertEquals(1, h.releaseRequests)
            assertTrue(report.resourcesReleased)
        } finally { h.pipeline?.close() }
    }

    @Test fun captureCleanupDoesNotForgeMissingNativeReleaseAcknowledgement() {
        val h = Harness()
        val ack = CompletableFuture<Unit>()
        val worker = Executors.newSingleThreadExecutor()
        try {
            val result = worker.submit<StreamingMicrophoneProbeReport> { h.runner(ack = ack).run() }
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(2)
            while (!h.source.released && System.nanoTime() < deadline) Thread.sleep(5)
            assertTrue(h.source.released)
            assertFalse(result.isDone)
            ack.complete(Unit)
            assertTrue(result.get(2, TimeUnit.SECONDS).resourcesReleased)
        } finally {
            ack.complete(Unit)
            worker.shutdownNow()
            h.pipeline?.close()
        }
    }

    private class Source : PcmCaptureSource {
        private val frames = LinkedBlockingQueue<ByteArray>()
        @Volatile private var running = false
        @Volatile var released = false
        var starts = 0
        override fun start(): Boolean { starts++; running = true; return true }
        override fun read(target: ByteArray): Int {
            while (running) {
                val bytes = frames.poll(10, TimeUnit.MILLISECONDS) ?: continue
                bytes.copyInto(target)
                return bytes.size
            }
            return PcmCaptureSource.READ_STOPPED
        }
        override fun stop(): Boolean { running = false; return true }
        override fun timestampFramePosition(): Long? = null
        override fun release() { released = true }
        fun offer() { repeat(2) { frames.put(ByteArray(640) { 1 }) } }
    }
    private class Encoder : CanonicalPcmEncoder {
        val frames = CopyOnWriteArrayList<PcmCaptureFrame>()
        var finished = false
        var failFinish = false
        override fun appendPcm(frame: PcmCaptureFrame): Boolean { frames.add(frame); return true }
        override fun finish(): Boolean { if (failFinish) throw OutOfMemoryError("synthetic encoder failure"); finished = true; return true }
        override fun abort() = Unit
        override fun bytesWritten(): Long = frames.size * 640L
    }
    private class Harness {
        val source = Source()
        val encoder = Encoder()
        val frames = CopyOnWriteArrayList<PcmCaptureFrame>()
        val windows = mutableListOf<Long>()
        val flushes = mutableListOf<Pair<StreamingBoundaryReason, Int>>()
        var pipeline: RecordingCapturePipeline? = null
        var releaseRequests = 0
        fun runner(cancelFirstWindow: Boolean = false, failFlush: Boolean = false, cancelInFactory: Boolean = false,
            stopAtWindow: Int = -1,
            ack: CompletableFuture<Unit> = CompletableFuture.completedFuture(Unit)): StreamingMicrophoneProbeRunner {
            var cancelled = false
            var stopped = false
            return StreamingMicrophoneProbeRunner(
            createCapture = { RecordingCapturePipeline(source, encoder).also { pipeline = it; cancelled = cancelInFactory } },
            consumer = PcmInferenceConsumer { frame -> Thread.sleep(10); frames.add(frame) },
            finishBoundary = { reason ->
                flushes.add(reason to frames.size)
                if (failFlush) throw IllegalStateException("synthetic native boundary failure")
            },
            releaseInference = { releaseRequests++; ack },
            isCancelled = { cancelled },
            isStopRequested = { stopped },
            waitWindow = { millis ->
                windows.add(millis)
                if (windows.size != 2) {
                    source.offer()
                    val count = if (windows.size == 1) 2 else 4
                    val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(2)
                    while (encoder.frames.size < count && System.nanoTime() < deadline) Thread.sleep(5)
                    check(encoder.frames.size == count)
                }
                stopped = windows.size == stopAtWindow
                !cancelFirstWindow && !stopped
            },
        )
        }
    }
}
