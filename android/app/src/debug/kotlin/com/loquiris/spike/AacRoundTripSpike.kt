package com.loquiris.spike

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.os.SystemClock
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.roundToInt
import kotlin.math.sin

data class AacRoundTripReport(
    val encoderName: String,
    val decoderName: String,
    val inputSamples: Int,
    val accessUnitCount: Int,
    val encodedBytes: Int,
    val decodedSamples: Int,
    val encodeElapsedMilliseconds: Long,
    val decodeElapsedMilliseconds: Long,
    val lagSamples: Int,
    val alignedSamples: Int,
    val correlation: Double,
    val signalToNoiseRatioDb: Double,
    val decodedRms: Double,
    val alignmentSearchClipped: Boolean,
    val referenceCoverage: Double,
    val decodedToInputSampleRatio: Double,
    val decoderSampleRateHz: Int,
    val decoderChannelCount: Int,
) {
    fun toJson(): String =
        JSONObject()
            .put("schemaVersion", 1)
            .put("sampleRateHz", AacRoundTripSpike.SAMPLE_RATE_HZ)
            .put("channelCount", AacRoundTripSpike.CHANNEL_COUNT)
            .put("bitRateBitsPerSecond", AacRoundTripSpike.BIT_RATE_BITS_PER_SECOND)
            .put("fixture", "deterministic_multi_tone_v1")
            .put("encoderName", encoderName)
            .put("decoderName", decoderName)
            .put("inputSamples", inputSamples)
            .put("accessUnitCount", accessUnitCount)
            .put("encodedBytes", encodedBytes)
            .put("decodedSamples", decodedSamples)
            .put("encodeElapsedMilliseconds", encodeElapsedMilliseconds)
            .put("decodeElapsedMilliseconds", decodeElapsedMilliseconds)
            .put("lagSamples", lagSamples)
            .put("alignedSamples", alignedSamples)
            .put("correlation", correlation)
            .put("signalToNoiseRatioDb", signalToNoiseRatioDb)
            .put("decodedRms", decodedRms)
            .put("alignmentSearchClipped", alignmentSearchClipped)
            .put("referenceCoverage", referenceCoverage)
            .put("decodedToInputSampleRatio", decodedToInputSampleRatio)
            .put("decoderSampleRateHz", decoderSampleRateHz)
            .put("decoderChannelCount", decoderChannelCount)
            .put(
                "limitation",
                "Synthetic codec smoke only; not evidence of meeting speech intelligibility or ASR accuracy.",
            ).toString(2)
}

class AacRoundTripSpike {
    fun run(): AacRoundTripReport {
        val reference = deterministicFixture()
        val encoded = encode(reference)
        val decoded = decode(encoded)
        val quality =
            AacRoundTripQualityEvaluator.evaluate(
                reference = reference,
                decoded = decoded.samples,
                maxLagSamples = MAX_ALIGNMENT_LAG_SAMPLES,
            )
        return AacRoundTripReport(
            encoderName = encoded.codecName,
            decoderName = decoded.codecName,
            inputSamples = reference.size,
            accessUnitCount = encoded.accessUnits.size,
            encodedBytes = encoded.accessUnits.sumOf { unit -> unit.bytes.size },
            decodedSamples = decoded.samples.size,
            encodeElapsedMilliseconds = encoded.elapsedMilliseconds,
            decodeElapsedMilliseconds = decoded.elapsedMilliseconds,
            lagSamples = quality.lagSamples,
            alignedSamples = quality.alignedSamples,
            correlation = quality.correlation,
            signalToNoiseRatioDb = quality.signalToNoiseRatioDb,
            decodedRms = quality.decodedRms,
            alignmentSearchClipped = quality.alignmentSearchClipped,
            referenceCoverage = quality.referenceCoverage,
            decodedToInputSampleRatio = decoded.samples.size.toDouble() / reference.size,
            decoderSampleRateHz = decoded.sampleRateHz,
            decoderChannelCount = decoded.channelCount,
        )
    }

