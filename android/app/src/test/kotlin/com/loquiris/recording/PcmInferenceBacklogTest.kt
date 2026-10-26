package com.loquiris.recording

import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test

class PcmInferenceBacklogTest {
    @Test
    fun pendingIncludesInFlightAndQueueDropsOnlyRemoveDroppedAudio() {
        val canonical = Collections.synchronizedList(mutableListOf<Long>())
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val fanOut = PriorityPcmFanOut(64, 2, { canonical.add(it.sequence) })
        try {
            fanOut.replaceInferenceConsumer {
                entered.countDown()
                while (release.count > 0) {
                    try { release.await(20, TimeUnit.MILLISECONDS) } catch (_: InterruptedException) { }
                }
            }
            fanOut.publish(PcmCaptureFrame(0, ByteArray(640), 0))
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            fanOut.publish(PcmCaptureFrame(1, ByteArray(320), 320))
            fanOut.publish(PcmCaptureFrame(2, ByteArray(160), 480))
            val before = fanOut.inferenceBacklog()
            assertEquals(3, before.pendingFrames)
            assertFalse(before.hasUnknownPosition)
            assertEquals(listOf(0L, 320L, 480L), before.intervals.map { it.startSample })
            assertEquals(listOf(320L, 480L, 560L), before.intervals.map { it.endSampleExclusive })
            fanOut.publish(PcmCaptureFrame(3, ByteArray(160), 560, 1))
            val after = fanOut.inferenceBacklog()
            assertEquals(listOf(0L, 480L, 560L), after.intervals.map { it.startSample })
            assertEquals(listOf(0L, 0L, 1L), after.intervals.map { it.captureEpoch })
            assertEquals(listOf(0L, 320L, 480L), before.intervals.map { it.startSample })
            assertThrows(UnsupportedOperationException::class.java) {
                (before.intervals as MutableList).clear()
            }
            fanOut.replaceInferenceConsumer(null)
            assertEquals(listOf(0L), fanOut.inferenceBacklog().intervals.map { it.startSample })
            assertTrue(fanOut.awaitCanonicalProcessed(4, 2000))
            assertEquals(listOf(0L, 1L, 2L, 3L), canonical)
            assertTrue(fanOut.shutdown())
            assertEquals(1, fanOut.inferenceBacklog().pendingFrames)
            release.countDown()
            assertTrue(waitFor { fanOut.inferenceBacklog().pendingFrames == 0 })
        } finally {
            release.countDown()
            fanOut.close()
        }
    }

    @Test
    fun legacyPositionsAreUnknownRatherThanSequenceDerived() {
        val fanOut = PriorityPcmFanOut(8, 8, {})
        try {
            fanOut.publish(PcmCaptureFrame(99, byteArrayOf(1)))
            fanOut.publish(PcmCaptureFrame(100, ByteArray(4), 1000))
            val pending = fanOut.inferenceBacklog()
            assertEquals(2, pending.pendingFrames)
            assertTrue(pending.hasUnknownPosition)
            assertEquals(listOf(CanonicalPcmInterval(1000, 1002, 0)), pending.intervals)
        } finally { fanOut.close() }
        assertEquals(0, fanOut.inferenceBacklog().pendingFrames)
    }

    @Test
    fun manualDrainReleasesTrackedQueueOwnership() {
        val fanOut = PriorityPcmFanOut(8, 8, {})
        try {
            fanOut.publish(PcmCaptureFrame(0, ByteArray(4), 0))
            assertEquals(1, fanOut.inferenceBacklog().pendingFrames)
            assertEquals(listOf(0L), fanOut.drainInference().map { it.sequence })
            assertEquals(0, fanOut.inferenceBacklog().pendingFrames)
        } finally { fanOut.close() }
    }

    private fun waitFor(predicate: () -> Boolean): Boolean {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(2)
        while (System.nanoTime() < deadline) {
            if (predicate()) return true
            Thread.sleep(1)
        }
        return false
    }
}
