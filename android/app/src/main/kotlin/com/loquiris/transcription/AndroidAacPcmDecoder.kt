package com.loquiris.transcription

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.FileInputStream
import java.nio.ByteOrder

class AndroidAacPcmDecoder(
    private val windowSamples: Int = 30 * TARGET_SAMPLE_RATE_HZ,
) : AacPcmDecoder {
    init {
        require(windowSamples > 0)
    }

    override fun decode(
        audio: AuthoritativeAudioResolution.Ready,
        onWindow: (PcmWindow) -> Boolean,
    ): AudioDecodeResult {
        if (audio.sampleRateHz != TARGET_SAMPLE_RATE_HZ) {
            return AudioDecodeResult.Failure("transcription_audio_format_unsupported")
        }
        val accumulator = PcmWindowAccumulator(windowSamples, onWindow)
        return try {
            for (segment in audio.segments) {
                when (val result = decodeSegment(segment, accumulator)) {
                    AudioDecodeResult.Completed -> Unit
                    else -> return result
                }
            }
            if (!accumulator.finish()) AudioDecodeResult.Cancelled else AudioDecodeResult.Completed
        } catch (_: Exception) {
            AudioDecodeResult.Failure("transcription_audio_decode_failed")
        }
    }

    private fun decodeSegment(
        segment: AuthoritativeAudioSegment,
        accumulator: PcmWindowAccumulator,
    ): AudioDecodeResult {
        FileInputStream(segment.file).use { source ->
            val extractor = MediaExtractor()
            var codec: MediaCodec? = null
            try {
                extractor.setDataSource(source.fd, 0, segment.committedBytes)
                val track =
                    (0 until extractor.trackCount).firstOrNull { index ->
                        extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
                    } ?: return AudioDecodeResult.Failure("transcription_audio_track_missing")
                extractor.selectTrack(track)
                val inputFormat = extractor.getTrackFormat(track)
                val mime = inputFormat.getString(MediaFormat.KEY_MIME)
                    ?: return AudioDecodeResult.Failure("transcription_audio_track_missing")
                codec = MediaCodec.createDecoderByType(mime)
                codec.configure(inputFormat, null, null, 0)
                codec.start()
                val info = MediaCodec.BufferInfo()
                var inputEnded = false
                var outputEnded = false
                var outputFormat: MediaFormat? = null
                while (!outputEnded) {
                    if (!inputEnded) {
                        val inputIndex = codec.dequeueInputBuffer(CODEC_TIMEOUT_US)
                        if (inputIndex >= 0) {
                            val input = checkNotNull(codec.getInputBuffer(inputIndex))
                            input.clear()
                            val size = extractor.readSampleData(input, 0)
                            if (size < 0) {
                                codec.queueInputBuffer(
                                    inputIndex,
                                    0,
                                    0,
                                    0,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                                )
                                inputEnded = true
                            } else {
                                codec.queueInputBuffer(inputIndex, 0, size, extractor.sampleTime, 0)
                                extractor.advance()
                            }
                        }
                    }
                    when (val outputIndex = codec.dequeueOutputBuffer(info, CODEC_TIMEOUT_US)) {
                        MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            outputFormat = codec.outputFormat
                            if (!outputFormat.isSupportedPcm()) {
                                return AudioDecodeResult.Failure("transcription_audio_format_unsupported")
                            }
                        }
                        MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                        else ->
                            if (outputIndex >= 0) {
                                if (info.size > 0) {
                                    val format = outputFormat ?: codec.outputFormat
                                    if (!format.isSupportedPcm()) {
                                        return AudioDecodeResult.Failure("transcription_audio_format_unsupported")
                                    }
                                    val output = checkNotNull(codec.getOutputBuffer(outputIndex)).duplicate()
                                    output.position(info.offset)
                                    output.limit(info.offset + info.size)
                                    val shorts = ShortArray(info.size / Short.SIZE_BYTES)
                                    output.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().get(shorts)
                                    if (!accumulator.append(shorts)) return AudioDecodeResult.Cancelled
                                }
                                outputEnded = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                                codec.releaseOutputBuffer(outputIndex, false)
                            }
                    }
                }
                return AudioDecodeResult.Completed
            } finally {
                runCatching { codec?.stop() }
                runCatching { codec?.release() }
                extractor.release()
            }
        }
    }

    private fun MediaFormat.isSupportedPcm(): Boolean {
        val sampleRate = getInteger(MediaFormat.KEY_SAMPLE_RATE)
        val channels = getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        val encoding =
            if (containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                getInteger(MediaFormat.KEY_PCM_ENCODING)
            } else {
                AudioFormat.ENCODING_PCM_16BIT
            }
        return sampleRate == TARGET_SAMPLE_RATE_HZ &&
            channels == 1 &&
            encoding == AudioFormat.ENCODING_PCM_16BIT
    }

    private companion object {
        const val TARGET_SAMPLE_RATE_HZ = 16_000
        const val CODEC_TIMEOUT_US = 10_000L
    }
}

internal class PcmWindowAccumulator(
    private val windowSamples: Int,
    private val emit: (PcmWindow) -> Boolean,
) {
    private var buffer = ShortArray(windowSamples)
    private var size = 0
    private var emittedSamples = 0L

    fun append(samples: ShortArray): Boolean {
        var sourceOffset = 0
        while (sourceOffset < samples.size) {
            val count = minOf(windowSamples - size, samples.size - sourceOffset)
            samples.copyInto(buffer, size, sourceOffset, sourceOffset + count)
            size += count
            sourceOffset += count
            if (size == windowSamples && !flush()) return false
        }
        return true
    }

    fun finish(): Boolean = size == 0 || flush()

    private fun flush(): Boolean {
        val samples = buffer.copyOf(size)
        val accepted = emit(PcmWindow(emittedSamples, samples))
        emittedSamples = Math.addExact(emittedSamples, size.toLong())
        buffer = ShortArray(windowSamples)
        size = 0
        return accepted
    }
}
