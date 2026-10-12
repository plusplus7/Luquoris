package com.loquiris.recording

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PriorityPcmLiveInferenceTest {
    @Test
    fun `stalled inference replaces obsolete AI work without delaying canonical audio`() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val backlog = mutableListOf<Pair<Int, Long>>()
        val encoded = mutableListOf<Long>()
        val fanOut =
            PriorityPcmFanOut(
                canonicalCapacity = 128,
                inferenceCapacity = 2,
                canonicalSink = { frame -> synchronized(encoded) { encoded += frame.sequence } },
            )
        fanOut.replaceInferenceConsumer(
            object : PcmInferenceConsumer {
                override fun consume(frame: PcmCaptureFrame) {
                    entered.countDown()
                    release.await(2, TimeUnit.SECONDS)
                }

                override fun onBacklog(
                    queuedFrames: Int,
                    droppedFrames: Long,
                ) {
                    synchronized(backlog) { backlog += queuedFrames to droppedFrames }
                }
            },
        )

        try {
            assertEquals(PcmFanOutPublishResult.accepted, fanOut.publish(frame(0)))
            assertTrue(entered.await(1, TimeUnit.SECONDS))
            val started = System.nanoTime()
            repeat(99) { offset ->
                assertEquals(PcmFanOutPublishResult.accepted, fanOut.publish(frame(offset + 1L)))
            }
            val publishMilliseconds = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - started)

            assertTrue("capture-side publish took ${publishMilliseconds}ms", publishMilliseconds < 250)
            assertTrue(fanOut.awaitCanonicalProcessed(100, 2_000))
            assertEquals((0L until 100L).toList(), synchronized(encoded) { encoded.toList() })
            assertTrue(fanOut.metrics.inferenceDroppedFrames > 0)
            assertEquals(0L, fanOut.metrics.canonicalRejectedFrames)

            release.countDown()
            assertTrue(waitUntil { synchronized(backlog) { backlog.any { it.second > 0 } } })
        } finally {
            release.countDown()
            fanOut.close()
        }
    }

    @Test
    fun `failed inference consumer is isolated from canonical publishing`() {
        val encoded = mutableListOf<Long>()
        val failed = CountDownLatch(1)
        val fanOut =
            PriorityPcmFanOut(
                canonicalCapacity = 8,
                inferenceCapacity = 2,
                canonicalSink = { frame -> synchronized(encoded) { encoded += frame.sequence } },
            )
        fanOut.replaceInferenceConsumer(
            object : PcmInferenceConsumer {
                override fun consume(frame: PcmCaptureFrame) = error("injected inference failure")

                override fun onFailure(code: String) {
                    assertEquals("transcription_live_consumer_failed", code)
                    failed.countDown()
                }
            },
        )

        fanOut.use {
            repeat(4) { sequence ->
                assertEquals(PcmFanOutPublishResult.accepted, fanOut.publish(frame(sequence.toLong())))
            }
            assertTrue(failed.await(1, TimeUnit.SECONDS))
            assertTrue(fanOut.awaitCanonicalProcessed(4, 1_000))
            assertEquals((0L until 4L).toList(), synchronized(encoded) { encoded.toList() })
            assertEquals(1L, fanOut.metrics.inferenceConsumerFailures)
            assertEquals(0L, fanOut.metrics.canonicalRejectedFrames)
        }
    }

    @Test
    fun `shutdown drains canonical work without waiting for blocked inference`() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val encoded = mutableListOf<Long>()
        val fanOut =
            PriorityPcmFanOut(
                canonicalCapacity = 8,
                inferenceCapacity = 2,
                canonicalSink = { frame -> synchronized(encoded) { encoded += frame.sequence } },
                workerJoinTimeoutMillis = 1_000,
            )
        fanOut.replaceInferenceConsumer(
            PcmInferenceConsumer { _ ->
                entered.countDown()
                release.await(2, TimeUnit.SECONDS)
            },
        )

        try {
            repeat(3) { sequence -> fanOut.publish(frame(sequence.toLong())) }
            assertTrue(entered.await(1, TimeUnit.SECONDS))
            val started = System.nanoTime()

            assertTrue(fanOut.shutdown())

            val shutdownMilliseconds = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - started)
            assertTrue("shutdown waited ${shutdownMilliseconds}ms for inference", shutdownMilliseconds < 250)
            assertEquals((0L until 3L).toList(), synchronized(encoded) { encoded.toList() })
        } finally {
            release.countDown()
            fanOut.close()
        }
    }
}

private fun frame(sequence: Long) = PcmCaptureFrame(sequence, ByteArray(640))

private fun waitUntil(predicate: () -> Boolean): Boolean {
    val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(2)
    while (System.nanoTime() < deadline) {
        if (predicate()) return true
        Thread.sleep(10)
    }
    return false
}
