package com.loquiris.spike

object AudioStorageEstimator {
    fun encodedPayloadBytes(
        bitRateBitsPerSecond: Int,
        durationMillis: Long,
    ): Long {
        require(bitRateBitsPerSecond > 0) { "bitRateBitsPerSecond must be positive" }
        require(durationMillis >= 0) { "durationMillis must be non-negative" }
        val bitMillis = Math.multiplyExact(bitRateBitsPerSecond.toLong(), durationMillis)
        return ceilDivide(bitMillis, 8_000L)
    }

    fun pcmBytes(
        sampleRateHz: Int,
        channelCount: Int,
        bytesPerSample: Int,
        durationMillis: Long,
    ): Long {
        require(sampleRateHz > 0) { "sampleRateHz must be positive" }
        require(channelCount > 0) { "channelCount must be positive" }
        require(bytesPerSample > 0) { "bytesPerSample must be positive" }
        require(durationMillis >= 0) { "durationMillis must be non-negative" }
        val samples = Math.multiplyExact(sampleRateHz.toLong(), channelCount.toLong())
        val sampleBytes = Math.multiplyExact(samples, bytesPerSample.toLong())
        val byteMillis = Math.multiplyExact(sampleBytes, durationMillis)
        return ceilDivide(byteMillis, 1_000L)
    }

    private fun ceilDivide(
        numerator: Long,
        denominator: Long,
    ): Long = if (numerator == 0L) 0L else 1L + (numerator - 1L) / denominator
}

class AacCommitPlan private constructor(
    val samplesPerFrame: Int,
    val framesPerDurableCommit: Int,
    val durableCommitDurationUs: Long,
    val durableCommitsPerLogicalSegment: Int,
    val logicalSegmentDurationUs: Long,
) {
    companion object {
        private const val AAC_LC_SAMPLES_PER_FRAME = 1_024
        private const val MAX_DURABLE_COMMIT_US = 5_000_000L
        private const val TARGET_LOGICAL_SEGMENT_US = 300_000_000L

        fun create(sampleRateHz: Int): AacCommitPlan {
            require(sampleRateHz > 0) { "sampleRateHz must be positive" }
            val sampleMicrosPerFrame = AAC_LC_SAMPLES_PER_FRAME.toLong() * 1_000_000L
            val framesPerCommit =
                (MAX_DURABLE_COMMIT_US * sampleRateHz / sampleMicrosPerFrame).toInt()
            require(framesPerCommit > 0) { "AAC frame exceeds durable commit target" }
            val durableCommitSamples = framesPerCommit.toLong() * AAC_LC_SAMPLES_PER_FRAME
            val durableCommitUs = ceilDivide(durableCommitSamples * 1_000_000L, sampleRateHz)
            val commitsPerSegment = (TARGET_LOGICAL_SEGMENT_US / durableCommitUs).toInt()
            require(commitsPerSegment > 0) { "durable commit exceeds logical segment target" }
            val logicalSegmentSamples = durableCommitSamples * commitsPerSegment
            return AacCommitPlan(
                samplesPerFrame = AAC_LC_SAMPLES_PER_FRAME,
                framesPerDurableCommit = framesPerCommit,
                durableCommitDurationUs = durableCommitUs,
                durableCommitsPerLogicalSegment = commitsPerSegment,
                logicalSegmentDurationUs =
                    ceilDivide(logicalSegmentSamples * 1_000_000L, sampleRateHz),
            )
        }

        private fun ceilDivide(
            numerator: Long,
            denominator: Int,
        ): Long = if (numerator == 0L) 0L else 1L + (numerator - 1L) / denominator
    }
}
