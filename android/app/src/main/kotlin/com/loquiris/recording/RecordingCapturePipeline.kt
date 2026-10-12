package com.loquiris.recording

import java.io.Closeable
import java.util.concurrent.atomic.AtomicReference
import java.util.concurrent.atomic.AtomicBoolean

interface PcmCaptureSource : Closeable {
    fun start(): Boolean

    fun read(target: ByteArray): Int

    fun stop(): Boolean

    fun timestampFramePosition(): Long?

    fun release()

    override fun close() = release()

    companion object {
        const val READ_STOPPED = -10_001
    }
}

interface CanonicalPcmEncoder {
    fun prepare(): Boolean = true

    fun appendPcm(frame: PcmCaptureFrame): Boolean

    fun finish(): Boolean

    fun abort()

    fun bytesWritten(): Long
}

enum class RecordingCapturePipelineState {
    idle,
    recording,
    paused,
    finishing,
    finished,
    failed,
}

object RecordingCaptureFailurePolicy {
    fun requiresRecovery(state: RecordingCapturePipelineState): Boolean =
        state == RecordingCapturePipelineState.failed
}

data class RecordingCapturePipelineSnapshot(
    val state: RecordingCapturePipelineState,
    val inputHealth: AudioInputHealthSnapshot,
    val fanOut: PriorityPcmFanOutMetrics,
    val bytesWritten: Long,
    val failureCode: String?,
)

sealed interface RecordingCaptureCommandResult {
    data object Success : RecordingCaptureCommandResult

    data class Failure(
        val code: String,
    ) : RecordingCaptureCommandResult
}

