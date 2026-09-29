package com.loquiris.spike

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AacSpikePlanningTest {
    @Test
    fun `four hour storage estimates use exact decimal payload bytes`() {
        assertEquals(
            115_200_000L,
            AudioStorageEstimator.encodedPayloadBytes(
                bitRateBitsPerSecond = 64_000,
                durationMillis = FOUR_HOURS_MILLIS,
            ),
        )
        assertEquals(
            57_600_000L,
            AudioStorageEstimator.encodedPayloadBytes(
                bitRateBitsPerSecond = 32_000,
                durationMillis = FOUR_HOURS_MILLIS,
            ),
        )
        assertEquals(
            460_800_000L,
            AudioStorageEstimator.pcmBytes(
                sampleRateHz = 16_000,
                channelCount = 1,
                bytesPerSample = 2,
                durationMillis = FOUR_HOURS_MILLIS,
            ),
        )
    }

    @Test
    fun `AAC commit groups never exceed five seconds`() {
        val plan = AacCommitPlan.create(sampleRateHz = 16_000)

        assertEquals(1_024, plan.samplesPerFrame)
        assertEquals(78, plan.framesPerDurableCommit)
        assertEquals(4_992_000L, plan.durableCommitDurationUs)
        assertTrue(plan.durableCommitDurationUs <= 5_000_000L)
        assertEquals(60, plan.durableCommitsPerLogicalSegment)
        assertEquals(299_520_000L, plan.logicalSegmentDurationUs)
    }

    @Test
    fun `AAC commit duration remains inside five seconds at non-divisible sample rates`() {
        val plan = AacCommitPlan.create(sampleRateHz = 44_100)

        assertEquals(4_992_291L, plan.durableCommitDurationUs)
        assertTrue(plan.durableCommitDurationUs <= 5_000_000L)
    }

    @Test
    fun `storage estimates round partial bytes up`() {
        assertEquals(
            1L,
            AudioStorageEstimator.encodedPayloadBytes(
                bitRateBitsPerSecond = 1,
                durationMillis = 1,
            ),
        )
    }

    companion object {
        private const val FOUR_HOURS_MILLIS = 4 * 60 * 60 * 1_000L
    }
}
