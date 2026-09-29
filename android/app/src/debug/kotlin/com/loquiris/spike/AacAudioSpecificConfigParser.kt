package com.loquiris.spike

data class AacAudioSpecificConfig(
    val audioObjectType: Int,
    val sampleRateHz: Int,
    val channelConfiguration: Int,
)

object AacAudioSpecificConfigParser {
    fun parse(bytes: ByteArray): AacAudioSpecificConfig {
        val bits = BitReader(bytes)
        val audioObjectType =
            bits.read(AUDIO_OBJECT_TYPE_BITS).let { value ->
                if (value == ESCAPED_AUDIO_OBJECT_TYPE) {
                    ESCAPED_AUDIO_OBJECT_TYPE_BASE + bits.read(ESCAPED_AUDIO_OBJECT_TYPE_BITS)
                } else {
                    value
                }
            }
        val sampleRateIndex = bits.read(SAMPLE_RATE_INDEX_BITS)
        val sampleRateHz =
            if (sampleRateIndex == EXPLICIT_SAMPLE_RATE_INDEX) {
                bits.read(EXPLICIT_SAMPLE_RATE_BITS)
            } else {
                sampleRatesHz.getOrNull(sampleRateIndex)
                    ?: throw IllegalArgumentException("Reserved AAC sample-rate index: $sampleRateIndex")
            }
        val channelConfiguration = bits.read(CHANNEL_CONFIGURATION_BITS)
        return AacAudioSpecificConfig(audioObjectType, sampleRateHz, channelConfiguration)
    }

    fun requireAacLc16KhzMono(bytes: ByteArray): AacAudioSpecificConfig =
        parse(bytes).also { config ->
            require(config.audioObjectType == AAC_LC_AUDIO_OBJECT_TYPE) {
                "Encoder AAC object type ${config.audioObjectType} is not AAC-LC"
            }
            require(config.sampleRateHz == TARGET_SAMPLE_RATE_HZ) {
                "Encoder AAC sample rate ${config.sampleRateHz} Hz is not 16000 Hz"
            }
            require(config.channelConfiguration == TARGET_CHANNEL_CONFIGURATION) {
                "Encoder AAC channel configuration ${config.channelConfiguration} is not mono"
            }
        }

    private class BitReader(
        private val bytes: ByteArray,
    ) {
        private var bitOffset = 0

        fun read(bitCount: Int): Int {
            require(bitCount > 0) { "bitCount must be positive" }
            require(bitOffset + bitCount <= bytes.size * Byte.SIZE_BITS) {
                "Truncated AAC AudioSpecificConfig"
            }
            var value = 0
            repeat(bitCount) {
                val byte = bytes[bitOffset / Byte.SIZE_BITS].toInt() and 0xFF
                val bit = byte ushr (Byte.SIZE_BITS - 1 - bitOffset % Byte.SIZE_BITS) and 1
                value = value shl 1 or bit
                bitOffset += 1
            }
            return value
        }
    }

    private const val AUDIO_OBJECT_TYPE_BITS = 5
    private const val ESCAPED_AUDIO_OBJECT_TYPE = 31
    private const val ESCAPED_AUDIO_OBJECT_TYPE_BASE = 32
    private const val ESCAPED_AUDIO_OBJECT_TYPE_BITS = 6
    private const val SAMPLE_RATE_INDEX_BITS = 4
    private const val EXPLICIT_SAMPLE_RATE_INDEX = 15
    private const val EXPLICIT_SAMPLE_RATE_BITS = 24
    private const val CHANNEL_CONFIGURATION_BITS = 4
    private const val AAC_LC_AUDIO_OBJECT_TYPE = 2
    private const val TARGET_SAMPLE_RATE_HZ = 16_000
    private const val TARGET_CHANNEL_CONFIGURATION = 1

    private val sampleRatesHz =
        listOf(
            96_000,
            88_200,
            64_000,
            48_000,
            44_100,
            32_000,
            24_000,
            22_050,
            16_000,
            12_000,
            11_025,
            8_000,
            7_350,
        )
}
