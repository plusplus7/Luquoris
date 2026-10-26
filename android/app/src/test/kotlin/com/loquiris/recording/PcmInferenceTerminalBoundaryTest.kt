package com.loquiris.recording

import java.util.concurrent.CountDownLatch
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test

class PcmInferenceTerminalBoundaryTest {
    @Test fun repeatedStopSharesTheOriginalWorkerCompletionWithoutEnqueuingAgain() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val calls = CopyOnWriteArrayList<String>()
        val fanOut = PriorityPcmFanOut(16, 4, {})
        val consumer = PcmInferenceConsumer { entered.countDown(); awaitRelease(release) }
        try {
            fanOut.replaceInferenceConsumer(consumer)
            fanOut.publish(frame(0))
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            val first = fanOut.finishInference(consumer) { calls.add("first") }
            val again = fanOut.finishInference(consumer) { calls.add("duplicate") }
            assertFalse(again.toCompletableFuture().isDone)
            release.countDown()
            assertEquals(PcmInferenceBoundaryResult.completed, first.toCompletableFuture().get(2, TimeUnit.SECONDS))
            assertEquals(PcmInferenceBoundaryResult.completed, again.toCompletableFuture().get(2, TimeUnit.SECONDS))
            assertEquals(PcmInferenceBoundaryResult.completed,
                fanOut.finishInference(consumer) { calls.add("late-duplicate") }.toCompletableFuture().get())
            assertEquals(listOf("first"), calls)
        } finally { release.countDown(); fanOut.close() }
    }

    @Test fun decoderErrorAfterPreservingShutdownSettlesStopAndClearsPendingAudio() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val failed = CountDownLatch(1)
        val fanOut = PriorityPcmFanOut(16, 4, {})
        val consumer = object : PcmInferenceConsumer {
            override fun consume(frame: PcmCaptureFrame) {
                entered.countDown(); awaitRelease(release)
                throw LinkageError("synthetic released-decoder failure")
            }
            override fun onFailure(code: String) { failed.countDown() }
        }
        try {
            fanOut.replaceInferenceConsumer(consumer)
            fanOut.publish(frame(0))
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            fanOut.publish(frame(1))
            val stop = fanOut.finishInference(consumer) { fail("failed owner's stop ran") }
            assertTrue(fanOut.shutdown(preserveInferenceBoundary = true))
            release.countDown()
            assertTrue(failed.await(2, TimeUnit.SECONDS))
            assertEquals(PcmInferenceBoundaryResult.detached, stop.toCompletableFuture().get(2, TimeUnit.SECONDS))
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(2)
            while (fanOut.inferenceBacklog().pendingFrames != 0 && System.nanoTime() < deadline) Thread.sleep(1)
            assertEquals(0, fanOut.inferenceBacklog().pendingFrames)
            assertEquals(2L, fanOut.metrics.canonicalProcessedFrames)
        } finally { release.countDown(); fanOut.close() }
    }

    @Test fun sealedInputDrainsOldFramesThenStopWhileNewAudioStillWrites() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val order = CopyOnWriteArrayList<String>()
        val fanOut = PriorityPcmFanOut(16, 4, {})
        val consumer = PcmInferenceConsumer {
            if (it.sequence == 0L) { entered.countDown(); awaitRelease(release) }
            order.add("pcm${it.sequence}")
        }
        try {
            fanOut.replaceInferenceConsumer(consumer)
            fanOut.publish(frame(0))
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            fanOut.publish(frame(1))
            val stop = fanOut.finishInference(consumer) { order.add("stop") }
            assertFalse(stop.toCompletableFuture().isDone)
            fanOut.publish(frame(2))
            assertTrue(fanOut.awaitCanonicalProcessed(3, 2000))
            assertEquals(2L, fanOut.metrics.inferenceAcceptedFrames)
            release.countDown()
            assertEquals(PcmInferenceBoundaryResult.completed, stop.toCompletableFuture().get(2, TimeUnit.SECONDS))
            assertEquals(listOf("pcm0", "pcm1", "stop"), order)
            assertEquals(PcmInferenceBoundaryResult.closed, fanOut.enqueueInferenceBoundary(consumer) {}.toCompletableFuture().get())
        } finally { release.countDown(); fanOut.close() }
    }

    @Test fun requestedStopCanFinishAfterCanonicalShutdownWithoutDelayingIt() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val order = CopyOnWriteArrayList<String>()
        val fanOut = PriorityPcmFanOut(16, 4, {})
        val consumer = PcmInferenceConsumer { entered.countDown(); awaitRelease(release); order.add("pcm") }
        try {
            fanOut.replaceInferenceConsumer(consumer)
            fanOut.publish(frame(0))
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            val stop = fanOut.finishInference(consumer) { order.add("stop") }
            assertFalse(stop.toCompletableFuture().isDone)
            val before = System.nanoTime()
            assertTrue(fanOut.shutdown(preserveInferenceBoundary = true))
            assertTrue(TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - before) < 250)
            assertEquals(1L, fanOut.metrics.canonicalProcessedFrames)
            assertFalse(stop.toCompletableFuture().isDone)
            release.countDown()
            assertEquals(PcmInferenceBoundaryResult.completed, stop.toCompletableFuture().get(2, TimeUnit.SECONDS))
            assertEquals(listOf("pcm", "stop"), order)
        } finally { release.countDown(); fanOut.close() }
    }

    @Test fun abortStillCancelsAQueuedGracefulStop() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val fanOut = PriorityPcmFanOut(16, 4, {})
        val consumer = PcmInferenceConsumer { entered.countDown(); awaitRelease(release) }
        try {
            fanOut.replaceInferenceConsumer(consumer)
            fanOut.publish(frame(0))
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            val stop = fanOut.finishInference(consumer) { fail("aborted finalizer ran") }
            assertFalse(stop.toCompletableFuture().isDone)
            assertTrue(fanOut.shutdown())
            assertEquals(PcmInferenceBoundaryResult.closed, stop.toCompletableFuture().get(2, TimeUnit.SECONDS))
            assertEquals(1, fanOut.inferenceBacklog().pendingFrames)
        } finally { release.countDown(); fanOut.close() }
    }

    private fun frame(sequence: Long) = PcmCaptureFrame(sequence, ByteArray(640), sequence * 320)
    private fun awaitRelease(latch: CountDownLatch) {
        while (latch.count > 0) try { latch.await(20, TimeUnit.MILLISECONDS) } catch (_: InterruptedException) { }
    }
}
