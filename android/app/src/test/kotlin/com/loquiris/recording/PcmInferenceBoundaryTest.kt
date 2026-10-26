package com.loquiris.recording

import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test

class PcmInferenceBoundaryTest {
    @Test fun frameErrorSettlesQueuedControlAndKeepsCanonicalWorkerAlive() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val failed = CountDownLatch(1)
        val fanOut = PriorityPcmFanOut(16, 4, {})
        val consumer = object : PcmInferenceConsumer {
            override fun consume(frame: PcmCaptureFrame) {
                entered.countDown()
                awaitUninterrupted(release)
                throw OutOfMemoryError("synthetic PCM decoder failure")
            }
            override fun onFailure(code: String) { failed.countDown() }
        }
        try {
            fanOut.replaceInferenceConsumer(consumer)
            fanOut.publish(frame(0))
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            val marker = fanOut.enqueueInferenceBoundary(consumer) { fail("failed owner's control ran") }
            release.countDown()
            assertTrue(failed.await(2, TimeUnit.SECONDS))
            assertEquals(PcmInferenceBoundaryResult.detached, marker.toCompletableFuture().get(2, TimeUnit.SECONDS))
            assertEquals(PcmInferenceBoundaryResult.detached, fanOut.enqueueInferenceBoundary(consumer) {}.toCompletableFuture().get())
            fanOut.publish(frame(1))
            assertTrue(fanOut.awaitCanonicalProcessed(2, 2000))
            assertEquals(0L, fanOut.metrics.canonicalSinkFailures)
            assertEquals(1L, fanOut.metrics.inferenceConsumerFailures)
        } finally { release.countDown(); fanOut.close() }
    }

    @Test fun boundaryFollowsOldFramesAndPrecedesResumedFramesWithoutBlockingCanonicalWrites() {
        val oldEntered = CountDownLatch(1)
        val releaseOld = CountDownLatch(1)
        val boundaryEntered = CountDownLatch(1)
        val releaseBoundary = CountDownLatch(1)
        val resumed = CountDownLatch(1)
        val order = CopyOnWriteArrayList<String>()
        val fanOut = PriorityPcmFanOut(32, 8, {})
        val consumer = PcmInferenceConsumer { frame ->
            if (frame.sequence == 0L) { oldEntered.countDown(); awaitUninterrupted(releaseOld) }
            order.add("pcm${frame.sequence}")
            if (frame.sequence == 2L) resumed.countDown()
        }
        try {
            fanOut.replaceInferenceConsumer(consumer)
            fanOut.publish(frame(0))
            assertTrue(oldEntered.await(2, TimeUnit.SECONDS))
            fanOut.publish(frame(1))
            val boundary = fanOut.enqueueInferenceBoundary(consumer) {
                order.add("pause")
                boundaryEntered.countDown()
                awaitUninterrupted(releaseBoundary)
            }
            fanOut.publish(frame(2, 1))
            assertTrue(fanOut.awaitCanonicalProcessed(3, 2000))
            assertFalse(boundary.toCompletableFuture().isDone)
            releaseOld.countDown()
            assertTrue(boundaryEntered.await(2, TimeUnit.SECONDS))
            assertEquals(listOf("pcm0", "pcm1", "pause"), order)
            boundary.toCompletableFuture().complete(PcmInferenceBoundaryResult.completed)
            assertFalse(boundary.toCompletableFuture().isDone)
            releaseBoundary.countDown()
            assertEquals(PcmInferenceBoundaryResult.completed, boundary.toCompletableFuture().get(2, TimeUnit.SECONDS))
            assertTrue(resumed.await(2, TimeUnit.SECONDS))
            assertEquals(listOf("pcm0", "pcm1", "pause", "pcm2"), order)
        } finally { releaseOld.countDown(); releaseBoundary.countDown(); fanOut.close() }
    }

    @Test fun boundedControlsSurvivePcmOverflowWithoutInflatingAudioBacklog() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val calls = CopyOnWriteArrayList<Int>()
        val fanOut = PriorityPcmFanOut(128, 2, {})
        val consumer = PcmInferenceConsumer { if (it.sequence == 0L) { entered.countDown(); awaitUninterrupted(release) } }
        try {
            fanOut.replaceInferenceConsumer(consumer)
            fanOut.publish(frame(0))
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            val accepted = (0 until 16).map { index -> fanOut.enqueueInferenceBoundary(consumer) { calls.add(index) } }
            val rejected = fanOut.enqueueInferenceBoundary(consumer) { calls.add(99) }
            assertEquals(PcmInferenceBoundaryResult.queueFull, rejected.toCompletableFuture().get(2, TimeUnit.SECONDS))
            (1L..100L).forEach { fanOut.publish(frame(it)) }
            assertTrue(fanOut.awaitCanonicalProcessed(101, 2000))
            assertEquals(3, fanOut.inferenceBacklog().pendingFrames)
            assertEquals(0L, fanOut.metrics.canonicalRejectedFrames)
            release.countDown()
            accepted.forEach { assertEquals(PcmInferenceBoundaryResult.completed, it.toCompletableFuture().get(2, TimeUnit.SECONDS)) }
            assertEquals((0 until 16).toList(), calls)
        } finally { release.countDown(); fanOut.close() }
    }

    @Test fun replacementCancelsOldQueuedControlAndLeavesOldInFlightAudioOwned() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val newFrame = CountDownLatch(1)
        val calls = CopyOnWriteArrayList<String>()
        val fanOut = PriorityPcmFanOut(16, 4, {})
        val old = PcmInferenceConsumer { entered.countDown(); awaitUninterrupted(release) }
        try {
            fanOut.replaceInferenceConsumer(old)
            fanOut.publish(frame(0))
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            val marker = fanOut.enqueueInferenceBoundary(old) { calls.add("stale") }
            assertFalse(marker.toCompletableFuture().isDone)
            fanOut.replaceInferenceConsumer { newFrame.countDown() }
            assertEquals(PcmInferenceBoundaryResult.detached, marker.toCompletableFuture().get(2, TimeUnit.SECONDS))
            assertEquals(1, fanOut.inferenceBacklog().pendingFrames)
            assertEquals(PcmInferenceBoundaryResult.detached,
                fanOut.enqueueInferenceBoundary(old) { calls.add("wrong-owner") }.toCompletableFuture().get())
            fanOut.publish(frame(1))
            release.countDown()
            assertTrue(newFrame.await(2, TimeUnit.SECONDS))
            assertTrue(calls.isEmpty())
        } finally { release.countDown(); fanOut.close() }
    }

    @Test fun shutdownSettlesPendingControlsAsClosedWithoutWaitingForDecoder() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val fanOut = PriorityPcmFanOut(16, 4, {})
        val consumer = PcmInferenceConsumer { entered.countDown(); awaitUninterrupted(release) }
        try {
            fanOut.replaceInferenceConsumer(consumer)
            fanOut.publish(frame(0))
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            val marker = fanOut.enqueueInferenceBoundary(consumer) { fail("closed callback ran") }
            assertTrue(fanOut.shutdown())
            assertEquals(PcmInferenceBoundaryResult.closed, marker.toCompletableFuture().get(2, TimeUnit.SECONDS))
            assertEquals(PcmInferenceBoundaryResult.closed, fanOut.enqueueInferenceBoundary(consumer) {}.toCompletableFuture().get())
            assertEquals(1, fanOut.inferenceBacklog().pendingFrames)
        } finally { release.countDown(); fanOut.close() }
    }

    @Test fun boundaryFailureIsTypedAndCannotStopCanonicalEncoding() {
        val failed = CountDownLatch(1)
        val fanOut = PriorityPcmFanOut(16, 4, {})
        val consumer = object : PcmInferenceConsumer {
            override fun consume(frame: PcmCaptureFrame) = Unit
            override fun onFailure(code: String) { assertEquals("transcription_live_boundary_failed", code); failed.countDown() }
        }
        try {
            fanOut.replaceInferenceConsumer(consumer)
            val marker = fanOut.enqueueInferenceBoundary(consumer) { throw OutOfMemoryError("synthetic inference finish failure") }
            assertEquals(PcmInferenceBoundaryResult.failed, marker.toCompletableFuture().get(2, TimeUnit.SECONDS))
            assertTrue(failed.await(2, TimeUnit.SECONDS))
            fanOut.publish(frame(0))
            assertTrue(fanOut.awaitCanonicalProcessed(1, 2000))
            assertEquals(0L, fanOut.metrics.canonicalSinkFailures)
            assertEquals(1L, fanOut.metrics.inferenceConsumerFailures)
        } finally { fanOut.close() }
    }

    private fun frame(sequence: Long, epoch: Long = 0) = PcmCaptureFrame(sequence, ByteArray(640), sequence * 320, epoch)
    private fun awaitUninterrupted(latch: CountDownLatch) {
        while (latch.count > 0) try { latch.await(20, TimeUnit.MILLISECONDS) } catch (_: InterruptedException) { }
    }
}
