package com.loquiris.spike

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.os.SystemClock
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

data class PcmEncoderFanOutReport(
    val publishedFrames: Int,
    val canonicalAcceptedFrames: Long,
    val canonicalProcessedFrames: Long,
    val canonicalRejectedFrames: Long,
    val canonicalQueueCapacity: Int,
    val canonicalQueueHighWaterMark: Int,
    val inferenceAcceptedFrames: Long,
    val inferenceDroppedFrames: Long,
    val canonicalPcmMatchesSource: Boolean,
    val canonicalSequenceGaps: Int,
    val encoderWasConcurrentCanonicalSink: Boolean,
    val producerMissedDeadlines: Int,
    val producerElapsedMilliseconds: Long,
    val producerMaxLatenessMicroseconds: Long,
    val publishP50Microseconds: Long,
    val publishP95Microseconds: Long,
    val publishMaxMicroseconds: Long,
    val encoderName: String,
    val encodedAccessUnits: Int,
    val encodedBytes: Int,
    val encodedSampleCoverage: Double,
    val decodedSampleCoverage: Double,
    val encodeElapsedMilliseconds: Long,
) {
    fun toJson(): String =
        JSONObject()
            .put("schemaVersion", 2)
            .put("fixture", "deterministic_pcm_stalled_inference_v2")
            .put("sampleRateHz", AacRoundTripSpike.SAMPLE_RATE_HZ)
            .put("channelCount", AacRoundTripSpike.CHANNEL_COUNT)
            .put("pcmFrameDurationMilliseconds", FRAME_DURATION_MILLISECONDS)
            .put("publishedFrames", publishedFrames)
            .put("canonicalAcceptedFrames", canonicalAcceptedFrames)
            .put("canonicalProcessedFrames", canonicalProcessedFrames)
            .put("canonicalRejectedFrames", canonicalRejectedFrames)
            .put("canonicalQueueCapacity", canonicalQueueCapacity)
            .put("canonicalQueueHighWaterMark", canonicalQueueHighWaterMark)
            .put("inferenceAcceptedFrames", inferenceAcceptedFrames)
            .put("inferenceDroppedFrames", inferenceDroppedFrames)
            .put("canonicalPcmMatchesSource", canonicalPcmMatchesSource)
            .put("canonicalSequenceGaps", canonicalSequenceGaps)
            .put("encoderWasConcurrentCanonicalSink", encoderWasConcurrentCanonicalSink)
            .put("producerMissedDeadlines", producerMissedDeadlines)
            .put("producerElapsedMilliseconds", producerElapsedMilliseconds)
            .put("producerMaxLatenessMicroseconds", producerMaxLatenessMicroseconds)
            .put("publishP50Microseconds", publishP50Microseconds)
            .put("publishP95Microseconds", publishP95Microseconds)
            .put("publishMaxMicroseconds", publishMaxMicroseconds)
            .put("encoderName", encoderName)
            .put("encodedAccessUnits", encodedAccessUnits)
            .put("encodedBytes", encodedBytes)
            .put("encodedSampleCoverage", encodedSampleCoverage)
            .put("decodedSampleCoverage", decodedSampleCoverage)
            .put("encodeElapsedMilliseconds", encodeElapsedMilliseconds)
            .put(
                "limitation",
                "Synthetic paced producer and real concurrent AAC encoder; not AudioRecord or long-duration evidence.",
            ).toString(2)

    companion object {
        private const val FRAME_DURATION_MILLISECONDS = 20
    }
}

