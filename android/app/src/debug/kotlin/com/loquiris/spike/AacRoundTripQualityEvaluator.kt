package com.loquiris.spike

import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

data class AacRoundTripQuality(
    val lagSamples: Int,
    val alignedSamples: Int,
    val correlation: Double,
    val signalToNoiseRatioDb: Double,
    val decodedRms: Double,
    val alignmentSearchClipped: Boolean,
    val referenceCoverage: Double,
)

object AacRoundTripQualityEvaluator {
    fun evaluate(
        reference: ShortArray,
        decoded: ShortArray,
        maxLagSamples: Int,
    ): AacRoundTripQuality {
        require(reference.isNotEmpty()) { "reference must not be empty" }
        require(decoded.isNotEmpty()) { "decoded must not be empty" }
        require(maxLagSamples >= 0) { "maxLagSamples must not be negative" }

        val effectiveMaxLagSamples = min(maxLagSamples, decoded.lastIndex)
        val alignment =
            (0..effectiveMaxLagSamples)
                .map { lag -> alignmentAt(reference, decoded, lag) }
                .filter { candidate -> candidate.sampleCount > 1 }
                .maxByOrNull(Alignment::correlation)
                ?: error("not enough aligned samples")

        var signalEnergy = 0.0
        var noiseEnergy = 0.0
        var decodedEnergy = 0.0
        repeat(alignment.sampleCount) { offset ->
            val referenceSample = reference[offset].toDouble()
            val decodedSample = decoded[alignment.lagSamples + offset].toDouble()
            val difference = referenceSample - decodedSample
            signalEnergy += referenceSample * referenceSample
            noiseEnergy += difference * difference
            decodedEnergy += decodedSample * decodedSample
        }
        require(signalEnergy > 0.0) { "reference must contain a non-silent signal" }

        val snr =
            if (noiseEnergy == 0.0) {
                Double.POSITIVE_INFINITY
            } else {
                10.0 * log10(signalEnergy / noiseEnergy)
            }
        return AacRoundTripQuality(
            lagSamples = alignment.lagSamples,
            alignedSamples = alignment.sampleCount,
            correlation = alignment.correlation,
            signalToNoiseRatioDb = snr,
            decodedRms = sqrt(decodedEnergy / alignment.sampleCount),
            alignmentSearchClipped =
                effectiveMaxLagSamples < maxLagSamples || alignment.lagSamples == effectiveMaxLagSamples,
            referenceCoverage = alignment.sampleCount.toDouble() / reference.size,
        )
    }

    private fun alignmentAt(
        reference: ShortArray,
        decoded: ShortArray,
        lagSamples: Int,
    ): Alignment {
        val sampleCount = min(reference.size, decoded.size - lagSamples)
        if (sampleCount <= 1) return Alignment(lagSamples, sampleCount, -1.0)

        var dotProduct = 0.0
        var referenceEnergy = 0.0
        var decodedEnergy = 0.0
        repeat(sampleCount) { offset ->
            val referenceSample = reference[offset].toDouble()
            val decodedSample = decoded[lagSamples + offset].toDouble()
            dotProduct += referenceSample * decodedSample
            referenceEnergy += referenceSample * referenceSample
            decodedEnergy += decodedSample * decodedSample
        }
        val denominator = sqrt(referenceEnergy * decodedEnergy)
        val correlation = if (denominator == 0.0) -1.0 else dotProduct / denominator
        return Alignment(lagSamples, sampleCount, max(-1.0, min(1.0, correlation)))
    }

    private data class Alignment(
        val lagSamples: Int,
        val sampleCount: Int,
        val correlation: Double,
    )
}
