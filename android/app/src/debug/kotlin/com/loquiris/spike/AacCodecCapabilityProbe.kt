package com.loquiris.spike

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException

data class AacEncoderCapability(
    val codecName: String,
    val canonicalName: String,
    val hardwareAccelerated: Boolean,
    val softwareOnly: Boolean,
    val vendor: Boolean,
    val supportsSampleRate: Boolean,
    val supportsBitRate: Boolean,
    val supportsChannelCount: Boolean,
    val supportsAacLcProfile: Boolean,
    val configureSucceeded: Boolean,
    val failureCode: String?,
) {
    val meetsTarget: Boolean
        get() =
            supportsSampleRate &&
                supportsBitRate &&
                supportsChannelCount &&
                supportsAacLcProfile &&
                configureSucceeded
}

data class AacCodecCapabilityReport(
    val sampleRateHz: Int,
    val channelCount: Int,
    val bitRateBitsPerSecond: Int,
    val candidates: List<AacEncoderCapability>,
) {
    val targetAvailable: Boolean
        get() = candidates.any(AacEncoderCapability::meetsTarget)

    fun toJson(): String {
        val encodedCandidates = JSONArray()
        candidates.forEach { candidate ->
            encodedCandidates.put(
                JSONObject()
                    .put("codecName", candidate.codecName)
                    .put("canonicalName", candidate.canonicalName)
                    .put("hardwareAccelerated", candidate.hardwareAccelerated)
                    .put("softwareOnly", candidate.softwareOnly)
                    .put("vendor", candidate.vendor)
                    .put("supportsSampleRate", candidate.supportsSampleRate)
                    .put("supportsBitRate", candidate.supportsBitRate)
                    .put("supportsChannelCount", candidate.supportsChannelCount)
                    .put("supportsAacLcProfile", candidate.supportsAacLcProfile)
                    .put("configureSucceeded", candidate.configureSucceeded)
                    .put("failureCode", candidate.failureCode ?: JSONObject.NULL)
                    .put("meetsTarget", candidate.meetsTarget),
            )
        }
        return JSONObject()
            .put("schemaVersion", 1)
            .put("sampleRateHz", sampleRateHz)
            .put("channelCount", channelCount)
            .put("bitRateBitsPerSecond", bitRateBitsPerSecond)
            .put("targetAvailable", targetAvailable)
            .put("candidates", encodedCandidates)
            .toString(2)
    }
}

class AacCodecCapabilityProbe {
    fun run(): AacCodecCapabilityReport {
        val codecInfos =
            MediaCodecList(MediaCodecList.ALL_CODECS).codecInfos
                .asSequence()
                .filter(MediaCodecInfo::isEncoder)
                .toList()
        val candidates =
            inspectAacCandidatesSafely(
                candidates = codecInfos,
                inspect = { info ->
                    if (info.supportedTypes.any(MIME_TYPE::equals)) {
                        inspect(info)
                    } else {
                        unsupportedCapability(info, "mime_type_unsupported")
                    }
                },
                failure = ::capabilityQueryFailure,
            )
                .asSequence()
                .filterNot { candidate -> candidate.failureCode == "mime_type_unsupported" }
                .sortedWith(
                    compareByDescending(AacEncoderCapability::meetsTarget)
                        .thenByDescending(AacEncoderCapability::hardwareAccelerated)
                        .thenBy(AacEncoderCapability::codecName),
                ).toList()
        return AacCodecCapabilityReport(
            sampleRateHz = SAMPLE_RATE_HZ,
            channelCount = CHANNEL_COUNT,
            bitRateBitsPerSecond = BIT_RATE_BITS_PER_SECOND,
            candidates = candidates,
        )
    }