class RecordingCapturePipeline(
    private val source: PcmCaptureSource,
    private val encoder: CanonicalPcmEncoder,
    canonicalQueueCapacity: Int = DEFAULT_CANONICAL_QUEUE_CAPACITY,
    inferenceQueueCapacity: Int = DEFAULT_INFERENCE_QUEUE_CAPACITY,
    canonicalWorkerJoinTimeoutMillis: Long = DEFAULT_CANONICAL_WORKER_JOIN_TIMEOUT_MILLISECONDS,
    canonicalWorkerInterruptJoinTimeoutMillis: Long = DEFAULT_CANONICAL_WORKER_INTERRUPT_TIMEOUT_MILLISECONDS,
    private val elapsedRealtimeNanos: () -> Long = System::nanoTime,
) : Closeable {
    @Suppress("PLATFORM_CLASS_MAPPED_TO_KOTLIN")
    private val lifecycle = java.lang.Object()
    private val health = AudioInputHealthTracker(elapsedRealtimeNanos)
    private val failure = AtomicReference<String?>()
    private val sourceReleased = AtomicBoolean()
    private val encoderCleanupScheduled = AtomicBoolean()
    private val fanOut =
        PriorityPcmFanOut(
            canonicalCapacity = canonicalQueueCapacity,
            inferenceCapacity = inferenceQueueCapacity,
            canonicalSink = { frame ->
                check(encoder.appendPcm(frame)) { "canonical encoder rejected PCM" }
            },
            workerJoinTimeoutMillis = canonicalWorkerJoinTimeoutMillis,
            workerInterruptJoinTimeoutMillis = canonicalWorkerInterruptJoinTimeoutMillis,
        )

    @Volatile
    private var state = RecordingCapturePipelineState.idle
    @Volatile
    private var captureBoundaryNanos: Long? = null
    private var nextSequence = 0L
    private var captureThread: Thread? = null
    private var readInProgress = false

    fun start(): RecordingCaptureCommandResult =
        synchronized(lifecycle) {
            when (state) {
                RecordingCapturePipelineState.recording -> RecordingCaptureCommandResult.Success
                RecordingCapturePipelineState.idle -> {
                    if (!encoder.prepare()) return@synchronized failLocked("recording_encoder_prepare_failed")
                    if (!source.start()) return@synchronized failLocked("recording_input_start_failed")
                    state = RecordingCapturePipelineState.recording
                    captureBoundaryNanos = elapsedRealtimeNanos()
                    captureThread =
                        Thread(::captureLoop, "loquiris-pcm-capture").apply {
                            priority = Thread.MAX_PRIORITY
                            start()
                        }
                    RecordingCaptureCommandResult.Success
                }
                else -> RecordingCaptureCommandResult.Failure("recording_capture_start_invalid_state")
            }
        }

    fun pause(): RecordingCaptureCommandResult =
        synchronized(lifecycle) {
            when (state) {
                RecordingCapturePipelineState.paused -> RecordingCaptureCommandResult.Success
                RecordingCapturePipelineState.recording -> {
                    state = RecordingCapturePipelineState.paused
                    captureBoundaryNanos = elapsedRealtimeNanos()
                    if (!source.stop()) return@synchronized failLocked("recording_input_pause_failed")
                    val deadline = System.nanoTime() + PAUSE_READ_SETTLE_TIMEOUT_NANOS
                    while (readInProgress) {
                        val remaining = deadline - System.nanoTime()
                        if (remaining <= 0) return@synchronized failLocked("recording_input_pause_timed_out")
                        lifecycle.wait(
                            remaining / NANOS_PER_MILLISECOND,
                            (remaining % NANOS_PER_MILLISECOND).toInt(),
                        )
                    }
                    RecordingCaptureCommandResult.Success
                }
                else -> RecordingCaptureCommandResult.Failure("recording_capture_pause_invalid_state")
            }
        }

    fun resume(): RecordingCaptureCommandResult =
        synchronized(lifecycle) {
            when (state) {
                RecordingCapturePipelineState.recording -> RecordingCaptureCommandResult.Success
                RecordingCapturePipelineState.paused -> {
                    if (!source.start()) return@synchronized failLocked("recording_input_resume_failed")
                    state = RecordingCapturePipelineState.recording
                    captureBoundaryNanos = elapsedRealtimeNanos()
                    lifecycle.notifyAll()
                    RecordingCaptureCommandResult.Success
                }
                else -> RecordingCaptureCommandResult.Failure("recording_capture_resume_invalid_state")
            }
        }

    fun finish(): RecordingCaptureCommandResult {
        val thread =
            synchronized(lifecycle) {
                when (state) {
                    RecordingCapturePipelineState.finished -> return RecordingCaptureCommandResult.Success
                    RecordingCapturePipelineState.finishing -> captureThread
                    RecordingCapturePipelineState.idle,
                    RecordingCapturePipelineState.failed,
                    -> return RecordingCaptureCommandResult.Failure(
                        failure.get() ?: "recording_capture_finish_invalid_state",
                    )
                    RecordingCapturePipelineState.recording,
                    RecordingCapturePipelineState.paused,
                    -> {
                        state = RecordingCapturePipelineState.finishing
                        source.stop()
                        lifecycle.notifyAll()
                        captureThread
                    }
                }
        }
        thread?.join(CAPTURE_JOIN_TIMEOUT_MILLISECONDS)
        if (thread?.isAlive == true) {
            releaseSource()
            thread.interrupt()
            thread.join(CAPTURE_INTERRUPT_JOIN_TIMEOUT_MILLISECONDS)
        }
        if (thread?.isAlive == true) {
            val quiesced = fanOut.shutdown()
            return failAndAbort("recording_capture_stop_timed_out", quiesced)
        }
        val quiesced = fanOut.shutdown()
        if (!quiesced) return failAndAbort("recording_canonical_shutdown_timed_out", false)
        val metrics = fanOut.metrics
        if (
            metrics.canonicalSinkFailures > 0 ||
            metrics.canonicalRejectedFrames > 0 ||
            metrics.canonicalProcessedFrames != metrics.canonicalAcceptedFrames
        ) {
            return failAndAbort("recording_canonical_audio_incomplete")
        }
        if (!encoder.finish()) return failAndAbort("recording_encoder_finalize_failed")
        releaseSource()
        synchronized(lifecycle) { state = RecordingCapturePipelineState.finished }
        return RecordingCaptureCommandResult.Success
    }

    fun snapshot(): RecordingCapturePipelineSnapshot =
        RecordingCapturePipelineSnapshot(
            state = state,
            inputHealth = health.snapshot(),
            fanOut = fanOut.metrics,
            bytesWritten = encoder.bytesWritten(),
            failureCode = failure.get(),
        )

    fun replaceInferenceConsumer(consumer: PcmInferenceConsumer?) {
        fanOut.replaceInferenceConsumer(consumer)
    }

    fun captureBoundaryElapsedRealtimeNanos(): Long? = captureBoundaryNanos

    override fun close() {
        if (state == RecordingCapturePipelineState.finished) return
        synchronized(lifecycle) {
            state = RecordingCapturePipelineState.failed
            failure.compareAndSet(null, "recording_capture_aborted")
            runCatching(source::stop)
            lifecycle.notifyAll()
        }
        captureThread?.join(CAPTURE_JOIN_TIMEOUT_MILLISECONDS)
        if (captureThread?.isAlive == true) {
            releaseSource()
            captureThread?.interrupt()
            captureThread?.join(CAPTURE_INTERRUPT_JOIN_TIMEOUT_MILLISECONDS)
        }
        val quiesced = fanOut.shutdown()
        if (quiesced) {
            abortEncoderOnce()
        } else {
            deferEncoderAbortUntilFanOutStops()
        }
        releaseSource()
    }

    private fun captureLoop() {
        val buffer = ByteArray(PCM_READ_BYTES)
        while (true) {
            synchronized(lifecycle) {
                while (state == RecordingCapturePipelineState.paused) lifecycle.wait()
                if (
                    state == RecordingCapturePipelineState.finishing ||
                    state == RecordingCapturePipelineState.finished ||
                    state == RecordingCapturePipelineState.failed
                ) {
                    return
                }
            }
            synchronized(lifecycle) {
                if (state != RecordingCapturePipelineState.recording) continue
                readInProgress = true
            }
            val read =
                try {
                    source.read(buffer)
                } catch (_: Exception) {
                    health.recordRead(buffer.size, -1)
                    failFromCapture("recording_input_read_failed")
                    return
                } finally {
                    synchronized(lifecycle) {
                        readInProgress = false
                        lifecycle.notifyAll()
                    }
                }
            val stateAfterRead = state
            if (stateAfterRead == RecordingCapturePipelineState.paused) continue
            if (stateAfterRead == RecordingCapturePipelineState.finishing) return
            if (read == PcmCaptureSource.READ_STOPPED && stateAfterRead != RecordingCapturePipelineState.recording) {
                continue
            }
            health.recordRead(buffer.size, read)
            if (read < 0) {
                failFromCapture("recording_input_read_failed")
                return
            }
            if (read == 0) continue
            source.timestampFramePosition()?.let(health::recordTimestamp)
            val frame = PcmCaptureFrame(nextSequence, buffer.copyOf(read))
            when (fanOut.publish(frame)) {
                PcmFanOutPublishResult.accepted -> nextSequence = Math.addExact(nextSequence, 1L)
                PcmFanOutPublishResult.canonicalQueueFull -> {
                    failFromCapture("recording_canonical_queue_full")
                    return
                }
                PcmFanOutPublishResult.canonicalSinkFailed -> {
                    failFromCapture("recording_canonical_encoder_failed")
                    return
                }
                PcmFanOutPublishResult.closed -> {
                    failFromCapture("recording_canonical_pipeline_closed")
                    return
                }
            }
        }
    }

    private fun failFromCapture(code: String) {
        synchronized(lifecycle) {
            failure.compareAndSet(null, code)
            state = RecordingCapturePipelineState.failed
            source.stop()
            lifecycle.notifyAll()
        }
    }

    private fun failLocked(code: String): RecordingCaptureCommandResult.Failure {
        failure.compareAndSet(null, code)
        state = RecordingCapturePipelineState.failed
        releaseSource()
        return RecordingCaptureCommandResult.Failure(code)
    }

    private fun failAndAbort(
        code: String,
        fanOutQuiesced: Boolean = true,
    ): RecordingCaptureCommandResult.Failure {
        failure.compareAndSet(null, code)
        synchronized(lifecycle) { state = RecordingCapturePipelineState.failed }
        if (fanOutQuiesced) abortEncoderOnce() else deferEncoderAbortUntilFanOutStops()
        releaseSource()
        return RecordingCaptureCommandResult.Failure(failure.get() ?: code)
    }

    private fun abortEncoderOnce() {
        if (encoderCleanupScheduled.compareAndSet(false, true)) runCatching(encoder::abort)
    }

    private fun deferEncoderAbortUntilFanOutStops() {
        if (!encoderCleanupScheduled.compareAndSet(false, true)) return
        Thread(
            {
                fanOut.awaitQuiescence()
                runCatching(encoder::abort)
            },
            "loquiris-encoder-cleanup",
        ).apply {
            isDaemon = true
            start()
        }
    }

    private fun releaseSource() {
        if (sourceReleased.compareAndSet(false, true)) runCatching(source::release)
    }

    companion object {
        const val PCM_READ_BYTES = 640
        const val DEFAULT_CANONICAL_QUEUE_CAPACITY = 64
        const val DEFAULT_INFERENCE_QUEUE_CAPACITY = 16
        const val DEFAULT_CANONICAL_WORKER_JOIN_TIMEOUT_MILLISECONDS = 5_000L
        const val DEFAULT_CANONICAL_WORKER_INTERRUPT_TIMEOUT_MILLISECONDS = 1_000L
        private const val CAPTURE_JOIN_TIMEOUT_MILLISECONDS = 5_000L
        private const val CAPTURE_INTERRUPT_JOIN_TIMEOUT_MILLISECONDS = 1_000L
        private const val PAUSE_READ_SETTLE_TIMEOUT_NANOS = 5_000_000_000L
        private const val NANOS_PER_MILLISECOND = 1_000_000L
    }
}
