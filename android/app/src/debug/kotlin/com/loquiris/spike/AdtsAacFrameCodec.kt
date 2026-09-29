package com.loquiris.spike

object AdtsAacFrameCodec {
    fun wrap(
        accessUnit: ByteArray,
        sampleRateHz: Int,
        channelCount: Int,
    ): ByteArray {
        require(accessUnit.isNotEmpty()) { "AAC access unit must not be empty" }
        val sampleRateIndex =
            sampleRateIndexes[sampleRateHz]
                ?: throw IllegalArgumentException("Unsupported ADTS sample rate: $sampleRateHz Hz")
        require(channelCount in 1..7) { "ADTS channel count must be between 1 and 7" }

        val frameLength = HEADER_BYTES + accessUnit.size
        require(frameLength <= MAX_FRAME_BYTES) { "ADTS frame exceeds 13-bit length limit" }

        val header =
            byteArrayOf(
                0xFF.toByte(),
                0xF1.toByte(),
                ((AAC_LC_PROFILE shl 6) or (sampleRateIndex shl 2) or (channelCount ushr 2)).toByte(),
                (((channelCount and 0x03) shl 6) or (frameLength ushr 11)).toByte(),
                ((frameLength ushr 3) and 0xFF).toByte(),
                (((frameLength and 0x07) shl 5) or 0x1F).toByte(),
                0xFC.toByte(),
            )
        return header + accessUnit
    }

    fun unwrapCompleteFrames(stream: ByteArray): List<ByteArray> {
        val recovery = AdtsRecoveryScanner.scan(stream)
        require(recovery.invalidOffset == null) {
            "Invalid ADTS frame at byte ${recovery.invalidOffset}"
        }

        val accessUnits = ArrayList<ByteArray>(recovery.completeFrames)
        var offset = 0
        while (offset < recovery.completeBytes) {
            val protectionAbsent = unsigned(stream[offset + 1]) and 0x01 == 1
            val headerBytes = if (protectionAbsent) HEADER_BYTES else HEADER_BYTES_WITH_CRC
            val frameBytes = frameLength(stream, offset)
            accessUnits += stream.copyOfRange(offset + headerBytes, offset + frameBytes)
            offset += frameBytes
        }
        return accessUnits
    }

    private fun frameLength(bytes: ByteArray, offset: Int): Int =
        ((unsigned(bytes[offset + 3]) and 0x03) shl 11) or
            (unsigned(bytes[offset + 4]) shl 3) or
            ((unsigned(bytes[offset + 5]) and 0xE0) ushr 5)

    private fun unsigned(value: Byte): Int = value.toInt() and 0xFF

    private const val AAC_LC_PROFILE = 1
    private const val HEADER_BYTES = 7
    private const val HEADER_BYTES_WITH_CRC = 9
    private const val MAX_FRAME_BYTES = 0x1FFF

    private val sampleRateIndexes =
        mapOf(
            96_000 to 0,
            88_200 to 1,
            64_000 to 2,
            48_000 to 3,
            44_100 to 4,
            32_000 to 5,
            24_000 to 6,
            22_050 to 7,
            16_000 to 8,
            12_000 to 9,
            11_025 to 10,
            8_000 to 11,
            7_350 to 12,
        )
}
