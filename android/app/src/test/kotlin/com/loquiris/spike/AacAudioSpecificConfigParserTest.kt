package com.loquiris.spike

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class AacAudioSpecificConfigParserTest {
    @Test
    fun `parses AAC-LC 16 kHz mono audio specific config`() {
        val config = AacAudioSpecificConfigParser.parse(byteArrayOf(0x14, 0x08))

        assertEquals(2, config.audioObjectType)
        assertEquals(16_000, config.sampleRateHz)
        assertEquals(1, config.channelConfiguration)
    }

    @Test
    fun `target contract rejects a semantically different encoder config`() {
        assertThrows(IllegalArgumentException::class.java) {
            AacAudioSpecificConfigParser.requireAacLc16KhzMono(byteArrayOf(0x12, 0x08))
        }
    }
}
