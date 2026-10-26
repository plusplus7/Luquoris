package com.loquiris.recording

import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import org.junit.Assert.*
import org.junit.Test

class CanonicalPcmPositionTest {
    @Test
    fun staleReadCannotPublishAcrossPauseResume() {
        val entered = CountDownLatch(1)
        val releaseTimestamp = CountDownLatch(1)
        val first = AtomicBoolean(true)
        val source = PositionSource {
            if (first.getAndSet(false)) {
                entered.countDown()
                check(releaseTimestamp.await(2, TimeUnit.SECONDS))
            }
        }
        val encoder = PositionEncoder(1)
        val resumedFrame = CountDownLatch(1)
        val pipeline = RecordingCapturePipeline(source, encoder)
        try {
            pipeline.replaceInferenceConsumer { if (it.captureEpoch == 1L) resumedFrame.countDown() }
            pipeline.start()
            source.offer(ByteArray(640) { 1 })
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            assertEquals(RecordingCaptureCommandResult.Success, pipeline.pause())
            assertEquals(RecordingCaptureCommandResult.Success, pipeline.resume())
            source.offer(ByteArray(160) { 2 })
            releaseTimestamp.countDown()
            assertTrue(resumedFrame.await(2, TimeUnit.SECONDS))
            assertEquals(RecordingCaptureCommandResult.Success, pipeline.finish())
            assertEquals(listOf(2.toByte()), encoder.frames.map { it.copyBytes()[0] })
            assertEquals(listOf(0L), encoder.frames.map { it.sequence })
            assertEquals(listOf(0L), encoder.frames.map { it.canonicalStartSample })
            assertEquals(listOf(80L), encoder.frames.map { it.canonicalEndSampleExclusive })
            assertEquals(listOf(1L), encoder.frames.map { it.captureEpoch })
        } finally {
            releaseTimestamp.countDown()
            pipeline.close()
        }
    }

    @Test
    fun variableReadsHaveExactPositionsInBothBranches() {
        val source = PositionSource()
        val encoder = PositionEncoder(3)
        val inference = Collections.synchronizedList(mutableListOf<PcmCaptureFrame>())
        val inferred = CountDownLatch(3)
        val pipeline = RecordingCapturePipeline(source, encoder)
        try {
            pipeline.replaceInferenceConsumer { frame ->
                inference.add(frame)
                frame.copyBytes().fill(99)
                inferred.countDown()
            }
            assertEquals(RecordingCaptureCommandResult.Success, pipeline.start())
            source.offer(ByteArray(8) { 1 })
            source.offer(ByteArray(640) { 2 })
            source.offer(ByteArray(2) { 3 })
            assertTrue(encoder.received.await(2, TimeUnit.SECONDS))
            assertTrue(inferred.await(2, TimeUnit.SECONDS))
            assertEquals(RecordingCaptureCommandResult.Success, pipeline.finish())
            for (frames in listOf(encoder.frames, inference)) {
                assertEquals(listOf(0L, 4L, 324L), frames.map { it.canonicalStartSample })
                assertEquals(listOf(4L, 324L, 325L), frames.map { it.canonicalEndSampleExclusive })
                assertEquals(listOf(0L, 0L, 0L), frames.map { it.captureEpoch })
                assertEquals(listOf(0L, 1L, 2L), frames.map { it.sequence })
                assertEquals(listOf(1.toByte(), 2.toByte(), 3.toByte()), frames.map { it.copyBytes()[0] })
            }
        } finally {
            pipeline.close()
        }
    }

