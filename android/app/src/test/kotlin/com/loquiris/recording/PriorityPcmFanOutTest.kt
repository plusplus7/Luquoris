package com.loquiris.recording

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PriorityPcmFanOutTest {
    @Test
    fun `optional inference overflow drops derived work while canonical order remains complete`() {
        val encoded = mutableListOf<Long>()
        val fanOut =
            PriorityPcmFanOut(
                canonicalCapacity = 128,
                inferenceCapacity = 2,
                canonicalSink = { frame -> encoded += frame.sequence },
            )

        fanOut.use {
            repeat(100) { sequence ->
                assertEquals(
                    PcmFanOutPublishResult.accepted,
                    fanOut.publish(PcmCaptureFrame(sequence.toLong(), ByteArray(640))),
                )
            }
            assertTrue(fanOut.awaitCanonicalProcessed(100, 1_000))
            assertEquals((0L until 100L).toList(), encoded)
            assertEquals(98L, fanOut.metrics.inferenceDroppedFrames)
            assertEquals(0L, fanOut.metrics.canonicalRejectedFrames)
        }
    }

    @Test
    fun `canonical overflow is immediate explicit and measurable`() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val fanOut =
            PriorityPcmFanOut(
                canonicalCapacity = 1,
                inferenceCapacity = 1,
                canonicalSink = {
                    entered.countDown()
                    release.await(2, TimeUnit.SECONDS)
                },
            )
        try {
            assertEquals(PcmFanOutPublishResult.accepted, fanOut.publish(PcmCaptureFrame(0, ByteArray(640))))
            assertTrue(entered.await(1, TimeUnit.SECONDS))
            assertEquals(PcmFanOutPublishResult.accepted, fanOut.publish(PcmCaptureFrame(1, ByteArray(640))))
            assertEquals(
                PcmFanOutPublishResult.canonicalQueueFull,
                fanOut.publish(PcmCaptureFrame(2, ByteArray(640))),
            )
            assertEquals(1L, fanOut.metrics.canonicalRejectedFrames)
            assertEquals(1, fanOut.metrics.canonicalQueueHighWaterMark)
        } finally {
            release.countDown()
            fanOut.close()
        }
    }

    @Test
    fun `canonical sink failure becomes sticky typed publisher failure`() {
        val fanOut =
            PriorityPcmFanOut(
                canonicalCapacity = 1,
                inferenceCapacity = 1,
                canonicalSink = { error("encoder failed") },
            )

        fanOut.use {
            assertEquals(PcmFanOutPublishResult.accepted, fanOut.publish(PcmCaptureFrame(0, ByteArray(640))))
            assertTrue(fanOut.awaitCanonicalProcessed(1, 1_000))
            assertEquals(
                PcmFanOutPublishResult.canonicalSinkFailed,
                fanOut.publish(PcmCaptureFrame(1, ByteArray(640))),
            )
            assertEquals(1L, fanOut.metrics.canonicalSinkFailures)
        }
    }
}
