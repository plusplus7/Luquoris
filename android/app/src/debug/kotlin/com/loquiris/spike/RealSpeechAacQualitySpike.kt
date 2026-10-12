package com.loquiris.spike

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.SystemClock
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

data class RealSpeechAacQualityReport(
    val sourceDecoderName: String,
    val sourceDurationMilliseconds: Long,
    val sourceSampleRateHz: Int,
    val sourceChannelCount: Int,
    val referenceSampleRateHz: Int,
    val referenceChannelCount: Int,
    val referenceSamples: Int,
    val encoderName: String,
    val decoderName: String,
    val encoderAudioObjectType: Int,
    val encoderSampleRateHz: Int,
    val encoderChannelConfiguration: Int,
    val encoderAudioSpecificConfigHex: String,
    val encodedAccessUnits: Int,
    val encodedBytes: Int,
    val encodeElapsedMilliseconds: Long,
    val decodeElapsedMilliseconds: Long,
    val lagSamples: Int,
    val alignedSamples: Int,
    val referenceCoverage: Double,
    val decodedToReferenceSampleRatio: Double,
    val correlation: Double,
    val signalToNoiseRatioDb: Double,
    val decodedRms: Double,
    val alignmentSearchClipped: Boolean,
    val outputBytes: Long,
) {
    fun toJson(): String =
        JSONObject()
            .put("schemaVersion", 1)
            .put("sourceKind", "explicitly_authorized_local_real_speech")
            .put("sourceDecoderName", sourceDecoderName)
            .put("sourceDurationMilliseconds", sourceDurationMilliseconds)
            .put("sourceSampleRateHz", sourceSampleRateHz)
            .put("sourceChannelCount", sourceChannelCount)
            .put("referenceSampleRateHz", referenceSampleRateHz)
            .put("referenceChannelCount", referenceChannelCount)
            .put("referenceSamples", referenceSamples)
            .put("bitRateBitsPerSecond", AacRoundTripSpike.BIT_RATE_BITS_PER_SECOND)
            .put("encoderName", encoderName)
            .put("decoderName", decoderName)
            .put("encoderAudioObjectType", encoderAudioObjectType)
            .put("encoderSampleRateHz", encoderSampleRateHz)
            .put("encoderChannelConfiguration", encoderChannelConfiguration)
            .put("encoderAudioSpecificConfigHex", encoderAudioSpecificConfigHex)
            .put("encodedAccessUnits", encodedAccessUnits)
            .put("encodedBytes", encodedBytes)
            .put("encodeElapsedMilliseconds", encodeElapsedMilliseconds)
            .put("decodeElapsedMilliseconds", decodeElapsedMilliseconds)
            .put("lagSamples", lagSamples)
            .put("alignedSamples", alignedSamples)
            .put("referenceCoverage", referenceCoverage)
            .put("decodedToReferenceSampleRatio", decodedToReferenceSampleRatio)
            .put("correlation", correlation)
            .put("signalToNoiseRatioDb", signalToNoiseRatioDb)
            .put("decodedRms", decodedRms)
            .put("alignmentSearchClipped", alignmentSearchClipped)
            .put("outputBytes", outputBytes)
            .put(
                "limitation",
                "One user-authorized recording; objective codec round-trip and listening fixture only. " +
                    "It is not a speech-intelligibility panel, ASR-accuracy result, or population-level quality claim.",
            ).toString(2)
}

