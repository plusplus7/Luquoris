package com.loquiris.recording

import android.media.MediaCodecInfo
import android.media.MediaFormat

object ProductionAacFormat {
    fun isExpected(
        mimeType: String?,
        sampleRateHz: Int,
        channelCount: Int,
        aacProfile: Int?,
        bitRateBitsPerSecond: Int?,
        codecSpecificData: List<ByteArray>,
    ): Boolean {
        if (mimeType != MediaFormat.MIMETYPE_AUDIO_AAC) return false
        if (sampleRateHz != AndroidAacSegmentEncoder.SAMPLE_RATE_HZ) return false
        if (channelCount != AndroidAacSegmentEncoder.CHANNEL_COUNT) return false
        if (aacProfile != null && aacProfile != MediaCodecInfo.CodecProfileLevel.AACObjectLC) return false
        if (
            bitRateBitsPerSecond != null &&
            bitRateBitsPerSecond != AndroidAacSegmentEncoder.BIT_RATE_BITS_PER_SECOND
        ) {
            return false
        }
        val config = codecSpecificData.firstOrNull() ?: return false
        if (config.size < MINIMUM_ASC_BYTES) return false
        val first = config[0].toInt() and 0xff
        val second = config[1].toInt() and 0xff
        val audioObjectType = first ushr 3
        val sampleRateIndex = ((first and 0x07) shl 1) or (second ushr 7)
        val configuredChannels = (second ushr 3) and 0x0f
        return audioObjectType == MediaCodecInfo.CodecProfileLevel.AACObjectLC &&
            sampleRateIndex == SAMPLE_RATE_INDEX_16_KHZ &&
            configuredChannels == AndroidAacSegmentEncoder.CHANNEL_COUNT
    }

    private const val MINIMUM_ASC_BYTES = 2
    private const val SAMPLE_RATE_INDEX_16_KHZ = 8
}
