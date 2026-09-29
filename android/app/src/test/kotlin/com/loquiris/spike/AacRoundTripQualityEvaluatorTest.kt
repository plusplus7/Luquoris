package com.loquiris.spike

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AacRoundTripQualityEvaluatorTest {
    @Test
    fun `codec delay is aligned before correlation and signal to noise are measured`() {
        val reference =
            shortArrayOf(
                1_000,
                -2_000,
                3_000,
                -4_000,
                5_000,
                -6_000,
                7_000,
                -8_000,
            )
        val decoded = shortArrayOf(0, 0, 0, 1_000, -2_000, 3_000, -4_000, 5_000, -6_000, 7_000, -8_000)

        val result =
            AacRoundTripQualityEvaluator.evaluate(
                reference = reference,
                decoded = decoded,
                maxLagSamples = 4,
            )

        assertEquals(3, result.lagSamples)
        assertEquals(8, result.alignedSamples)
        assertTrue(result.correlation > 0.999)
        assertTrue(result.signalToNoiseRatioDb > 90.0)
        assertTrue(result.decodedRms > 4_000.0)
    }

    @Test
    fun `best alignment at the search limit is reported as clipped`() {
        val reference = shortArrayOf(2_000, -3_000, 5_000, -7_000)
        val decoded = shortArrayOf(0, 0, 0, 2_000, -3_000, 5_000, -7_000)

        val result =
            AacRoundTripQualityEvaluator.evaluate(
                reference = reference,
                decoded = decoded,
                maxLagSamples = 3,
            )

        assertTrue(result.alignmentSearchClipped)
    }

    @Test
    fun `short perfect decoded prefix reports insufficient reference coverage`() {
        val result =
            AacRoundTripQualityEvaluator.evaluate(
                reference = shortArrayOf(1_000, -2_000, 3_000, -4_000, 5_000, -6_000, 7_000, -8_000),
                decoded = shortArrayOf(1_000, -2_000, 3_000, -4_000),
                maxLagSamples = 10,
            )

        assertEquals(0.5, result.referenceCoverage, 0.000_001)
        assertTrue(result.alignmentSearchClipped)
    }
}