class PcmEncoderFanOutSpike {
    fun run(): PcmEncoderFanOutReport {
        val codecHarness = AacRoundTripSpike()
        val baseFixture = codecHarness.deterministicFixture()
        val source =
            ShortArray(baseFixture.size * FIXTURE_REPETITIONS) { index ->
                baseFixture[index % baseFixture.size]
            }
        val sourceBytes = source.toLittleEndianBytes()
        check(sourceBytes.size % FRAME_BYTES == 0)
        val publishedFrames = sourceBytes.size / FRAME_BYTES
        val publishMicros = LongArray(publishedFrames)
        val streamingEncoder = StreamingAacEncoder()
        var encoderFinished = false
        val fanOut =
            BoundedPcmFanOut(
                canonicalCapacity = CANONICAL_CAPACITY,
                inferenceCapacity = INFERENCE_CAPACITY,
                canonicalSink = streamingEncoder::append,
            )
        val producerStartedNanos = SystemClock.elapsedRealtimeNanos()
        var missedDeadlines = 0
        var maxLatenessNanos = 0L
        try {
            repeat(publishedFrames) { index ->
                val targetNanos =
                    producerStartedNanos +
                        (index + 1L) * FRAME_DURATION_MILLISECONDS * NANOSECONDS_PER_MILLISECOND
                waitUntil(targetNanos)
                val publishStartedNanos = SystemClock.elapsedRealtimeNanos()
                val latenessNanos = (publishStartedNanos - targetNanos).coerceAtLeast(0L)
                maxLatenessNanos = maxOf(maxLatenessNanos, latenessNanos)
                if (latenessNanos >= FRAME_DURATION_MILLISECONDS * NANOSECONDS_PER_MILLISECOND) {
                    missedDeadlines += 1
                }
                val offset = index * FRAME_BYTES
                val frame =
                    PcmFrame(
                        sequence = index.toLong(),
                        bytes = sourceBytes.copyOfRange(offset, offset + FRAME_BYTES),
                    )
                check(fanOut.publish(frame) == PcmPublishResult.accepted) {
                    "Canonical PCM publication rejected frame $index"
                }
                publishMicros[index] =
                    (SystemClock.elapsedRealtimeNanos() - publishStartedNanos) / NANOSECONDS_PER_MICROSECOND
            }
            val producerElapsedMilliseconds =
                (SystemClock.elapsedRealtimeNanos() - producerStartedNanos) / NANOSECONDS_PER_MILLISECOND
            val progressAtProducerEnd = streamingEncoder.progress
            check(fanOut.awaitCanonicalProcessed(publishedFrames.toLong(), CANONICAL_TIMEOUT_MILLISECONDS)) {
                "Canonical PCM worker did not process every frame"
            }
            val metrics = fanOut.metrics
            check(metrics.canonicalSinkFailures == 0L) { "Canonical AAC sink failed" }
            val encoded = streamingEncoder.finish()
            encoderFinished = true
            val decoded = codecHarness.decode(encoded.audio)
            val sortedPublishMicros = publishMicros.sortedArray()
            return PcmEncoderFanOutReport(
                publishedFrames = publishedFrames,
                canonicalAcceptedFrames = metrics.canonicalAcceptedFrames,
                canonicalProcessedFrames = metrics.canonicalProcessedFrames,
                canonicalRejectedFrames = metrics.canonicalRejectedFrames,
                canonicalQueueCapacity = CANONICAL_CAPACITY,
                canonicalQueueHighWaterMark = metrics.canonicalQueueHighWaterMark,
                inferenceAcceptedFrames = metrics.inferenceAcceptedFrames,
                inferenceDroppedFrames = metrics.inferenceDroppedFrames,
                canonicalPcmMatchesSource = encoded.canonicalPcm.contentEquals(sourceBytes),
                canonicalSequenceGaps = encoded.sequenceGaps,
                encoderWasConcurrentCanonicalSink =
                    progressAtProducerEnd.inputFrames > 0 && progressAtProducerEnd.accessUnits > 0,
                producerMissedDeadlines = missedDeadlines,
                producerElapsedMilliseconds = producerElapsedMilliseconds,
                producerMaxLatenessMicroseconds = maxLatenessNanos / NANOSECONDS_PER_MICROSECOND,
                publishP50Microseconds = sortedPublishMicros.percentile(50),
                publishP95Microseconds = sortedPublishMicros.percentile(95),
                publishMaxMicroseconds = sortedPublishMicros.last(),
                encoderName = encoded.audio.codecName,
                encodedAccessUnits = encoded.audio.accessUnits.size,
                encodedBytes = encoded.audio.accessUnits.sumOf { unit -> unit.bytes.size },
                encodedSampleCoverage =
                    encoded.audio.accessUnits.size.toDouble() * AAC_SAMPLES_PER_ACCESS_UNIT / source.size,
                decodedSampleCoverage = decoded.samples.size.toDouble() / source.size,
                encodeElapsedMilliseconds = encoded.audio.elapsedMilliseconds,
            )
        } finally {
            fanOut.close()
            if (!encoderFinished) streamingEncoder.abort()
        }
    }

