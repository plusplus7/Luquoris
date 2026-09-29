package com.loquiris.spike

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class AdtsAacFrameCodecTest {
    @Test
    fun `wrap emits an MPEG-4 AAC-LC 16 kHz mono ADTS header`() {
        val frame =
            AdtsAacFrameCodec.wrap(
                accessUnit = byteArrayOf(0x11, 0x22, 0x33),
                sampleRateHz = 16_000,
                channelCount = 1,
            )

        assertArrayEquals(
            byteArrayOf(
                0xFF.toByte(),
                0xF1.toByte(),
                0x60,
                0x40,
                0x01,
                0x5F,
                0xFC.toByte(),
            ),
            frame.copyOfRange(0, 7),
        )
        assertArrayEquals(byteArrayOf(0x11, 0x22, 0x33), frame.copyOfRange(7, frame.size))
    }

    @Test
    fun `unwrap returns every authentic access unit without ADTS headers`() {
        val first = byteArrayOf(1, 2, 3, 4)
        val second = byteArrayOf(5, 6)
        val stream =
            AdtsAacFrameCodec.wrap(first, sampleRateHz = 16_000, channelCount = 1) +
                AdtsAacFrameCodec.wrap(second, sampleRateHz = 16_000, channelCount = 1)

        val accessUnits = AdtsAacFrameCodec.unwrapCompleteFrames(stream)

        assertEquals(2, accessUnits.size)
        assertArrayEquals(first, accessUnits[0])
        assertArrayEquals(second, accessUnits[1])
    }

    @Test
    fun `unsupported sample rate is rejected instead of emitting a false header`() {
        assertThrows(IllegalArgumentException::class.java) {
            AdtsAacFrameCodec.wrap(byteArrayOf(1), sampleRateHz = 12_345, channelCount = 1)
        }
    }
}
