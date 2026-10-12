package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame
import com.loquiris.recording.PcmInferenceConsumer
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.Executor
import java.util.concurrent.Executors

sealed interface LiveDraftStartResult {
    data object Started : LiveDraftStartResult

    data class Failure(
        val code: String,
    ) : LiveDraftStartResult
}

sealed interface LiveDraftRuntimeEvent {
    val runId: String
}

data class LiveDraftUpdated(
    override val runId: String,
    val segment: ReconciledDraftSegment,
    val backlogMilliseconds: Long,
) : LiveDraftRuntimeEvent

data class LiveDraftDegraded(
    override val runId: String,
    val code: String,
    val backlogMilliseconds: Long,
    val incomplete: Boolean,
) : LiveDraftRuntimeEvent

interface LiveDraftSession : PcmInferenceConsumer, AutoCloseable {
    fun start(): LiveDraftStartResult

    fun degrade(code: String)
}

class WhisperDraftEngine(
    private val runId: String,
    private val modelProvider: WhisperModelProvider,
    private val native: WhisperNativeApi,
    private val eventEmitter: (LiveDraftRuntimeEvent) -> Unit,
    private val languageHint: TranscriptionLanguageHint = TranscriptionLanguageHint.mixed,
    private val sampleRateHz: Int = DEFAULT_SAMPLE_RATE_HZ,
    private val windowSamples: Int = DEFAULT_WINDOW_SAMPLES,
    private val strideSamples: Int = DEFAULT_STRIDE_SAMPLES,
    stableHorizonMilliseconds: Long = DEFAULT_STABLE_HORIZON_MILLISECONDS,
    private val arbiter: WhisperInferenceArbiter = WhisperInferenceArbiter(),
    private val cleanupExecutor: Executor = cleanupWorker,
) : LiveDraftSession {
    private val closed = AtomicBoolean()
    private val inFlight = AtomicBoolean()
    private val nativeReleased = AtomicBoolean()
    private val reconciler = DraftHypothesisReconciler(stableHorizonMilliseconds)
    private val rollingPcm = ShortArray(windowSamples)

    @Volatile
    private var contextHandle = 0L

    @Volatile
    private var runHandle = 0L
    private var rollingSampleCount = 0
    private var observedSamples = 0L
    private var nextDecodeAtSamples = windowSamples.toLong()
    private var lastSequence: Long? = null
    private var lastFrameSampleCount = 0
    private var inferenceLease: AutoCloseable? = null
    private var latestBacklogMilliseconds = 0L
    private var lastDroppedFrames = 0L

    init {
        require(runId.matches(SAFE_IDENTIFIER))
        require(sampleRateHz > 0)
        require(windowSamples > 0)
        require(strideSamples in 1..windowSamples)
    }

    @Synchronized
    override fun start(): LiveDraftStartResult {
        if (contextHandle != 0L && runHandle != 0L && !closed.get()) return LiveDraftStartResult.Started
        if (closed.get()) return failStart("transcription_live_closed")
        inferenceLease = arbiter.acquireLive(closed::get)
            ?: return failStart("transcription_live_engine_failed")
        val model =
            when (val materialized = modelProvider.materialize()) {
                is ModelMaterializationResult.Ready -> materialized.file
                is ModelMaterializationResult.Failure -> return failStart(safeModelFailure(materialized.code))
            }
        if (closed.get()) return failStart("transcription_live_closed")
        return try {
            val context = native.createContext(model.absolutePath)
            if (context == 0L) return failStart(stableNativeFailure())
            contextHandle = context
            if (closed.get()) return failStart("transcription_live_closed")
            val run = native.createRun()
            if (run == 0L) {
                releaseNative()
                return failStart(stableNativeFailure())
            }
            runHandle = run
            if (closed.get()) return failStart("transcription_live_closed")
            LiveDraftStartResult.Started
        } catch (_: OutOfMemoryError) {
            releaseNative()
            failStart("transcription_native_out_of_memory")
        } catch (_: LinkageError) {
            releaseNative()
            failStart("transcription_native_unavailable")
        } catch (_: RuntimeException) {
            releaseNative()
            failStart("transcription_native_failed")
        }
    }

    @Synchronized
    override fun consume(frame: PcmCaptureFrame) {
        if (closed.get() || contextHandle == 0L || runHandle == 0L) return
        val samples = decodeLittleEndianPcm(frame.copyBytes())
        if (samples.isEmpty()) return
        val previousSequence = lastSequence
        if (previousSequence == null) {
            observedSamples = Math.multiplyExact(frame.sequence, samples.size.toLong())
        }
        if (previousSequence != null && frame.sequence != previousSequence + 1L) {
            emitDegraded("transcription_live_pcm_gap", incomplete = true)
            if (frame.sequence <= previousSequence) return
            val missingSamples = Math.multiplyExact(frame.sequence - previousSequence - 1, lastFrameSampleCount.toLong())
            observedSamples = Math.addExact(observedSamples, missingSamples)
            rollingSampleCount = 0
            nextDecodeAtSamples = Math.addExact(observedSamples, windowSamples.toLong())
        }
        lastSequence = frame.sequence
        lastFrameSampleCount = samples.size
        appendRolling(samples)
        observedSamples = Math.addExact(observedSamples, samples.size.toLong())
        if (rollingSampleCount < windowSamples || observedSamples < nextDecodeAtSamples) return
        nextDecodeAtSamples = Math.addExact(observedSamples, strideSamples.toLong())
        decodeWindow()
    }

    override fun onBacklog(
        queuedFrames: Int,
        droppedFrames: Long,
    ) {
        latestBacklogMilliseconds = queuedFrames.coerceAtLeast(0) * FRAME_MILLISECONDS
        if (droppedFrames > lastDroppedFrames) {
            lastDroppedFrames = droppedFrames
            emitDegraded("transcription_live_backlog", incomplete = true)
        }
    }

    override fun onFailure(code: String) {
        emitDegraded(safeLiveFailure(code), incomplete = true)
        close()
    }

    override fun degrade(code: String) {
        emitDegraded(safeLiveFailure(code), incomplete = true)
    }

    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        val run = runHandle
        if (run != 0L) runCatching { native.cancelRun(run) }
        if (!inFlight.get()) cleanupExecutor.execute { releaseNative() }
    }

    private fun decodeWindow() {
        if (!inFlight.compareAndSet(false, true)) return
        val context = contextHandle
        val run = runHandle
        val windowStartSamples = (observedSamples - rollingSampleCount).coerceAtLeast(0)
        val windowStartMilliseconds = windowStartSamples * 1_000L / sampleRateHz
        var resultHandle = 0L
        try {
            resultHandle = native.transcribePcm(
                context,
                run,
                rollingPcm.copyOf(),
                windowStartMilliseconds,
                languageHint,
            )
            if (closed.get()) return
            if (resultHandle == 0L) {
                emitDegraded(stableNativeFailure(), incomplete = true)
                close()
                return
            }
            val hypotheses =
                buildList {
                    repeat(native.segmentCount(resultHandle)) { index ->
                        val start = native.segmentStartMilliseconds(resultHandle, index).coerceAtLeast(0)
                        val end = native.segmentEndMilliseconds(resultHandle, index).coerceAtLeast(start)
                        val rawText = native.segmentText(resultHandle, index)
                        add(
                            DraftHypothesis(
                                startMilliseconds = start,
                                endMilliseconds = end,
                                rawText = rawText,
                                displayText = rawText.trim(),
                            ),
                        )
                    }
                }
            val windowEndMilliseconds =
                windowStartMilliseconds + rollingSampleCount * 1_000L / sampleRateHz
            val reconciliation = reconciler.reconcile(windowEndMilliseconds, hypotheses)
            reconciliation.segments.forEach { segment ->
                emit(
                    LiveDraftUpdated(
                        runId = runId,
                        segment = segment,
                        backlogMilliseconds = latestBacklogMilliseconds,
                    ),
                )
            }
        } catch (_: OutOfMemoryError) {
            emitDegraded("transcription_native_out_of_memory", incomplete = true)
            close()
        } catch (_: LinkageError) {
            emitDegraded("transcription_native_unavailable", incomplete = true)
            close()
        } catch (_: RuntimeException) {
            emitDegraded("transcription_native_failed", incomplete = true)
            close()
        } finally {
            if (resultHandle != 0L) runCatching { native.freeResult(resultHandle) }
            inFlight.set(false)
            if (closed.get()) releaseNative()
        }
    }

    private fun appendRolling(samples: ShortArray) {
        if (samples.size >= windowSamples) {
            samples.copyInto(
                destination = rollingPcm,
                startIndex = samples.size - windowSamples,
            )
            rollingSampleCount = windowSamples
            return
        }
        val overflow = (rollingSampleCount + samples.size - windowSamples).coerceAtLeast(0)
        if (overflow > 0) {
            rollingPcm.copyInto(
                destination = rollingPcm,
                startIndex = overflow,
                endIndex = rollingSampleCount,
                destinationOffset = 0,
            )
            rollingSampleCount -= overflow
        }
        samples.copyInto(rollingPcm, destinationOffset = rollingSampleCount)
        rollingSampleCount += samples.size
    }

    private fun decodeLittleEndianPcm(bytes: ByteArray): ShortArray {
        if (bytes.size % 2 != 0) {
            emitDegraded("transcription_live_pcm_invalid", incomplete = true)
            return ShortArray(0)
        }
        return ShortArray(bytes.size / 2) { index ->
            val low = bytes[index * 2].toInt() and 0xff
            val high = bytes[index * 2 + 1].toInt()
            ((high shl 8) or low).toShort()
        }
    }

    @Synchronized
    private fun releaseNative() {
        if (!nativeReleased.compareAndSet(false, true)) return
        val run = runHandle
        runHandle = 0
        if (run != 0L) runCatching { native.freeRun(run) }
        val context = contextHandle
        contextHandle = 0
        if (context != 0L) runCatching { native.freeContext(context) }
        inferenceLease?.close()
        inferenceLease = null
    }

    private fun failStart(code: String): LiveDraftStartResult.Failure {
        val safeCode = safeLiveFailure(code)
        emitDegraded(safeCode, incomplete = true)
        close()
        return LiveDraftStartResult.Failure(safeCode)
    }

    private fun emitDegraded(
        code: String,
        incomplete: Boolean,
    ) {
        emit(
            LiveDraftDegraded(
                runId = runId,
                code = safeLiveFailure(code),
                backlogMilliseconds = latestBacklogMilliseconds,
                incomplete = incomplete,
            ),
        )
    }

    private fun emit(event: LiveDraftRuntimeEvent) {
        runCatching { eventEmitter(event) }
    }

    private fun safeModelFailure(code: String): String =
        when (code) {
            "model_sha256_mismatch" -> "transcription_model_hash_mismatch"
            else -> safeLiveFailure(code)
        }

    private fun stableNativeFailure(): String = safeLiveFailure(native.lastErrorCode().orEmpty())

    private fun safeLiveFailure(code: String): String =
        code.takeIf(SAFE_FAILURE_CODES::contains) ?: "transcription_native_failed"

    private companion object {
        val cleanupWorker = Executors.newSingleThreadExecutor { task ->
            Thread(task, "loquiris-live-cleanup").apply { isDaemon = true }
        }
        const val DEFAULT_SAMPLE_RATE_HZ = 16_000
        const val DEFAULT_WINDOW_SAMPLES = DEFAULT_SAMPLE_RATE_HZ * 5
        const val DEFAULT_STRIDE_SAMPLES = DEFAULT_SAMPLE_RATE_HZ * 2
        const val DEFAULT_STABLE_HORIZON_MILLISECONDS = 2_000L
        const val FRAME_MILLISECONDS = 20L
        val SAFE_IDENTIFIER = Regex("[A-Za-z0-9._-]{1,128}")
        val SAFE_FAILURE_CODES =
            setOf(
                "transcription_live_backlog",
                "transcription_live_channel_closed",
                "transcription_live_closed",
                "transcription_live_consumer_failed",
                "transcription_live_engine_failed",
                "transcription_live_pcm_gap",
                "transcription_live_pcm_invalid",
                "transcription_live_recording_stopped",
                "transcription_live_replaced",
                "transcription_live_thermal",
                "transcription_model_directory_failed",
                "transcription_model_hash_mismatch",
                "transcription_model_load_failed",
                "transcription_model_manifest_invalid",
                "transcription_model_materialization_failed",
                "transcription_model_publish_failed",
                "transcription_native_failed",
                "transcription_native_inference_failed",
                "transcription_native_input_invalid",
                "transcription_native_invalid_handle",
                "transcription_native_out_of_memory",
                "transcription_native_unavailable",
            )
    }
}
