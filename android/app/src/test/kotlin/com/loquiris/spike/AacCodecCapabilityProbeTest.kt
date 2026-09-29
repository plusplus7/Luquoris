package com.loquiris.spike

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AacCodecCapabilityProbeTest {
    @Test
    fun `one broken OEM codec does not suppress later candidates`() {
        val results =
            inspectAacCandidatesSafely(
                candidates = listOf("broken.codec", "working.codec"),
                inspect = { name ->
                    if (name == "broken.codec") {
                        throw IllegalStateException("OEM capability query failed")
                    }
                    capability(name, configureSucceeded = true)
                },
                failure = { name -> capability(name, failureCode = "capability_query_failed") },
            )

        assertEquals(2, results.size)
        assertFalse(results[0].meetsTarget)
        assertEquals("capability_query_failed", results[0].failureCode)
        assertTrue(results[1].meetsTarget)
    }

    @Test
    fun `cleanup failure becomes a stable result instead of escaping`() {
        val result =
            resultAfterCleanup(
                result = "configured",
                cleanup = { throw IllegalStateException("OEM release failed") },
                cleanupFailure = { "codec_release_failed" },
            )

        assertEquals("codec_release_failed", result)
    }
}

private fun capability(
    name: String,
    configureSucceeded: Boolean = false,
    failureCode: String? = null,
): AacEncoderCapability =
    AacEncoderCapability(
        codecName = name,
        canonicalName = name,
        hardwareAccelerated = false,
        softwareOnly = true,
        vendor = false,
        supportsSampleRate = configureSucceeded,
        supportsBitRate = configureSucceeded,
        supportsChannelCount = configureSucceeded,
        supportsAacLcProfile = configureSucceeded,
        configureSucceeded = configureSucceeded,
        failureCode = failureCode,
    )
