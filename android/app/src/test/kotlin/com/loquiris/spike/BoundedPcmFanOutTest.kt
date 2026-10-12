package com.loquiris.spike

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class BoundedPcmFanOutTest {
    @Test
    fun `stalled inference drops optional work without dropping canonical PCM`() {
        val canonicalFrames = mutableListOf<Long>()
        val fanOut =
            BoundedPcmFanOut(
                canonicalCapacity = 128,
                inferenceCapacity = 2,
                canonicalSink = { frame -> canonicalFrames += frame.sequence },
            )

        fanOut.use {
            repeat(100) { sequence ->
                assertEquals(
                    PcmPublishResult.accepted,
                    fanOut.publish(PcmFrame(sequence.toLong(), ByteArray(640))),
                )
            }

            assertTrue(fanOut.awaitCanonicalProcessed(atLeast = 100, timeoutMillis = 1_000))
            assertEquals((0L until 100L).toList(), canonicalFrames)
            assertEquals(100L, fanOut.metrics.canonicalAcceptedFrames)
            assertEquals(100L, fanOut.metrics.canonicalProcessedFrames)
            assertEquals(0L, fanOut.metrics.canonicalRejectedFrames)
            assertEquals(2L, fanOut.metrics.inferenceAcceptedFrames)
            assertEquals(98L, fanOut.metrics.inferenceDroppedFrames)
            assertEquals(listOf(0L, 1L), fanOut.drainInference().map(PcmFrame::sequence))
        }
    }

    @Test
    fun `callers and canonical consumer cannot mutate inference bytes`() {
        val source = ByteArray(4) { it.toByte() }
        val fanOut =
            BoundedPcmFanOut(
                canonicalCapacity = 1,
                inferenceCapacity = 1,
                canonicalSink = { frame -> frame.copyBytes()[0] = 88 },
            )

        fanOut.use {
            val frame = PcmFrame(0, source)
            assertEquals(PcmPublishResult.accepted, fanOut.publish(frame))
            source[0] = 99
            frame.copyBytes()[0] = 77

            assertTrue(fanOut.awaitCanonicalProcessed(atLeast = 1, timeoutMillis = 1_000))
            assertEquals(0, fanOut.drainInference().single().copyBytes()[0].toInt())
        }
    }

    @Test
    fun `stalled canonical sink does not block capture publisher`() {
        val sinkEntered = CountDownLatch(1)
        val releaseSink = CountDownLatch(1)
        val publisher = Executors.newSingleThreadExecutor()
        val fanOut =
            BoundedPcmFanOut(
                canonicalCapacity = 128,
                inferenceCapacity = 1,
                canonicalSink = {
                    sinkEntered.countDown()
                    releaseSink.await(2, TimeUnit.SECONDS)
                },
            )

        try {
            assertEquals(PcmPublishResult.accepted, fanOut.publish(PcmFrame(0, ByteArray(640))))
            assertTrue(sinkEntered.await(1, TimeUnit.SECONDS))

            val results =
                publisher.submit<List<PcmPublishResult>> {
                    (1L until 100L).map { sequence ->
                        fanOut.publish(PcmFrame(sequence, ByteArray(640)))
                    }
                }.get(500, TimeUnit.MILLISECONDS)

            assertTrue(results.all { it == PcmPublishResult.accepted })
        } finally {
            releaseSink.countDown()
            publisher.shutdownNow()
            fanOut.close()
        }
    }

    @Test
    fun `canonical queue overflow is explicit and never blocks`() {
        val sinkEntered = CountDownLatch(1)
        val releaseSink = CountDownLatch(1)
        val fanOut =
            BoundedPcmFanOut(
                canonicalCapacity = 1,
                inferenceCapacity = 1,
                canonicalSink = {
                    sinkEntered.countDown()
                    releaseSink.await(2, TimeUnit.SECONDS)
                },
            )

        try {
            assertEquals(PcmPublishResult.accepted, fanOut.publish(PcmFrame(0, ByteArray(640))))
            assertTrue(sinkEntered.await(1, TimeUnit.SECONDS))
            assertEquals(PcmPublishResult.accepted, fanOut.publish(PcmFrame(1, ByteArray(640))))
            assertEquals(
                PcmPublishResult.canonicalQueueFull,
                fanOut.publish(PcmFrame(2, ByteArray(640))),
            )

            assertEquals(2L, fanOut.metrics.canonicalAcceptedFrames)
            assertEquals(1L, fanOut.metrics.canonicalRejectedFrames)
            assertEquals(1, fanOut.metrics.canonicalQueueHighWaterMark)
        } finally {
            releaseSink.countDown()
            fanOut.close()
        }
    }

    @Test
    fun `canonical sink failure is visible to later publishers`() {
        val fanOut =
            BoundedPcmFanOut(
                canonicalCapacity = 1,
                inferenceCapacity = 1,
                canonicalSink = { throw IllegalStateException("encoder failed") },
            )

        fanOut.use {
            assertEquals(PcmPublishResult.accepted, fanOut.publish(PcmFrame(0, ByteArray(640))))
            assertTrue(fanOut.awaitCanonicalProcessed(atLeast = 1, timeoutMillis = 1_000))

            assertEquals(
                PcmPublishResult.canonicalSinkFailed,
                fanOut.publish(PcmFrame(1, ByteArray(640))),
            )
            assertEquals(1L, fanOut.metrics.canonicalSinkFailures)
        }
    }
}