    internal fun encode(samples: ShortArray): EncodedAudio {
        val codec = MediaCodec.createEncoderByType(MIME_TYPE)
        var started = false
        var primaryFailure: Throwable? = null
        val startedAt = SystemClock.elapsedRealtime()
        try {
            codec.configure(targetFormat(), null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
            started = true
            val accessUnits = mutableListOf<AccessUnit>()
            var formatCodecSpecificData = emptyList<ByteArray>()
            val configBufferCodecSpecificData = mutableListOf<ByteArray>()
            var inputOffset = 0
            var inputEnded = false
            var outputEnded = false
            val bufferInfo = MediaCodec.BufferInfo()
            val deadline = SystemClock.elapsedRealtime() + CODEC_TIMEOUT_MILLISECONDS
            while (!outputEnded) {
                check(SystemClock.elapsedRealtime() < deadline) { "AAC encoder timed out" }
                if (!inputEnded) {
                    val inputIndex = codec.dequeueInputBuffer(DEQUEUE_TIMEOUT_MICROSECONDS)
                    if (inputIndex >= 0) {
                        val inputBuffer = checkNotNull(codec.getInputBuffer(inputIndex)).apply { clear() }
                        inputBuffer.order(ByteOrder.LITTLE_ENDIAN)
                        val sampleCount = minOf(inputBuffer.remaining() / Short.SIZE_BYTES, samples.size - inputOffset)
                        if (sampleCount == 0) {
                            codec.queueInputBuffer(
                                inputIndex,
                                0,
                                0,
                                presentationTimeMicroseconds(inputOffset),
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputEnded = true
                        } else {
                            repeat(sampleCount) { index -> inputBuffer.putShort(samples[inputOffset + index]) }
                            codec.queueInputBuffer(
                                inputIndex,
                                0,
                                sampleCount * Short.SIZE_BYTES,
                                presentationTimeMicroseconds(inputOffset),
                                0,
                            )
                            inputOffset += sampleCount
                        }
                    }
                }

                when (val outputIndex = codec.dequeueOutputBuffer(bufferInfo, DEQUEUE_TIMEOUT_MICROSECONDS)) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED ->
                        formatCodecSpecificData = copyCodecSpecificData(codec.outputFormat)
                    MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                    else ->
                        if (outputIndex >= 0) {
                            if (bufferInfo.size > 0) {
                                val bytes = copyOutput(codec, outputIndex, bufferInfo)
                                if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                                    configBufferCodecSpecificData += bytes
                                } else {
                                    accessUnits += AccessUnit(bytes, bufferInfo.presentationTimeUs)
                                }
                            }
                            outputEnded = bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                            codec.releaseOutputBuffer(outputIndex, false)
                        }
                }
            }
            val codecSpecificData =
                selectCodecSpecificData(formatCodecSpecificData, configBufferCodecSpecificData)
            check(codecSpecificData.isNotEmpty()) { "AAC encoder did not expose codec specific data" }
            check(accessUnits.isNotEmpty()) { "AAC encoder emitted no access units" }
            check(timestampsAreStrictlyIncreasing(accessUnits.map(AccessUnit::presentationTimeUs))) {
                "AAC encoder emitted non-increasing access-unit timestamps"
            }
            val mediaEndPresentationTimeUs =
                mediaEndTimestampMicroseconds(samples.size, SAMPLE_RATE_HZ)
            check(mediaEndPresentationTimeUs > accessUnits.last().presentationTimeUs) {
                "AAC media-end timestamp does not follow the final access unit"
            }
            return EncodedAudio(
                codecName = codec.name,
                codecSpecificData = codecSpecificData,
                accessUnits = accessUnits,
                elapsedMilliseconds = SystemClock.elapsedRealtime() - startedAt,
                mediaEndPresentationTimeUs = mediaEndPresentationTimeUs,
            )
        } catch (failure: Throwable) {
            primaryFailure = failure
            throw failure
        } finally {
            val lifecycleFailure =
                finishCodecLifecycle(
                    primaryFailure = primaryFailure,
                    stop = { if (started) codec.stop() },
                    release = codec::release,
                )
            if (primaryFailure == null && lifecycleFailure != null) throw lifecycleFailure
        }
    }

