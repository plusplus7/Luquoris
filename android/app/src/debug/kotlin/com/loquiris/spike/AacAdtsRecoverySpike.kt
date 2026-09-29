package com.loquiris.spike

import org.json.JSONObject
import java.io.File
import kotlin.math.sqrt

data class AacAdtsRecoveryReport(
    val encodedAccessUnits: Int,
    val recoveredAccessUnits: Int,
    val durableDataBytes: Int,
    val recoveredDataBytes: Int,
    val discardedTailBytes: Int,
    val recoveredPayloadsMatchEncodedPrefix: Boolean,
    val decodedSamples: Int,
    val decodedSampleCoverage: Double,
    val decodedRms: Double,
    val encoderName: String,
    val decoderName: String,
    val encoderAudioObjectType: Int,
    val encoderSampleRateHz: Int,
    val encoderChannelConfiguration: Int,
    val encoderAudioSpecificConfigHex: String,
    val recoveryAudioSpecificConfigHex: String,
    val decoderSampleRateHz: Int,
    val decoderChannelCount: Int,
) {
    fun toJson(): String =
        JSONObject()
            .put("schemaVersion", 1)
            .put("sampleRateHz", AacRoundTripSpike.SAMPLE_RATE_HZ)
            .put("channelCount", AacRoundTripSpike.CHANNEL_COUNT)
            .put("codec", "AAC-LC in ADTS")
            .put("encodedAccessUnits", encodedAccessUnits)
            .put("recoveredAccessUnits", recoveredAccessUnits)
            .put("durableDataBytes", durableDataBytes)
            .put("recoveredDataBytes", recoveredDataBytes)
            .put("discardedTailBytes", discardedTailBytes)
            .put("recoveredPayloadsMatchEncodedPrefix", recoveredPayloadsMatchEncodedPrefix)
            .put("decodedSamples", decodedSamples)
            .put("decodedSampleCoverage", decodedSampleCoverage)
            .put("decodedRms", decodedRms)
            .put("encoderName", encoderName)
            .put("decoderName", decoderName)
            .put("encoderAudioObjectType", encoderAudioObjectType)
            .put("encoderSampleRateHz", encoderSampleRateHz)
            .put("encoderChannelConfiguration", encoderChannelConfiguration)
            .put("encoderAudioSpecificConfigHex", encoderAudioSpecificConfigHex)
            .put("recoveryAudioSpecificConfigHex", recoveryAudioSpecificConfigHex)
            .put("decoderSampleRateHz", decoderSampleRateHz)
            .put("decoderChannelCount", decoderChannelCount)
            .put(
                "limitation",
                "Authentic MediaCodec payload recovery smoke; abrupt process death and real microphone speech are separate tests.",
            ).toString(2)
}

