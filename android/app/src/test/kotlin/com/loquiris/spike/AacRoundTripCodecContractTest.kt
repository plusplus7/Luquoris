package com.loquiris.spike

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class AacRoundTripCodecContractTest {
    @Test
    fun `codec config buffer supplies CSD when output format omits it`() {
        val configBufferCsd = byteArrayOf(0x14, 0x08)

        val selected = selectCodecSpecificData(emptyList(), listOf(configBufferCsd))

        assertEquals(1, selected.size)
        assertArrayEquals(configBufferCsd, selected.single())
    }

    @Test
    fun `duplicate access unit timestamps are rejected`() {
        assertFalse(timestampsAreStrictlyIncreasing(listOf(0L, 64_000L, 64_000L)))
        assertTrue(timestampsAreStrictlyIncreasing(listOf(0L, 64_000L, 128_000L)))
    }

    @Test
    fun `decoder end of stream timestamp follows the final access unit`() {
        val eosTimestamp = mediaEndTimestampMicroseconds(totalSamples = 32_000, sampleRateHz = 16_000)

        assertEquals(2_000_000L, eosTimestamp)
        assertTrue(timestampsAreStrictlyIncreasing(listOf(1_856_000L, 1_920_000L, eosTimestamp)))
    }

    @Test
    fun `cleanup preserves primary failure and still attempts stop and release`() {
        val primary = IllegalStateException("codec timed out")
        var stopAttempted = false
        var releaseAttempted = false

        val result =
            finishCodecLifecycle(
                primaryFailure = primary,
                stop = {
                    stopAttempted = true
                    error("stop failed")
                },
                release = {
                    releaseAttempted = true
                    error("release failed")
                },
            )

        assertSame(primary, result)
        assertTrue(stopAttempted)
        assertTrue(releaseAttempted)
        assertEquals(2, primary.suppressed.size)
    }
}
