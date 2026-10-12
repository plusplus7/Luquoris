package com.loquiris.spike

import kotlin.math.abs
import kotlin.math.log10
import kotlin.math.min
import kotlin.math.sqrt

data class LongAacQuality(
    val lagSamples: Int,
    val alignedSamples: Int,
    val correlation: Double,
    val signalToNoiseRatioDb: Double,
    val decodedRms: Double,
    val alignmentSearchClipped: Boolean,
    val referenceCoverage: Double,
)

object LongAacQualityEvaluator {
    fun evaluate(
        reference: ShortArray,
        decoded: ShortArray,
        maxLagSamples: Int,
        alignmentWindowSamples: Int,
    ): LongAacQuality {
        require(reference.isNotEmpty()) { "reference must not be empty" }
        require(decoded.isNotEmpty()) { "decoded must not be empty" }
        require(maxLagSamples >= 0) { "maxLagSamples must not be negative" }
        require(alignmentWindowSamples > 1) { "alignmentWindowSamples must exceed one sample" }

        val windowStart = highestEnergyWindowStart(reference, alignmentWindowSamples)
        val windowEnd = min(reference.size, windowStart + alignmentWindowSamples)
        val decodedWindowEnd = min(decoded.size, windowEnd + maxLagSamples)
        check(decodedWindowEnd - windowStart > 1) { "decoded audio does not overlap the alignment window" }
        val alignment =
            AacRoundTripQualityEvaluator.evaluate(
                reference = reference.copyOfRange(windowStart, windowEnd),
                decoded = decoded.copyOfRange(windowStart, decodedWindowEnd),
                maxLagSamples = maxLagSamples,
            )
        val sampleCount = min(reference.size, decoded.size - alignment.lagSamples)
        check(sampleCount > 1) { "not enough samples after alignment" }
        var dotProduct = 0.0
        var referenceEnergy = 0.0
        var decodedEnergy = 0.0
        var noiseEnergy = 0.0
        repeat(sampleCount) { index ->
            val referenceSample = reference[index].toDouble()
            val decodedSample = decoded[alignment.lagSamples + index].toDouble()
            dotProduct += referenceSample * decodedSample
            referenceEnergy += referenceSample * referenceSample
            decodedEnergy += decodedSample * decodedSample
            val difference = referenceSample - decodedSample
            noiseEnergy += difference * difference
        }
        check(referenceEnergy > 0.0) { "reference must contain a non-silent signal" }
        check(decodedEnergy > 0.0) { "decoded audio must contain a non-silent signal" }
        val correlation = dotProduct / sqrt(referenceEnergy * decodedEnergy)
        val signalToNoiseRatioDb =
            if (noiseEnergy == 0.0) {
                Double.POSITIVE_INFINITY
            } else {
                10.0 * log10(referenceEnergy / noiseEnergy)
            }
        return LongAacQuality(
            lagSamples = alignment.lagSamples,
            alignedSamples = sampleCount,
            correlation = correlation.coerceIn(-1.0, 1.0),
            signalToNoiseRatioDb = signalToNoiseRatioDb,
            decodedRms = sqrt(decodedEnergy / sampleCount),
            alignmentSearchClipped = alignment.alignmentSearchClipped,
            referenceCoverage = sampleCount.toDouble() / reference.size,
        )
    }

    private fun highestEnergyWindowStart(
        samples: ShortArray,
        windowSamples: Int,
    ): Int {
        var bestStart = 0
        var bestEnergy = -1L
        var start = 0
        while (start < samples.size) {
            val end = min(samples.size, start + windowSamples)
            var energy = 0L
            for (index in start until end) energy += abs(samples[index].toInt()).toLong()
            if (energy > bestEnergy) {
                bestEnergy = energy
                bestStart = start
            }
            start = end
        }
        return bestStart
    }
}

object Pcm16Downsampler {
    fun toMono16Khz(
        interleavedSamples: ShortArray,
        sourceSampleRateHz: Int,
        sourceChannelCount: Int,
    ): ShortArray {
        require(sourceSampleRateHz >= AacRoundTripSpike.SAMPLE_RATE_HZ) { "source sample rate is too low" }
        require(sourceSampleRateHz % AacRoundTripSpike.SAMPLE_RATE_HZ == 0) {
            "source sample rate must be an integer multiple of 16 kHz"
        }
        require(sourceChannelCount > 0) { "source channel count must be positive" }
        require(interleavedSamples.size % sourceChannelCount == 0) { "source PCM ends inside a frame" }
        val sourceFramesPerOutput = sourceSampleRateHz / AacRoundTripSpike.SAMPLE_RATE_HZ
        val sourceFrameCount = interleavedSamples.size / sourceChannelCount
        val outputFrameCount = sourceFrameCount / sourceFramesPerOutput
        return ShortArray(outputFrameCount) { outputIndex ->
            val firstSourceFrame = outputIndex * sourceFramesPerOutput
            var sum = 0L
            repeat(sourceFramesPerOutput) { frameOffset ->
                val firstSample = (firstSourceFrame + frameOffset) * sourceChannelCount
                repeat(sourceChannelCount) { channel -> sum += interleavedSamples[firstSample + channel] }
            }
            (sum / (sourceFramesPerOutput * sourceChannelCount)).toShort()
        }
    }
}
