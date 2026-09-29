package com.loquiris.spike

data class AdtsRecoveryResult(
    val completeFrames: Int,
    val completeBytes: Int,
    val trailingBytes: Int,
    val invalidOffset: Int?,
)

object AdtsRecoveryScanner {
    fun scan(bytes: ByteArray): AdtsRecoveryResult {
        var offset = 0
        var completeFrames = 0
        while (offset < bytes.size) {
            val remaining = bytes.size - offset
            if (remaining < ADTS_HEADER_BYTES_WITHOUT_CRC) {
                break
            }
            if (!hasSyncWord(bytes, offset)) {
                return result(bytes.size, offset, completeFrames, offset)
            }
            val protectionAbsent = unsigned(bytes[offset + 1]) and 0x01 == 1
            val headerBytes =
                if (protectionAbsent) {
                    ADTS_HEADER_BYTES_WITHOUT_CRC
                } else {
                    ADTS_HEADER_BYTES_WITH_CRC
                }
            val frameBytes = frameLength(bytes, offset)
            if (frameBytes < headerBytes) {
                return result(bytes.size, offset, completeFrames, offset)
            }
            if (frameBytes > remaining) {
                break
            }
            offset += frameBytes
            completeFrames += 1
        }
        return result(bytes.size, offset, completeFrames, null)
    }

    private fun result(
        totalBytes: Int,
        completeBytes: Int,
        completeFrames: Int,
        invalidOffset: Int?,
    ): AdtsRecoveryResult =
        AdtsRecoveryResult(
            completeFrames = completeFrames,
            completeBytes = completeBytes,
            trailingBytes = totalBytes - completeBytes,
            invalidOffset = invalidOffset,
        )

    private fun hasSyncWord(bytes: ByteArray, offset: Int): Boolean =
        unsigned(bytes[offset]) == 0xFF && unsigned(bytes[offset + 1]) and 0xF6 == 0xF0

    private fun frameLength(bytes: ByteArray, offset: Int): Int =
        ((unsigned(bytes[offset + 3]) and 0x03) shl 11) or
            (unsigned(bytes[offset + 4]) shl 3) or
            ((unsigned(bytes[offset + 5]) and 0xE0) ushr 5)

    private fun unsigned(value: Byte): Int = value.toInt() and 0xFF

    private const val ADTS_HEADER_BYTES_WITHOUT_CRC = 7
    private const val ADTS_HEADER_BYTES_WITH_CRC = 9
}
