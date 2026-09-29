package com.loquiris.spike

import org.junit.Assert.assertEquals
import org.junit.Test

class AdtsRecoveryScannerTest {
    @Test
    fun `truncated tail recovers every preceding complete AAC frame`() {
        val stream = adtsFrame(100) + adtsFrame(100) + adtsFrame(100)

        val result = AdtsRecoveryScanner.scan(stream.copyOf(250))

        assertEquals(2, result.completeFrames)
        assertEquals(200, result.completeBytes)
        assertEquals(50, result.trailingBytes)
        assertEquals(null, result.invalidOffset)
    }

    @Test
    fun `invalid sync stops at the last known complete frame`() {
        val stream = adtsFrame(100) + adtsFrame(100)
        stream[100] = 0

        val result = AdtsRecoveryScanner.scan(stream)

        assertEquals(1, result.completeFrames)
        assertEquals(100, result.completeBytes)
        assertEquals(100, result.trailingBytes)
        assertEquals(100, result.invalidOffset)
    }

    @Test
    fun `empty stream is a valid zero-frame prefix`() {
        assertEquals(
            AdtsRecoveryResult(
                completeFrames = 0,
                completeBytes = 0,
                trailingBytes = 0,
                invalidOffset = null,
            ),
            AdtsRecoveryScanner.scan(ByteArray(0)),
        )
    }
}

private fun adtsFrame(length: Int): ByteArray {
    require(length >= 7)
    return ByteArray(length).also { frame ->
        frame[0] = 0xFF.toByte()
        frame[1] = 0xF1.toByte()
        frame[2] = 0x60.toByte()
        frame[3] = ((length ushr 11) and 0x03).toByte()
        frame[4] = ((length ushr 3) and 0xFF).toByte()
        frame[5] = (((length and 0x07) shl 5) or 0x1F).toByte()
        frame[6] = 0xFC.toByte()
    }
}