class RealSpeechAacQualitySpike {
    fun run(
        inputFile: File,
        outputFile: File,
    ): RealSpeechAacQualityReport {
        val source = decodeSource(inputFile)
        val reference =
            Pcm16Downsampler.toMono16Khz(
                interleavedSamples = source.samples,
                sourceSampleRateHz = source.sampleRateHz,
                sourceChannelCount = source.channelCount,
            )
        val codecHarness = AacRoundTripSpike()
        val encoded = codecHarness.encode(reference, LONG_CODEC_TIMEOUT_MILLISECONDS)
        val encoderAudioSpecificConfig = encoded.codecSpecificData.first()
        val parsedEncoderConfig =
            AacAudioSpecificConfigParser.requireAacLc16KhzMono(encoderAudioSpecificConfig)
        val decoded = codecHarness.decode(encoded, LONG_CODEC_TIMEOUT_MILLISECONDS)
        val quality =
            LongAacQualityEvaluator.evaluate(
                reference = reference,
                decoded = decoded.samples,
                maxLagSamples = MAX_ALIGNMENT_LAG_SAMPLES,
                alignmentWindowSamples = ALIGNMENT_WINDOW_SAMPLES,
            )
        check(!outputFile.exists() || outputFile.delete()) { "Could not replace real-speech M4A output" }
        mux(outputFile, encoded)
        return RealSpeechAacQualityReport(
            sourceDecoderName = source.decoderName,
            sourceDurationMilliseconds =
                source.samples.size.toLong() / source.channelCount * 1_000L / source.sampleRateHz,
            sourceSampleRateHz = source.sampleRateHz,
            sourceChannelCount = source.channelCount,
            referenceSampleRateHz = AacRoundTripSpike.SAMPLE_RATE_HZ,
            referenceChannelCount = AacRoundTripSpike.CHANNEL_COUNT,
            referenceSamples = reference.size,
            encoderName = encoded.codecName,
            decoderName = decoded.codecName,
            encoderAudioObjectType = parsedEncoderConfig.audioObjectType,
            encoderSampleRateHz = parsedEncoderConfig.sampleRateHz,
            encoderChannelConfiguration = parsedEncoderConfig.channelConfiguration,
            encoderAudioSpecificConfigHex = encoderAudioSpecificConfig.toHex(),
            encodedAccessUnits = encoded.accessUnits.size,
            encodedBytes = encoded.accessUnits.sumOf { it.bytes.size },
            encodeElapsedMilliseconds = encoded.elapsedMilliseconds,
            decodeElapsedMilliseconds = decoded.elapsedMilliseconds,
            lagSamples = quality.lagSamples,
            alignedSamples = quality.alignedSamples,
            referenceCoverage = quality.referenceCoverage,
            decodedToReferenceSampleRatio = decoded.samples.size.toDouble() / reference.size,
            correlation = quality.correlation,
            signalToNoiseRatioDb = quality.signalToNoiseRatioDb,
            decodedRms = quality.decodedRms,
            alignmentSearchClipped = quality.alignmentSearchClipped,
            outputBytes = outputFile.length(),
        )
    }

