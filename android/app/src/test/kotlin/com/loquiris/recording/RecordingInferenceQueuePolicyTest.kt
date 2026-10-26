package com.loquiris.recording

import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test

class RecordingInferenceQueuePolicyTest {
    @Test fun legacyColdStartReproducesTheNonPrefixGapWithoutLosingCanonicalFrames() {
        val observed = runStartupFrames(RecordingCapturePipeline.DEFAULT_INFERENCE_QUEUE_CAPACITY)
        assertEquals(16, observed.pendingBeforeAttach)
        assertEquals(185L, observed.droppedFrames)
        assertEquals((0L..201L).toList(), observed.canonicalSequences)
        assertEquals((0L..15L).toList() + 201L, observed.inferenceFrames.map { it.sequence })
        assertEquals(5120L, observed.inferenceFrames[15].canonicalEndSampleExclusive)
        assertEquals(64320L, observed.inferenceFrames.last().canonicalStartSample)
    }

    @Test fun optedInDebugQueueRetainsTheFourSecondModelStartupWindow() {
        val observed = runStartupFrames(RecordingInferenceQueuePolicy.capacityFrames(true, true))
        assertEquals(201, observed.pendingBeforeAttach)
        assertEquals(0L, observed.droppedFrames)
        assertEquals((0L..201L).toList(), observed.canonicalSequences)
        assertEquals((0L..201L).toList(), observed.inferenceFrames.map { it.sequence })
        assertEquals(0L, observed.inferenceFrames.first().canonicalStartSample)
        assertEquals(64640L, observed.inferenceFrames.last().canonicalEndSampleExclusive)
    }

    @Test fun optedInQueueStillHasAHardBoundAndCannotBlockCanonicalCapture() {
        val observed = runStartupFrames(RecordingInferenceQueuePolicy.capacityFrames(true, true), 300)
        assertEquals(256, observed.pendingBeforeAttach)
        assertEquals(44L, observed.droppedFrames)
        assertEquals((0L..300L).toList(), observed.canonicalSequences)
        assertEquals((0L..255L).toList() + 300L, observed.inferenceFrames.map { it.sequence })
    }

    @Test fun releaseAndOrdinaryDebugKeepTheExistingQueuePolicy() {
        for ((debug, spike) in listOf(false to false, false to true, true to false)) {
            val observed = runStartupFrames(RecordingInferenceQueuePolicy.capacityFrames(debug, spike))
            assertEquals(16, observed.pendingBeforeAttach)
            assertEquals(185L, observed.droppedFrames)
            assertEquals((0L..201L).toList(), observed.canonicalSequences)
        }
    }

    private fun runStartupFrames(capacity: Int, startupFrames: Int = 201): StartupObservation {
        val canonical = Collections.synchronizedList(mutableListOf<Long>())
        val inference = Collections.synchronizedList(mutableListOf<PcmCaptureFrame>())
        // Keep the canonical fixture independent of the inference queue being tested.
        val fanOut = PriorityPcmFanOut(startupFrames + 1, capacity, { canonical.add(it.sequence) })
        try {
            repeat(startupFrames) { sequence ->
                assertEquals(PcmFanOutPublishResult.accepted,
                    fanOut.publish(PcmCaptureFrame(sequence.toLong(), ByteArray(640), sequence * 320L)))
            }
            val pending = fanOut.inferenceBacklog().pendingFrames
            val queuedDrained = CountDownLatch(pending)
            val liveFrame = CountDownLatch(1)
            fanOut.replaceInferenceConsumer { frame ->
                inference.add(frame)
                if (frame.sequence < startupFrames) queuedDrained.countDown() else liveFrame.countDown()
            }
            assertTrue(queuedDrained.await(2, TimeUnit.SECONDS))
            assertEquals(PcmFanOutPublishResult.accepted,
                fanOut.publish(PcmCaptureFrame(startupFrames.toLong(), ByteArray(640), startupFrames * 320L)))
            assertTrue(liveFrame.await(2, TimeUnit.SECONDS))
            assertTrue(fanOut.awaitCanonicalProcessed(startupFrames + 1L, 2000))
            return StartupObservation(pending, fanOut.metrics.inferenceDroppedFrames,
                canonical.toList(), inference.toList())
        } finally { fanOut.close() }
    }

    private data class StartupObservation(
        val pendingBeforeAttach: Int,
        val droppedFrames: Long,
        val canonicalSequences: List<Long>,
        val inferenceFrames: List<PcmCaptureFrame>,
    )
}