class AacAdtsRecoverySpike {
    fun run(workingDirectory: File): AacAdtsRecoveryReport {
        val codec = AacRoundTripSpike()
        val encoded = codec.encode(codec.deterministicFixture())
        check(encoded.accessUnits.size > 1) { "AAC encoder must emit a tail frame for recovery testing" }
        val encoderAudioSpecificConfig = encoded.codecSpecificData.first()
        val parsedEncoderConfig =
            AacAudioSpecificConfigParser.requireAacLc16KhzMono(encoderAudioSpecificConfig)

        val dataFile = File.createTempFile("loquiris-aac-", ".adts", workingDirectory)
        val journalFile = File.createTempFile("loquiris-aac-", ".journal", workingDirectory)
        try {
            AdtsDurableCommitStore.open(dataFile, journalFile).use { store ->
                encoded.accessUnits.forEachIndexed { index, accessUnit ->
                    store.appendFrame(
                        frame =
                            AdtsAacFrameCodec.wrap(
                                accessUnit = accessUnit.bytes,
                                sampleRateHz = AacRoundTripSpike.SAMPLE_RATE_HZ,
                                channelCount = AacRoundTripSpike.CHANNEL_COUNT,
                            ),
                        mediaSamples = SAMPLES_PER_ACCESS_UNIT,
                    )
                    if (index == encoded.accessUnits.lastIndex - 1) store.commit()
                }
            }

            val dataBytes = dataFile.readBytes()
            val recovered =
                AdtsCommittedPrefixRecovery.recover(
                    dataBytes = dataBytes,
                    journalBytes = journalFile.readBytes(),
                )
            check(recovered.committedBytes in 1 until dataBytes.size) {
                "Recovery did not isolate a committed prefix from the durable tail"
            }
            val recoveredPayloads =
                AdtsAacFrameCodec.unwrapCompleteFrames(
                    dataBytes.copyOf(recovered.committedBytes),
                )
            val expectedCommittedPayloads = encoded.accessUnits.dropLast(1).map(AacRoundTripSpike.AccessUnit::bytes)
            val recoveredPayloadsMatchEncodedPrefix =
                recoveredPayloads.size == expectedCommittedPayloads.size &&
                    recoveredPayloads.zip(expectedCommittedPayloads).all { (actual, expected) ->
                        actual.contentEquals(expected)
                    }
            check(recoveredPayloadsMatchEncodedPrefix) {
                "Recovered AAC payloads differ from the durably committed encoder prefix"
            }
            check(recovered.committedFrames == encoded.accessUnits.size - 1) {
                "Recovery lost committed AAC frames or included the uncommitted tail"
            }
            check(recovered.committedBytes + recovered.uncommittedOrInvalidBytes == dataBytes.size) {
                "Recovered and discarded byte accounting does not match durable data"
            }
            val recoveredAccessUnits =
                recoveredPayloads.mapIndexed { index, bytes ->
                    AacRoundTripSpike.AccessUnit(
                        bytes = bytes,
                        presentationTimeUs =
                            index.toLong() * SAMPLES_PER_ACCESS_UNIT * 1_000_000L /
                                AacRoundTripSpike.SAMPLE_RATE_HZ,
                    )
                }
            val mediaEndPresentationTimeUs =
                recoveredAccessUnits.size.toLong() * SAMPLES_PER_ACCESS_UNIT * 1_000_000L /
                    AacRoundTripSpike.SAMPLE_RATE_HZ
            val decoded =
                codec.decode(
                    encoded.copy(
                        codecSpecificData = listOf(aacLc16KhzMonoAudioSpecificConfig),
                        accessUnits = recoveredAccessUnits,
                        mediaEndPresentationTimeUs = mediaEndPresentationTimeUs,
                    ),
                )
            return AacAdtsRecoveryReport(
                encodedAccessUnits = encoded.accessUnits.size,
                recoveredAccessUnits = recoveredAccessUnits.size,
                durableDataBytes = dataBytes.size,
                recoveredDataBytes = recovered.committedBytes,
                discardedTailBytes = recovered.uncommittedOrInvalidBytes,
                recoveredPayloadsMatchEncodedPrefix = recoveredPayloadsMatchEncodedPrefix,
                decodedSamples = decoded.samples.size,
                decodedSampleCoverage =
                    decoded.samples.size.toDouble() /
                        (recoveredAccessUnits.size * SAMPLES_PER_ACCESS_UNIT),
                decodedRms = decoded.samples.rootMeanSquare(),
                encoderName = encoded.codecName,
                decoderName = decoded.codecName,
                encoderAudioObjectType = parsedEncoderConfig.audioObjectType,
                encoderSampleRateHz = parsedEncoderConfig.sampleRateHz,
                encoderChannelConfiguration = parsedEncoderConfig.channelConfiguration,
                encoderAudioSpecificConfigHex = encoderAudioSpecificConfig.toHex(),
                recoveryAudioSpecificConfigHex = aacLc16KhzMonoAudioSpecificConfig.toHex(),
                decoderSampleRateHz = decoded.sampleRateHz,
                decoderChannelCount = decoded.channelCount,
            )
        } finally {
            dataFile.delete()
            journalFile.delete()
        }
    }

    companion object {
        private const val SAMPLES_PER_ACCESS_UNIT = 1_024
        private val aacLc16KhzMonoAudioSpecificConfig = byteArrayOf(0x14, 0x08)
    }
}

private fun ShortArray.rootMeanSquare(): Double =
    if (isEmpty()) {
        0.0
    } else {
        sqrt(sumOf { sample -> sample.toDouble() * sample } / size)
    }

private fun ByteArray.toHex(): String = joinToString(separator = "") { byte -> "%02x".format(byte.toInt() and 0xFF) }