    private fun waitUntil(targetNanos: Long) {
        while (true) {
            val remainingNanos = targetNanos - SystemClock.elapsedRealtimeNanos()
            if (remainingNanos <= 0L) return
            if (remainingNanos >= NANOSECONDS_PER_MILLISECOND) {
                SystemClock.sleep(remainingNanos / NANOSECONDS_PER_MILLISECOND)
            } else {
                Thread.yield()
            }
        }
    }

    companion object {
        private const val FIXTURE_REPETITIONS = 8
        private const val PCM_SAMPLES_PER_FRAME = 320
        private const val FRAME_BYTES = PCM_SAMPLES_PER_FRAME * Short.SIZE_BYTES
        private const val FRAME_DURATION_MILLISECONDS = 20L
        private const val CANONICAL_CAPACITY = 25
        private const val INFERENCE_CAPACITY = 2
        private const val AAC_SAMPLES_PER_ACCESS_UNIT = 1_024
        private const val CANONICAL_TIMEOUT_MILLISECONDS = 10_000L
        private const val NANOSECONDS_PER_MILLISECOND = 1_000_000L
        private const val NANOSECONDS_PER_MICROSECOND = 1_000L
    }
}

private data class StreamingAacProgress(
    val inputFrames: Int,
    val accessUnits: Int,
)

private data class StreamingAacResult(
    val audio: AacRoundTripSpike.EncodedAudio,
    val canonicalPcm: ByteArray,
    val sequenceGaps: Int,
)

private class StreamingAacEncoder {
    private val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
    private val canonicalPcm = ByteArrayOutputStream()
    private val accessUnits = mutableListOf<AacRoundTripSpike.AccessUnit>()
    private var codecSpecificData = emptyList<ByteArray>()
    private var started = false
    private var released = false
    private var inputSamples = 0
    private var expectedSequence = 0L
    private var sequenceGaps = 0
    private var startedAtMilliseconds = 0L

    @Volatile
    private var publishedInputFrames = 0

    @Volatile
    private var publishedAccessUnits = 0

    val progress: StreamingAacProgress
        get() = StreamingAacProgress(publishedInputFrames, publishedAccessUnits)

    fun append(frame: PcmFrame) {
        startIfNeeded()
        if (frame.sequence != expectedSequence) {
            sequenceGaps += 1
        }
        expectedSequence = frame.sequence + 1L
        val bytes = frame.copyBytes()
        check(bytes.size == FRAME_BYTES) { "Unexpected PCM frame size ${bytes.size}" }
        canonicalPcm.write(bytes)
        drainAvailable()
        val inputIndex = dequeueInputBuffer()
        val inputBuffer = checkNotNull(codec.getInputBuffer(inputIndex)).apply { clear() }
        check(inputBuffer.remaining() >= bytes.size) { "AAC encoder input buffer is too small" }
        inputBuffer.put(bytes)
        codec.queueInputBuffer(
            inputIndex,
            0,
            bytes.size,
            presentationTimeMicroseconds(inputSamples),
            0,
        )
        inputSamples += bytes.size / Short.SIZE_BYTES
        publishedInputFrames += 1
        drainAvailable()
    }

    fun finish(): StreamingAacResult {
        check(started) { "AAC encoder received no PCM" }
        val eosInputIndex = dequeueInputBuffer()
        codec.queueInputBuffer(
            eosInputIndex,
            0,
            0,
            presentationTimeMicroseconds(inputSamples),
            MediaCodec.BUFFER_FLAG_END_OF_STREAM,
        )
        val deadline = SystemClock.elapsedRealtime() + FINISH_TIMEOUT_MILLISECONDS
        var outputEnded = false
        while (!outputEnded) {
            check(SystemClock.elapsedRealtime() < deadline) { "Streaming AAC encoder timed out finishing" }
            outputEnded = drainOne(DEQUEUE_TIMEOUT_MICROSECONDS) == DrainOutcome.endOfStream
        }
        val codecName = codec.name
        releaseCodec()
        check(codecSpecificData.isNotEmpty()) { "Streaming AAC encoder emitted no codec-specific data" }
        check(accessUnits.isNotEmpty()) { "Streaming AAC encoder emitted no access units" }
        check(
            accessUnits.zipWithNext().all { (first, second) ->
                first.presentationTimeUs < second.presentationTimeUs
            },
        ) { "Streaming AAC encoder emitted non-increasing timestamps" }
        return StreamingAacResult(
            audio =
                AacRoundTripSpike.EncodedAudio(
                    codecName = codecName,
                    codecSpecificData = codecSpecificData,
                    accessUnits = accessUnits.toList(),
                    elapsedMilliseconds = SystemClock.elapsedRealtime() - startedAtMilliseconds,
                    mediaEndPresentationTimeUs = presentationTimeMicroseconds(inputSamples),
                ),
            canonicalPcm = canonicalPcm.toByteArray(),
            sequenceGaps = sequenceGaps,
        )
    }

