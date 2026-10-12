package com.loquiris.recording

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.os.SystemClock
import java.io.Closeable
import java.io.File
import java.nio.ByteBuffer

data class RecordingEncoderSnapshot(
    val inputSamples: Long,
    val encodedAccessUnits: Int,
    val bytesWritten: Long,
    val codecName: String,
    val failureCode: String?,
    val finished: Boolean,
)

sealed interface RecordingEncoderCreateResult {
    data class Success(
        val encoder: AndroidAacSegmentEncoder,
    ) : RecordingEncoderCreateResult

    data class Failure(
        val code: String,
    ) : RecordingEncoderCreateResult
}

sealed interface RecordingEncoderCommandResult {
    data class Success(
        val snapshot: RecordingEncoderSnapshot,
    ) : RecordingEncoderCommandResult

    data class Failure(
        val code: String,
        val snapshot: RecordingEncoderSnapshot,
    ) : RecordingEncoderCommandResult
}

class AndroidAacSegmentEncoder private constructor(
    private val codec: MediaCodec,
    private val directory: File,
    private val sessionId: String,
    private val segmentationPolicy: RecordingSegmentationPolicy,
    private val continuation: Boolean,
) : Closeable {
    private var coordinator: RecordingSegmentCoordinator? = null
    private var inputSamples = 0L
    private var encodedAccessUnits = 0
    private var failureCode: String? = null
    private var finished = false
    private var released = false

    val codecName: String = codec.name

    @Synchronized
    fun prepare(): RecordingEncoderCommandResult {
        failureCode?.let { return failure(it) }
        if (finished) return failure("recording_encoder_closed")
        if (!continuation || coordinator != null) return success()
        return try {
            val opened =
                RecordingSegmentCoordinator.continueFromManifest(
                    directory = directory,
                    sessionId = sessionId,
                    policy = segmentationPolicy,
                )
            check(opened is RecordingSegmentOpenResult.Success) {
                "continuation segment coordinator initialization failed"
            }
            coordinator = opened.coordinator
            success()
        } catch (_: Exception) {
            fail("recording_encoder_prepare_failed")
        }
    }

    @Synchronized
    fun appendPcm(bytes: ByteArray): RecordingEncoderCommandResult {
        failureCode?.let { return failure(it) }
        if (finished) return failure("recording_encoder_closed")
        if (bytes.isEmpty() || bytes.size % PCM_BYTES_PER_SAMPLE != 0 || bytes.size > MAX_INPUT_BYTES) {
            return failure("recording_pcm_frame_invalid")
        }
        return try {
            drainAvailable()
            val inputIndex = dequeueInputBuffer()
            val inputBuffer = checkNotNull(codec.getInputBuffer(inputIndex)).apply { clear() }
            check(inputBuffer.remaining() >= bytes.size) { "AAC input buffer is too small" }
            inputBuffer.put(bytes)
            codec.queueInputBuffer(
                inputIndex,
                0,
                bytes.size,
                presentationTimeMicroseconds(inputSamples),
                0,
            )
            inputSamples = Math.addExact(inputSamples, bytes.size.toLong() / PCM_BYTES_PER_SAMPLE)
            drainAvailable()
            success()
        } catch (_: Exception) {
            fail("recording_encoder_write_failed")
        }
    }

    @Synchronized
    fun finish(): RecordingEncoderCommandResult {
        failureCode?.let { return failure(it) }
        if (finished) return success()
        return try {
            val inputIndex = dequeueInputBuffer()
            codec.queueInputBuffer(
                inputIndex,
                0,
                0,
                presentationTimeMicroseconds(inputSamples),
                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
            )
            val deadline = SystemClock.elapsedRealtime() + FINISH_TIMEOUT_MILLISECONDS
            var outputEnded = false
            while (!outputEnded) {
                check(SystemClock.elapsedRealtime() < deadline) { "AAC encoder finish timed out" }
                outputEnded = drainOne(DEQUEUE_TIMEOUT_MICROSECONDS) == DrainOutcome.endOfStream
            }
            val segmentResult = checkNotNull(coordinator).finish()
            check(segmentResult is RecordingSegmentCommandResult.Success) { "segment finalization failed" }
            finished = true
            releaseCodec()
            success()
        } catch (_: Exception) {
            fail("recording_encoder_finalize_failed")
        }
    }

    @Synchronized
    fun snapshot(): RecordingEncoderSnapshot =
        RecordingEncoderSnapshot(
            inputSamples = inputSamples,
            encodedAccessUnits = encodedAccessUnits,
            bytesWritten = coordinator?.snapshot()?.bytesWritten ?: 0L,
            codecName = codecName,
            failureCode = failureCode,
            finished = finished,
        )

    @Synchronized
    fun abort() {
        if (released) return
        runCatching { coordinator?.finish() }
        releaseCodec()
    }

    override fun close() {
        if (!finished) abort()
    }

    private fun dequeueInputBuffer(): Int {
        val deadline = SystemClock.elapsedRealtime() + INPUT_TIMEOUT_MILLISECONDS
        while (true) {
            val index = codec.dequeueInputBuffer(DEQUEUE_TIMEOUT_MICROSECONDS)
            if (index >= 0) return index
            drainAvailable()
            check(SystemClock.elapsedRealtime() < deadline) { "AAC input timed out" }
        }
    }

    private fun drainAvailable() {
        while (drainOne(0) != DrainOutcome.none) {
            // Drain all immediately available output before returning to capture input.
        }
    }

    private fun drainOne(timeoutMicroseconds: Long): DrainOutcome {
        val info = MediaCodec.BufferInfo()
        return when (val outputIndex = codec.dequeueOutputBuffer(info, timeoutMicroseconds)) {
            MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                initializeSegments(codec.outputFormat)
                DrainOutcome.progress
            }
            MediaCodec.INFO_TRY_AGAIN_LATER -> DrainOutcome.none
            else -> {
                if (outputIndex < 0) return DrainOutcome.none
                try {
                    if (info.size > 0 && info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                        val accessUnit = copyOutput(outputIndex, info)
                        val result = checkNotNull(coordinator).appendAccessUnit(accessUnit)
                        check(result is RecordingSegmentCommandResult.Success) { "segment append failed" }
                        encodedAccessUnits = Math.addExact(encodedAccessUnits, 1)
                    }
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        DrainOutcome.endOfStream
                    } else {
                        DrainOutcome.progress
                    }
                } finally {
                    codec.releaseOutputBuffer(outputIndex, false)
                }
            }
        }
    }

    private fun initializeSegments(format: MediaFormat) {
        val codecSpecificData =
            generateSequence(0) { it + 1 }
                .map { index -> format.getByteBuffer("csd-$index") ?: return@map null }
                .takeWhile { it != null }
                .map { buffer -> copyBuffer(checkNotNull(buffer).duplicate()) }
                .toList()
        check(codecSpecificData.isNotEmpty()) { "AAC output format has no codec-specific data" }
        check(
            ProductionAacFormat.isExpected(
                mimeType = format.getString(MediaFormat.KEY_MIME),
                sampleRateHz = format.getInteger(MediaFormat.KEY_SAMPLE_RATE),
                channelCount = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT),
                aacProfile = format.optionalInteger(MediaFormat.KEY_AAC_PROFILE),
                bitRateBitsPerSecond = format.optionalInteger(MediaFormat.KEY_BIT_RATE),
                codecSpecificData = codecSpecificData,
            ),
        ) { "AAC encoder negotiated an unsupported output format" }
        if (continuation) {
            check(prepare() is RecordingEncoderCommandResult.Success) {
                "continuation segment coordinator initialization failed"
            }
            return
        }
        check(coordinator == null) { "AAC output format changed more than once" }
        val opened =
            RecordingSegmentCoordinator.open(
                directory = directory,
                sessionId = sessionId,
                codecSpecificData = codecSpecificData,
                policy = segmentationPolicy,
            )
        check(opened is RecordingSegmentOpenResult.Success) { "segment coordinator initialization failed" }
        coordinator = opened.coordinator
    }

    private fun copyOutput(
        outputIndex: Int,
        info: MediaCodec.BufferInfo,
    ): ByteArray {
        val output = checkNotNull(codec.getOutputBuffer(outputIndex)).duplicate()
        output.position(info.offset)
        output.limit(info.offset + info.size)
        return copyBuffer(output)
    }

    private fun copyBuffer(buffer: ByteBuffer): ByteArray = ByteArray(buffer.remaining()).also(buffer::get)

    private fun MediaFormat.optionalInteger(key: String): Int? =
        if (containsKey(key)) getInteger(key) else null

    private fun presentationTimeMicroseconds(sampleOffset: Long): Long =
        sampleOffset * MICROSECONDS_PER_SECOND / SAMPLE_RATE_HZ

    private fun success() = RecordingEncoderCommandResult.Success(snapshot())

    private fun failure(code: String) = RecordingEncoderCommandResult.Failure(code, snapshot())

    private fun fail(code: String): RecordingEncoderCommandResult.Failure {
        failureCode = code
        return failure(code)
    }

    private fun releaseCodec() {
        if (released) return
        released = true
        runCatching(codec::stop)
        codec.release()
    }

    companion object {
        fun create(
            directory: File,
            sessionId: String,
            segmentationPolicy: RecordingSegmentationPolicy = RecordingSegmentationPolicy.production,
            continuation: Boolean = false,
        ): RecordingEncoderCreateResult {
            if (sessionId.isBlank()) return RecordingEncoderCreateResult.Failure("recording_session_invalid")
            var codec: MediaCodec? = null
            return try {
                codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
                val format =
                    MediaFormat.createAudioFormat(
                        MediaFormat.MIMETYPE_AUDIO_AAC,
                        SAMPLE_RATE_HZ,
                        CHANNEL_COUNT,
                    ).apply {
                        setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                        setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE_BITS_PER_SECOND)
                        setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, MAX_INPUT_BYTES)
                    }
                codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                codec.start()
                RecordingEncoderCreateResult.Success(
                    AndroidAacSegmentEncoder(codec, directory, sessionId, segmentationPolicy, continuation),
                )
            } catch (_: Exception) {
                runCatching { codec?.release() }
                RecordingEncoderCreateResult.Failure("recording_encoder_initialize_failed")
            }
        }

        const val SAMPLE_RATE_HZ = 16_000
        const val CHANNEL_COUNT = 1
        const val BIT_RATE_BITS_PER_SECOND = 64_000
        const val PCM_BYTES_PER_SAMPLE = 2
        const val MAX_INPUT_BYTES = 4_096
        private const val MICROSECONDS_PER_SECOND = 1_000_000L
        private const val DEQUEUE_TIMEOUT_MICROSECONDS = 10_000L
        private const val INPUT_TIMEOUT_MILLISECONDS = 1_000L
        private const val FINISH_TIMEOUT_MILLISECONDS = 20_000L
    }

    private enum class DrainOutcome {
        none,
        progress,
        endOfStream,
    }
}
