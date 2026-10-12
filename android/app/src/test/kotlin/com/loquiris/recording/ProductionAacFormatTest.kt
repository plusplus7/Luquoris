package com.loquiris.recording

import android.media.MediaFormat
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ProductionAacFormatTest {
    @Test
    fun `accepts AAC LC mono 16k 64k output and matching ASC`() {
        assertTrue(
            ProductionAacFormat.isExpected(
                mimeType = MediaFormat.MIMETYPE_AUDIO_AAC,
                sampleRateHz = 16_000,
                channelCount = 1,
                aacProfile = 2,
                bitRateBitsPerSecond = 64_000,
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
            ),
        )
    }

    @Test
    fun `rejects mismatched negotiated fields or audio specific config`() {
        val valid = listOf(byteArrayOf(0x14, 0x08))
        assertFalse(ProductionAacFormat.isExpected("audio/other", 16_000, 1, 2, 64_000, valid))
        assertFalse(ProductionAacFormat.isExpected(MediaFormat.MIMETYPE_AUDIO_AAC, 48_000, 1, 2, 64_000, valid))
        assertFalse(ProductionAacFormat.isExpected(MediaFormat.MIMETYPE_AUDIO_AAC, 16_000, 2, 2, 64_000, valid))
        assertFalse(ProductionAacFormat.isExpected(MediaFormat.MIMETYPE_AUDIO_AAC, 16_000, 1, 5, 64_000, valid))
        assertFalse(ProductionAacFormat.isExpected(MediaFormat.MIMETYPE_AUDIO_AAC, 16_000, 1, 2, 32_000, valid))
        assertFalse(
            ProductionAacFormat.isExpected(
                MediaFormat.MIMETYPE_AUDIO_AAC,
                16_000,
                1,
                2,
                64_000,
                listOf(byteArrayOf(0x12, 0x08)),
            ),
        )
    }

    @Test
    fun `allows omitted optional profile and bitrate only when ASC is authoritative`() {
        assertTrue(
            ProductionAacFormat.isExpected(
                mimeType = MediaFormat.MIMETYPE_AUDIO_AAC,
                sampleRateHz = 16_000,
                channelCount = 1,
                aacProfile = null,
                bitRateBitsPerSecond = null,
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
            ),
        )
    }
}