    @Test
    fun pauseResumeChangesEpochWithoutInventingCapturedSamples() {
        val source = PositionSource()
        val encoder = PositionEncoder(2)
        val firstFrame = CountDownLatch(1)
        val pipeline = RecordingCapturePipeline(source, encoder)
        try {
            pipeline.replaceInferenceConsumer { firstFrame.countDown() }
            pipeline.start()
            source.offer(ByteArray(640))
            assertTrue(firstFrame.await(2, TimeUnit.SECONDS))
            assertEquals(RecordingCaptureCommandResult.Success, pipeline.pause())
            assertEquals(RecordingCaptureCommandResult.Success, pipeline.resume())
            assertEquals(RecordingCaptureCommandResult.Success, pipeline.resume())
            source.offer(ByteArray(160))
            assertTrue(encoder.received.await(2, TimeUnit.SECONDS))
            assertEquals(RecordingCaptureCommandResult.Success, pipeline.finish())
            assertEquals(listOf(0L, 320L), encoder.frames.map { it.canonicalStartSample })
            assertEquals(listOf(320L, 400L), encoder.frames.map { it.canonicalEndSampleExclusive })
            assertEquals(listOf(0L, 1L), encoder.frames.map { it.captureEpoch })
        } finally {
            pipeline.close()
        }
    }

    @Test
    fun invalidSampleAlignmentFailsBeforeCanonicalPublication() {
        val source = PositionSource()
        val encoder = PositionEncoder(1)
        val pipeline = RecordingCapturePipeline(source, encoder)
        try {
            pipeline.start()
            source.offer(ByteArray(3))
            assertTrue(source.stopped.await(2, TimeUnit.SECONDS))
            assertEquals("recording_input_pcm_alignment_invalid", pipeline.snapshot().failureCode)
            assertEquals(0L, pipeline.snapshot().fanOut.canonicalAcceptedFrames)
            assertTrue(encoder.frames.isEmpty())
        } finally {
            pipeline.close()
        }
    }

    @Test
    fun explicitPositionsRejectInvalidOrOverflowingPayloads() {
        assertThrows(IllegalArgumentException::class.java) { PcmCaptureFrame(0, ByteArray(2), -1) }
        assertThrows(IllegalArgumentException::class.java) { PcmCaptureFrame(0, ByteArray(3), 0) }
        assertThrows(IllegalArgumentException::class.java) { PcmCaptureFrame(0, ByteArray(2), 0, -1) }
        assertThrows(ArithmeticException::class.java) { PcmCaptureFrame(0, ByteArray(2), Long.MAX_VALUE) }
        val frame = PcmCaptureFrame(4, ByteArray(2), Long.MAX_VALUE - 1, 3)
        assertEquals(Long.MAX_VALUE, frame.canonicalEndSampleExclusive)
        assertEquals(3L, frame.isolatedCopy().captureEpoch)
    }

    @Test
    fun legacyFramesDoNotInventSamplePositions() {
        val frame = PcmCaptureFrame(99, byteArrayOf(1))
        assertNull(frame.canonicalStartSample)
        assertNull(frame.canonicalEndSampleExclusive)
        assertNull(frame.isolatedCopy().canonicalStartSample)
    }
}

private class PositionSource(private val onTimestamp: () -> Unit = {}) : PcmCaptureSource {
    private val queue = LinkedBlockingQueue<ByteArray>()
    val stopped = CountDownLatch(1)
    @Volatile private var active = false
    override fun start(): Boolean { active = true; return true }
    override fun read(target: ByteArray): Int {
        while (active) {
            val bytes = queue.poll(10, TimeUnit.MILLISECONDS) ?: continue
            bytes.copyInto(target)
            return bytes.size
        }
        return PcmCaptureSource.READ_STOPPED
    }
    override fun stop(): Boolean { active = false; stopped.countDown(); return true }
    override fun timestampFramePosition(): Long? { onTimestamp(); return null }
    override fun release() = Unit
    fun offer(bytes: ByteArray) { queue.add(bytes) }
}

private class PositionEncoder(count: Int) : CanonicalPcmEncoder {
    val received = CountDownLatch(count)
    val frames = Collections.synchronizedList(mutableListOf<PcmCaptureFrame>())
    override fun appendPcm(frame: PcmCaptureFrame): Boolean {
        frames.add(frame)
        received.countDown()
        return true
    }
    override fun finish(): Boolean = true
    override fun abort() = Unit
    override fun bytesWritten(): Long = 0
}