    private fun inspect(info: MediaCodecInfo): AacEncoderCapability {
        val capabilities = info.getCapabilitiesForType(MIME_TYPE)
        val audio =
            capabilities.audioCapabilities
                ?: return unsupportedCapability(info, "audio_capabilities_missing")
        val supportsSampleRate = audio.isSampleRateSupported(SAMPLE_RATE_HZ)
        val supportsBitRate = audio.bitrateRange.contains(BIT_RATE_BITS_PER_SECOND)
        val supportsChannelCount = audio.maxInputChannelCount >= CHANNEL_COUNT
        val supportsAacLc =
            capabilities.profileLevels.any { profile ->
                profile.profile == MediaCodecInfo.CodecProfileLevel.AACObjectLC
            }
        val configuration =
            if (supportsSampleRate && supportsBitRate && supportsChannelCount && supportsAacLc) {
                verifyConfiguration(info.name)
            } else {
                ConfigurationResult(false, "declared_capability_mismatch")
            }
        return AacEncoderCapability(
            codecName = info.name,
            canonicalName = info.canonicalName,
            hardwareAccelerated = info.isHardwareAccelerated,
            softwareOnly = info.isSoftwareOnly,
            vendor = info.isVendor,
            supportsSampleRate = supportsSampleRate,
            supportsBitRate = supportsBitRate,
            supportsChannelCount = supportsChannelCount,
            supportsAacLcProfile = supportsAacLc,
            configureSucceeded = configuration.succeeded,
            failureCode = configuration.failureCode,
        )
    }

    private fun unsupportedCapability(
        info: MediaCodecInfo,
        failureCode: String,
    ): AacEncoderCapability =
        AacEncoderCapability(
            codecName = info.name,
            canonicalName = info.canonicalName,
            hardwareAccelerated = info.isHardwareAccelerated,
            softwareOnly = info.isSoftwareOnly,
            vendor = info.isVendor,
            supportsSampleRate = false,
            supportsBitRate = false,
            supportsChannelCount = false,
            supportsAacLcProfile = false,
            configureSucceeded = false,
            failureCode = failureCode,
        )

    private fun capabilityQueryFailure(info: MediaCodecInfo): AacEncoderCapability =
        AacEncoderCapability(
            codecName = runCatching(info::getName).getOrDefault("<unavailable>"),
            canonicalName = "<unavailable>",
            hardwareAccelerated = false,
            softwareOnly = false,
            vendor = false,
            supportsSampleRate = false,
            supportsBitRate = false,
            supportsChannelCount = false,
            supportsAacLcProfile = false,
            configureSucceeded = false,
            failureCode = "capability_query_failed",
        )

    private fun verifyConfiguration(codecName: String): ConfigurationResult {
        var codec: MediaCodec? = null
        val result =
            try {
                codec = MediaCodec.createByCodecName(codecName)
                codec.configure(targetFormat(), null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                codec.start()
                codec.stop()
                ConfigurationResult(true, null)
            } catch (_: IOException) {
                ConfigurationResult(false, "codec_create_failed")
            } catch (_: UnsupportedOperationException) {
                ConfigurationResult(false, "codec_configuration_unsupported")
            } catch (_: IllegalArgumentException) {
                ConfigurationResult(false, "codec_configuration_rejected")
            } catch (_: IllegalStateException) {
                ConfigurationResult(false, "codec_state_failed")
            }
        return resultAfterCleanup(
            result = result,
            cleanup = { codec?.release() },
            cleanupFailure = { ConfigurationResult(false, "codec_release_failed") },
        )
    }

    private fun targetFormat(): MediaFormat =
        MediaFormat.createAudioFormat(MIME_TYPE, SAMPLE_RATE_HZ, CHANNEL_COUNT).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE_BITS_PER_SECOND)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 4_096)
        }

    private data class ConfigurationResult(
        val succeeded: Boolean,
        val failureCode: String?,
    )

    companion object {
        private const val MIME_TYPE = MediaFormat.MIMETYPE_AUDIO_AAC
        private const val SAMPLE_RATE_HZ = 16_000
        private const val CHANNEL_COUNT = 1
        private const val BIT_RATE_BITS_PER_SECOND = 64_000
    }
}

internal fun <T> inspectAacCandidatesSafely(
    candidates: List<T>,
    inspect: (T) -> AacEncoderCapability,
    failure: (T) -> AacEncoderCapability,
): List<AacEncoderCapability> =
    candidates.map { candidate ->
        try {
            inspect(candidate)
        } catch (_: Exception) {
            failure(candidate)
        }
    }

internal fun <T> resultAfterCleanup(
    result: T,
    cleanup: () -> Unit,
    cleanupFailure: () -> T,
): T =
    try {
        cleanup()
        result
    } catch (_: Exception) {
        cleanupFailure()
    }