    fun abort() {
        releaseCodec()
    }

    private fun startIfNeeded() {
        if (started) return
        val format =
            MediaFormat.createAudioFormat(
                MediaFormat.MIMETYPE_AUDIO_AAC,
                AacRoundTripSpike.SAMPLE_RATE_HZ,
                AacRoundTripSpike.CHANNEL_COUNT,
            ).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, AacRoundTripSpike.BIT_RATE_BITS_PER_SECOND)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, MAX_INPUT_BYTES)
            }
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()
        started = true
        startedAtMilliseconds = SystemClock.elapsedRealtime()
    }

    private fun dequeueInputBuffer(): Int {
        val deadline = SystemClock.elapsedRealtime() + INPUT_TIMEOUT_MILLISECONDS
        while (true) {
            val inputIndex = codec.dequeueInputBuffer(DEQUEUE_TIMEOUT_MICROSECONDS)
            if (inputIndex >= 0) return inputIndex
            drainAvailable()
            check(SystemClock.elapsedRealtime() < deadline) { "Streaming AAC encoder input timed out" }
        }
    }

    private fun drainAvailable() {
        while (drainOne(0L) != DrainOutcome.none) {
            // Continue until MediaCodec reports that no output is immediately available.
        }
    }

    private fun drainOne(timeoutMicroseconds: Long): DrainOutcome {
        val bufferInfo = MediaCodec.BufferInfo()
        return when (val outputIndex = codec.dequeueOutputBuffer(bufferInfo, timeoutMicroseconds)) {
            MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                codecSpecificData = copyCodecSpecificData(codec.outputFormat)
                DrainOutcome.progress
            }
            MediaCodec.INFO_TRY_AGAIN_LATER -> DrainOutcome.none
            else -> {
                if (outputIndex < 0) return DrainOutcome.none
                if (bufferInfo.size > 0 && bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                    accessUnits +=
                        AacRoundTripSpike.AccessUnit(
                            bytes = copyOutput(outputIndex, bufferInfo),
                            presentationTimeUs = bufferInfo.presentationTimeUs,
                        )
                    publishedAccessUnits = accessUnits.size
                }
                val outputEnded = bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                codec.releaseOutputBuffer(outputIndex, false)
                if (outputEnded) DrainOutcome.endOfStream else DrainOutcome.progress
            }
        }
    }

    private fun copyCodecSpecificData(format: MediaFormat): List<ByteArray> {
        val result = mutableListOf<ByteArray>()
        var index = 0
        while (true) {
            val buffer = format.getByteBuffer("csd-$index") ?: break
            result += copyBuffer(buffer.duplicate())
            index += 1
        }
        return result
    }

    private fun copyOutput(
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

    private fun presentationTimeMicroseconds(sampleOffset: Int): Long =
        sampleOffset.toLong() * 1_000_000L / AacRoundTripSpike.SAMPLE_RATE_HZ

    private fun releaseCodec() {
        if (released) return
        released = true
        if (started) runCatching(codec::stop)
        codec.release()
    }

    companion object {
        private const val PCM_SAMPLES_PER_FRAME = 320
        private const val FRAME_BYTES = PCM_SAMPLES_PER_FRAME * Short.SIZE_BYTES
        private const val MAX_INPUT_BYTES = 4_096
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

private fun ShortArray.toLittleEndianBytes(): ByteArray =
    ByteBuffer.allocate(size * Short.SIZE_BYTES).order(ByteOrder.LITTLE_ENDIAN).apply {
        forEach(::putShort)
    }.array()

private fun LongArray.percentile(percent: Int): Long {
    require(isNotEmpty())
    require(percent in 0..100)
    val index = ((size - 1) * percent + 99) / 100
    return this[index]
}