    private fun decodeSource(inputFile: File): SourcePcm {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        var codecStarted = false
        var primaryFailure: Throwable? = null
        try {
            extractor.setDataSource(inputFile.absolutePath)
            val trackIndex =
                (0 until extractor.trackCount).first { index ->
                    extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
                }
            val inputFormat = extractor.getTrackFormat(trackIndex)
            val mime = checkNotNull(inputFormat.getString(MediaFormat.KEY_MIME))
            extractor.selectTrack(trackIndex)
            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(inputFormat, null, null, 0)
            codec.start()
            codecStarted = true
            val pcm = ByteArrayOutputStream()
            var actualSampleRateHz: Int? = null
            var actualChannelCount: Int? = null
            var inputEnded = false
            var outputEnded = false
            var lastInputPresentationTimeUs = 0L
            val bufferInfo = MediaCodec.BufferInfo()
            val deadline = SystemClock.elapsedRealtime() + LONG_CODEC_TIMEOUT_MILLISECONDS
            while (!outputEnded) {
                check(SystemClock.elapsedRealtime() < deadline) { "Source AAC decoder timed out" }
                if (!inputEnded) {
                    val inputIndex = codec.dequeueInputBuffer(DEQUEUE_TIMEOUT_MICROSECONDS)
                    if (inputIndex >= 0) {
                        val inputBuffer = checkNotNull(codec.getInputBuffer(inputIndex)).apply { clear() }
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)
                        if (sampleSize < 0) {
                            codec.queueInputBuffer(
                                inputIndex,
                                0,
                                0,
                                lastInputPresentationTimeUs,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputEnded = true
                        } else {
                            lastInputPresentationTimeUs = extractor.sampleTime
                            codec.queueInputBuffer(inputIndex, 0, sampleSize, lastInputPresentationTimeUs, 0)
                            extractor.advance()
                        }
                    }
                }
                when (val outputIndex = codec.dequeueOutputBuffer(bufferInfo, DEQUEUE_TIMEOUT_MICROSECONDS)) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val outputFormat = codec.outputFormat
                        actualSampleRateHz = outputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        actualChannelCount = outputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        check(
                            outputFormat.getInteger(
                                MediaFormat.KEY_PCM_ENCODING,
                                AudioFormat.ENCODING_PCM_16BIT,
                            ) == AudioFormat.ENCODING_PCM_16BIT,
                        ) { "Source decoder did not emit PCM 16-bit" }
                    }
                    MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                    else ->
                        if (outputIndex >= 0) {
                            if (bufferInfo.size > 0) {
                                val output = checkNotNull(codec.getOutputBuffer(outputIndex)).duplicate()
                                output.position(bufferInfo.offset)
                                output.limit(bufferInfo.offset + bufferInfo.size)
                                val bytes = ByteArray(output.remaining()).also(output::get)
                                pcm.write(bytes)
                            }
                            outputEnded = bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                            codec.releaseOutputBuffer(outputIndex, false)
                        }
                }
            }
            val bytes = pcm.toByteArray()
            check(bytes.size % Short.SIZE_BYTES == 0) { "Source decoder emitted odd PCM byte count" }
            val shorts = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
            return SourcePcm(
                decoderName = codec.name,
                samples = ShortArray(shorts.remaining()).also(shorts::get),
                sampleRateHz = checkNotNull(actualSampleRateHz) { "Source decoder emitted no output format" },
                channelCount = checkNotNull(actualChannelCount) { "Source decoder emitted no output format" },
            )
        } catch (failure: Throwable) {
            primaryFailure = failure
            throw failure
        } finally {
            val activeCodec = codec
            val lifecycleFailure =
                finishSourceDecoderLifecycle(
                    primaryFailure = primaryFailure,
                    extractorRelease = extractor::release,
                    codecStop = { if (codecStarted) checkNotNull(activeCodec).stop() },
                    codecRelease = { activeCodec?.release() },
                )
            if (primaryFailure == null && lifecycleFailure != null) throw lifecycleFailure
        }
    }

    private fun mux(
        outputFile: File,
        encoded: AacRoundTripSpike.EncodedAudio,
    ) {
        val muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var started = false
        var primaryFailure: Throwable? = null
        try {
            val format =
                MediaFormat.createAudioFormat(
                    MediaFormat.MIMETYPE_AUDIO_AAC,
                    AacRoundTripSpike.SAMPLE_RATE_HZ,
                    AacRoundTripSpike.CHANNEL_COUNT,
                ).apply {
                    setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                    setInteger(MediaFormat.KEY_BIT_RATE, AacRoundTripSpike.BIT_RATE_BITS_PER_SECOND)
                    encoded.codecSpecificData.forEachIndexed { index, bytes ->
                        setByteBuffer("csd-$index", ByteBuffer.wrap(bytes))
                    }
                }
            val trackIndex = muxer.addTrack(format)
            muxer.start()
            started = true
            encoded.accessUnits.forEach { accessUnit ->
                val info =
                    MediaCodec.BufferInfo().apply {
                        set(0, accessUnit.bytes.size, accessUnit.presentationTimeUs, 0)
                    }
                muxer.writeSampleData(trackIndex, ByteBuffer.wrap(accessUnit.bytes), info)
            }
        } catch (failure: Throwable) {
            primaryFailure = failure
            throw failure
        } finally {
            val lifecycleFailure =
                finishMuxerLifecycle(
                    primaryFailure = primaryFailure,
                    stop = { if (started) muxer.stop() },
                    release = muxer::release,
                )
            if (primaryFailure == null && lifecycleFailure != null) throw lifecycleFailure
        }
    }

    private data class SourcePcm(
        val decoderName: String,
        val samples: ShortArray,
        val sampleRateHz: Int,
        val channelCount: Int,
    )

    companion object {
        private const val LONG_CODEC_TIMEOUT_MILLISECONDS = 120_000L
        private const val DEQUEUE_TIMEOUT_MICROSECONDS = 10_000L
        private const val MAX_ALIGNMENT_LAG_SAMPLES = 4_096
        private const val ALIGNMENT_WINDOW_SAMPLES = 16_000
    }
}

internal fun finishSourceDecoderLifecycle(
    primaryFailure: Throwable?,
    extractorRelease: () -> Unit,
    codecStop: () -> Unit,
    codecRelease: () -> Unit,
): Throwable? {
    var failure = primaryFailure
    listOf(extractorRelease, codecStop, codecRelease).forEach { cleanup ->
        try {
            cleanup()
        } catch (cleanupFailure: Throwable) {
            if (failure == null) {
                failure = cleanupFailure
            } else if (failure !== cleanupFailure) {
                checkNotNull(failure).addSuppressed(cleanupFailure)
            }
        }
    }
    return failure
}

internal fun finishPublishedMediaRollback(
    primaryFailure: Throwable,
    delete: () -> Int,
): Throwable {
    try {
        val deletedRows = delete()
        check(deletedRows == 1) { "Published media rollback deleted $deletedRows rows" }
    } catch (cleanupFailure: Throwable) {
        if (primaryFailure !== cleanupFailure) primaryFailure.addSuppressed(cleanupFailure)
    }
    return primaryFailure
}

private fun ByteArray.toHex(): String = joinToString(separator = "") { byte -> "%02x".format(byte.toInt() and 0xFF) }
