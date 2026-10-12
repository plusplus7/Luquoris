package com.loquiris.spike

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class LongAacQualityEvaluatorTest {
    @Test
    fun publishedMediaRollbackKeepsPrimaryAndRejectsZeroDeletedRows() {
        val primary = IllegalStateException("publish failed")
        var deleteAttempted = false

        val result =
            finishPublishedMediaRollback(primary) {
                deleteAttempted = true
                0
            }

        assertSame(primary, result)
        assertTrue(deleteAttempted)
        assertEquals(
            listOf("Published media rollback deleted 0 rows"),
            result.suppressed.map(Throwable::message),
        )
    }

    @Test
    fun sourceDecoderCleanupPreservesPrimaryAndAttemptsEveryRelease() {
        val primary = IllegalStateException("decode failed")
        var codecStopped = false
        var codecReleased = false

        val result =
            finishSourceDecoderLifecycle(
                primaryFailure = primary,
                extractorRelease = { throw IllegalArgumentException("extractor release failed") },
                codecStop = { codecStopped = true },
                codecRelease = { codecReleased = true },
            )

        assertSame(primary, result)
        assertTrue(codecStopped)
        assertTrue(codecReleased)
        assertEquals(listOf("extractor release failed"), result?.suppressed?.map(Throwable::message))
    }

    @Test
    fun downmixesStereoAndBoxFiltersFortyEightKilohertzToSixteenKilohertz() {
        val source = shortArrayOf(6, 12, 18, 24, 30, 36, 42, 48, 54, 60, 66, 72)

        val result =
            Pcm16Downsampler.toMono16Khz(
                interleavedSamples = source,
                sourceSampleRateHz = 48_000,
                sourceChannelCount = 2,
            )

        assertTrue(result.contentEquals(shortArrayOf(21, 57)))
    }

    @Test
    fun findsEncoderLagAfterLeadingSilenceAndScoresTheFullSignal() {
        val reference =
            ShortArray(128_000) { index ->
                if (index < 40_000) 0 else (((index * 97L) % 20_001L) - 10_000L).toInt().toShort()
            }
        val decoded = ShortArray(reference.size + 2_048)
        reference.copyInto(decoded, destinationOffset = 2_048)

        val quality =
            LongAacQualityEvaluator.evaluate(
                reference = reference,
                decoded = decoded,
                maxLagSamples = 4_096,
                alignmentWindowSamples = 32_000,
            )

        assertEquals(2_048, quality.lagSamples)
        assertEquals(reference.size, quality.alignedSamples)
        assertEquals(1.0, quality.referenceCoverage, 0.0)
        assertEquals(1.0, quality.correlation, 0.000_001)
        assertTrue(quality.signalToNoiseRatioDb.isInfinite())
        assertTrue(!quality.alignmentSearchClipped)
    }
}
