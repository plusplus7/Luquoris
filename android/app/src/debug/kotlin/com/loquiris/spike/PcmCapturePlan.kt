package com.loquiris.spike

class PcmCapturePlan private constructor(
    val sampleRateHz: Int,
    val channelCount: Int,
    val bytesPerSample: Int,
    val bufferBytes: Int,
) {
    val bytesPerTwentyMilliseconds: Int =
        sampleRateHz * channelCount * bytesPerSample * FRAME_MILLIS / 1_000

    fun targetBytes(durationMillis: Long): Long {
        require(durationMillis in 1..MAX_SPIKE_DURATION_MILLIS) {
            "durationMillis must be between 1 and $MAX_SPIKE_DURATION_MILLIS"
        }
        return sampleRateHz.toLong() * channelCount * bytesPerSample * durationMillis / 1_000
    }

    companion object {
        const val SAMPLE_RATE_HZ: Int = 16_000
        const val CHANNEL_COUNT: Int = 1
        const val BYTES_PER_SAMPLE: Int = 2
        const val FRAME_MILLIS: Int = 20
        const val MAX_SPIKE_DURATION_MILLIS: Long = 60_000

        fun create(minBufferBytes: Int): PcmCapturePlan {
            require(minBufferBytes > 0) { "minBufferBytes must be positive" }
            val frameBytes =
                SAMPLE_RATE_HZ * CHANNEL_COUNT * BYTES_PER_SAMPLE * FRAME_MILLIS / 1_000
            val frameCount = (minBufferBytes + frameBytes - 1) / frameBytes
            return PcmCapturePlan(
                sampleRateHz = SAMPLE_RATE_HZ,
                channelCount = CHANNEL_COUNT,
                bytesPerSample = BYTES_PER_SAMPLE,
                bufferBytes = frameCount * frameBytes,
            )
        }
    }
}
