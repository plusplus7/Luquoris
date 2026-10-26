package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame
import com.loquiris.recording.PcmInferenceBacklog
import com.loquiris.recording.PriorityPcmFanOut
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class StreamingBacklogGuardTest {
    @Test
    fun realFanOutBacklogIncludesBusyDecoderAtEveryObservation() {
        val fanOut = PriorityPcmFanOut(4, 4, {})
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        try {
            fanOut.replaceInferenceConsumer {
                entered.countDown()
                while (release.count > 0) {
                    try { release.await(20, TimeUnit.MILLISECONDS) } catch (_: InterruptedException) { }
                }
            }
            fanOut.publish(PcmCaptureFrame(0, ByteArray(192000), 0))
            assertEquals(true, entered.await(2, TimeUnit.SECONDS))
            val guard = StreamingBacklogGuard(16000)
            assertEquals(96000L, guard.observeBacklog(1000, fanOut.inferenceBacklog()).uniqueSamples)
            assertNull(guard.observeBacklog(2000, fanOut.inferenceBacklog()).failure)
            assertEquals(StreamingBacklogFailure.SUSTAINED_BACKLOG,
                guard.observeBacklog(3000, fanOut.inferenceBacklog()).failure)
            assertEquals(true, fanOut.awaitCanonicalProcessed(1, 2000))
        } finally { release.countDown(); fanOut.close() }
    }

    @Test
    fun unknownFanOutCoordinatesFailClosedBeforeTimingGate() {
        val fanOut = PriorityPcmFanOut(4, 4, {})
        try {
            fanOut.publish(PcmCaptureFrame(99, ByteArray(640)))
            val guard = StreamingBacklogGuard(16000)
            assertEquals(StreamingBacklogFailure.INVALID_INPUT,
                guard.observeBacklog(0, fanOut.inferenceBacklog()).failure)
            assertEquals(StreamingBacklogFailure.INVALID_INPUT,
                guard.observeBacklog(1000, PcmInferenceBacklog(emptyList(), 0, false)).failure)
            assertEquals(StreamingBacklogFailure.INVALID_INPUT,
                StreamingBacklogGuard(16000).observeBacklog(0,
                    PcmInferenceBacklog(emptyList(), 1, false)).failure)
        } finally { fanOut.close() }
    }

    @Test
    fun overlappingQueuedAndInFlightAudioIsCountedOnce() {
        val guard = StreamingBacklogGuard(sampleRate = 16000)
        val result = guard.observe(0, listOf(
            PcmSampleInterval(32000, 64000),
            PcmSampleInterval(0, 48000),
            PcmSampleInterval(0, 48000),
            PcmSampleInterval(96000, 112000),
        ))
        assertEquals(80000L, result.uniqueSamples)
        assertEquals(0, result.consecutiveOverloadObservations)
        assertNull(result.failure)
    }

    @Test
    fun backlogMustExceedFiveSecondsAtThreeOneSecondObservations() {
        val guard = StreamingBacklogGuard(sampleRate = 16000)
        assertEquals(0, guard.observe(0, listOf(PcmSampleInterval(0, 80000))).consecutiveOverloadObservations)
        val pending = listOf(PcmSampleInterval(0, 80001))
        assertEquals(1, guard.observe(1000, pending).consecutiveOverloadObservations)
        assertNull(guard.observe(2000, pending).failure)
        assertEquals(StreamingBacklogFailure.SUSTAINED_BACKLOG, guard.observe(3000, pending).failure)
    }

    @Test
    fun duplicateAndStaleChecksCannotAccelerateDegradation() {
        val guard = StreamingBacklogGuard(sampleRate = 16000)
        val pending = listOf(PcmSampleInterval(0, 96000))
        val first = guard.observe(1000, pending)
        for (time in listOf(1000L, 1999L, 999L, 0L)) {
            assertEquals(first, guard.observe(time, pending))
        }
        assertEquals(2, guard.observe(2000, pending).consecutiveOverloadObservations)
        assertEquals(StreamingBacklogFailure.SUSTAINED_BACKLOG, guard.observe(3000, pending).failure)
    }

    @Test
    fun missedObservationAndRecoveredBacklogResetStreak() {
        val guard = StreamingBacklogGuard(sampleRate = 16000)
        val pending = listOf(PcmSampleInterval(0, 96000))
        guard.observe(0, pending)
        guard.observe(1000, pending)
        assertEquals(1, guard.observe(3000, pending).consecutiveOverloadObservations)
        assertEquals(0, guard.observe(4000, emptyList()).consecutiveOverloadObservations)
        assertEquals(1, guard.observe(5000, pending).consecutiveOverloadObservations)
        assertNull(guard.observe(6000, pending).failure)
        assertEquals(StreamingBacklogFailure.SUSTAINED_BACKLOG, guard.observe(7000, pending).failure)
    }

    @Test
    fun invalidOrUnboundedSnapshotsDegradeWithoutThrowing() {
        for (pending in listOf(
            listOf(PcmSampleInterval(-1, 10)),
            listOf(PcmSampleInterval(10, 9)),
            listOf(PcmSampleInterval(10, 10)),
            List(513) { PcmSampleInterval(0, 1) },
        )) {
            val result = StreamingBacklogGuard(16000).observe(0, pending)
            assertEquals(StreamingBacklogFailure.INVALID_INPUT, result.failure)
            assertNull(result.uniqueSamples)
        }
        assertEquals(StreamingBacklogFailure.INVALID_INPUT,
            StreamingBacklogGuard(16000).observe(-1, emptyList()).failure)
    }

    @Test
    fun extremeSampleCoordinatesDoNotOverflow() {
        val guard = StreamingBacklogGuard(Int.MAX_VALUE)
        val result = guard.observe(Long.MAX_VALUE - 2000, listOf(
            PcmSampleInterval(Long.MAX_VALUE - 1, Long.MAX_VALUE),
            PcmSampleInterval(0, Long.MAX_VALUE - 1),
        ))
        assertEquals(Long.MAX_VALUE, result.uniqueSamples)
        assertNull(guard.observe(Long.MAX_VALUE - 1000,
            listOf(PcmSampleInterval(0, Long.MAX_VALUE))).failure)
        assertEquals(StreamingBacklogFailure.SUSTAINED_BACKLOG,
            guard.observe(Long.MAX_VALUE, listOf(PcmSampleInterval(0, Long.MAX_VALUE))).failure)
    }

    @Test
    fun degradationIsLatchedForTheOwner() {
        val guard = StreamingBacklogGuard(16000)
        val pending = listOf(PcmSampleInterval(0, 96000))
        guard.observe(0, pending)
        guard.observe(1000, pending)
        val degraded = guard.observe(2000, pending)
        assertEquals(StreamingBacklogFailure.SUSTAINED_BACKLOG, degraded.failure)
        assertEquals(degraded, guard.observe(3000, emptyList()))
        assertNull(StreamingBacklogGuard(16000).observe(3000, emptyList()).failure)
    }
}