    internal fun decode(encoded: EncodedAudio): DecodedAudio {
        val codec = MediaCodec.createDecoderByType(MIME_TYPE)
        var started = false
        var primaryFailure: Throwable? = null
        val startedAt = SystemClock.elapsedRealtime()
        try {
            codec.configure(decoderFormat(encoded.codecSpecificData), null, null, 0)
            codec.start()
            started = true
            val pcm = ByteArrayOutputStream()
            val outputTimestamps = mutableListOf<Long>()
            var actualSampleRateHz: Int? = null
            var actualChannelCount: Int? = null
            var nextAccessUnit = 0
            var inputEnded = false
            var outputEnded = false
            val bufferInfo = MediaCodec.BufferInfo()
            val deadline = SystemClock.elapsedRealtime() + CODEC_TIMEOUT_MILLISECONDS
            while (!outputEnded) {
                check(SystemClock.elapsedRealtime() < deadline) { "AAC decoder timed out" }
                if (!inputEnded) {
                    val inputIndex = codec.dequeueInputBuffer(DEQUEUE_TIMEOUT_MICROSECONDS)
                    if (inputIndex >= 0) {
                        val inputBuffer = checkNotNull(codec.getInputBuffer(inputIndex)).apply { clear() }
                        if (nextAccessUnit < encoded.accessUnits.size) {
                            val unit = encoded.accessUnits[nextAccessUnit++]
                            check(inputBuffer.remaining() >= unit.bytes.size) { "AAC access unit exceeds decoder input" }
                            inputBuffer.put(unit.bytes)
                            codec.queueInputBuffer(inputIndex, 0, unit.bytes.size, unit.presentationTimeUs, 0)
                        } else {
                            codec.queueInputBuffer(
                                inputIndex,
                                0,
                                0,
                                encoded.mediaEndPresentationTimeUs,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputEnded = true
                        }
                    }
                }

                when (val outputIndex = codec.dequeueOutputBuffer(bufferInfo, DEQUEUE_TIMEOUT_MICROSECONDS)) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val outputFormat = codec.outputFormat
                        actualSampleRateHz = outputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        actualChannelCount = outputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        check(actualSampleRateHz == SAMPLE_RATE_HZ) { "AAC decoder changed sample rate" }
                        check(actualChannelCount == CHANNEL_COUNT) { "AAC decoder changed channel count" }
                        check(
                            outputFormat.getInteger(
                                MediaFormat.KEY_PCM_ENCODING,
                                AudioFormat.ENCODING_PCM_16BIT,
                            ) == AudioFormat.ENCODING_PCM_16BIT,
                        ) {
                            "AAC decoder did not emit PCM 16-bit"
                        }
                    }
                    MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                    else ->
                        if (outputIndex >= 0) {
                            if (bufferInfo.size > 0) {
                                pcm.write(copyOutput(codec, outputIndex, bufferInfo))
                                outputTimestamps += bufferInfo.presentationTimeUs
                            }
                            outputEnded = bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                            codec.releaseOutputBuffer(outputIndex, false)
                        }
                }
            }
            check(timestampsAreStrictlyIncreasing(outputTimestamps)) {
                "AAC decoder emitted non-increasing output timestamps"
            }
            return DecodedAudio(
                codecName = codec.name,
                samples = littleEndianPcm16(pcm.toByteArray()),
                elapsedMilliseconds = SystemClock.elapsedRealtime() - startedAt,
                sampleRateHz = checkNotNull(actualSampleRateHz) { "AAC decoder emitted no output format" },
                channelCount = checkNotNull(actualChannelCount) { "AAC decoder emitted no output format" },
            )
        } catch (failure: Throwable) {
            primaryFailure = failure
            throw failure
        } finally {
            val lifecycleFailure =
                finishCodecLifecycle(
                    primaryFailure = primaryFailure,
                    stop = { if (started) codec.stop() },
                    release = codec::release,
                )
            if (primaryFailure == null && lifecycleFailure != null) throw lifecycleFailure
        }
    }

    private fun targetFormat(): MediaFormat =
        MediaFormat.createAudioFormat(MIME_TYPE, SAMPLE_RATE_HZ, CHANNEL_COUNT).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE_BITS_PER_SECOND)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, MAX_INPUT_BYTES)
        }

    private fun decoderFormat(codecSpecificData: List<ByteArray>): MediaFormat =
        targetFormat().apply {
            setInteger(MediaFormat.KEY_PCM_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
            codecSpecificData.forEachIndexed { index, bytes -> setByteBuffer("csd-$index", ByteBuffer.wrap(bytes)) }
        }

    internal fun deterministicFixture(): ShortArray =
        ShortArray(FIXTURE_SECONDS * SAMPLE_RATE_HZ) { index ->
            val seconds = index.toDouble() / SAMPLE_RATE_HZ
            val envelope = 0.55 + 0.45 * sin(2.0 * PI * 1.7 * seconds)
            val mixed =
                0.45 * sin(2.0 * PI * 223.0 * seconds) +
                    0.30 * sin(2.0 * PI * 509.0 * seconds) +
                    0.15 * sin(2.0 * PI * 997.0 * seconds)
            (envelope * mixed * Short.MAX_VALUE * 0.72).roundToInt().toShort()
        }

    private fun presentationTimeMicroseconds(sampleOffset: Int): Long =
        sampleOffset.toLong() * 1_000_000L / SAMPLE_RATE_HZ

    private fun copyCodecSpecificData(format: MediaFormat): List<ByteArray> =
        generateSequence(0) { index -> index + 1 }
            .map { index -> format.getByteBuffer("csd-$index") ?: return@map null }
            .takeWhile { buffer -> buffer != null }
            .map { buffer -> copyBuffer(checkNotNull(buffer)) }
            .toList()

    private fun copyOutput(
        codec: MediaCodec,
        outputIndex: Int,
        bufferInfo: MediaCodec.BufferInfo,
    ): ByteArray {
        val output = checkNotNull(codec.getOutputBuffer(outputIndex)).duplicate()
        output.position(bufferInfo.offset)
        output.limit(bufferInfo.offset + bufferInfo.size)
        return copyBuffer(output)
    }

    private fun copyBuffer(buffer: ByteBuffer): ByteArray =
        ByteArray(buffer.remaining()).also(buffer::get)

    private fun littleEndianPcm16(bytes: ByteArray): ShortArray {
        check(bytes.size % Short.SIZE_BYTES == 0) { "AAC decoder emitted an odd PCM byte count" }
        val buffer = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
        return ShortArray(buffer.remaining()).also(buffer::get)
    }

    internal data class AccessUnit(
        val bytes: ByteArray,
        val presentationTimeUs: Long,
    )

    internal data class EncodedAudio(
        val codecName: String,
        val codecSpecificData: List<ByteArray>,
        val accessUnits: List<AccessUnit>,
        val elapsedMilliseconds: Long,
        val mediaEndPresentationTimeUs: Long,
    )

    internal data class DecodedAudio(
        val codecName: String,
        val samples: ShortArray,
        val elapsedMilliseconds: Long,
        val sampleRateHz: Int,
        val channelCount: Int,
    )

    companion object {
        internal const val SAMPLE_RATE_HZ = 16_000
        internal const val CHANNEL_COUNT = 1
        internal const val BIT_RATE_BITS_PER_SECOND = 64_000
        private const val MIME_TYPE = MediaFormat.MIMETYPE_AUDIO_AAC
        private const val FIXTURE_SECONDS = 2
        private const val MAX_INPUT_BYTES = 4_096
        private const val MAX_ALIGNMENT_LAG_SAMPLES = 4_096
        private const val DEQUEUE_TIMEOUT_MICROSECONDS = 10_000L
        private const val CODEC_TIMEOUT_MILLISECONDS = 20_000L
    }
}
