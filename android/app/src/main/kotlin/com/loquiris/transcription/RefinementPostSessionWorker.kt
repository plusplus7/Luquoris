package com.loquiris.transcription

import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import java.io.File
import java.io.IOException

/** Validated frozen execution inputs; local catalog aliases never select weights. */
data class RefinementExecutionRequest(
    val meetingId: String,
    val audioInventorySha256: String,
    val engineVersion: String,
    val model: ModelArtifactSpec,
    val languageHint: TranscriptionLanguageHint,
)

sealed interface RefinementExecutionResult {
    data class Completed(val output: PostSessionTranscriptionResult.Completed) : RefinementExecutionResult
    data class Failure(val code: String) : RefinementExecutionResult
    data class Deferred(val code: String) : RefinementExecutionResult
    data object Cancelled : RefinementExecutionResult
}

/** Complete-pass execution core, independent of channels, capture callbacks, and persistence. */
class RefinementPostSessionWorker(
    private val inspect: (String, String) -> RefinementAudioInventoryResult,
    private val modelProvider: (ModelArtifactSpec) -> WhisperModelProvider,
    private val decoder: AacPcmDecoder,
    private val native: WhisperNativeApi,
    private val isRecordingActive: () -> Boolean,
    private val onRecordingStarted: (() -> Unit) -> AutoCloseable,
    snapshotDirectory: File,
    private val resourcePauseReason: () -> String? = { null },
    private val onResourcesPaused: ((String) -> Unit) -> AutoCloseable = { AutoCloseable {} },
) {
    private val snapshots = RefinementAudioSnapshotStore(snapshotDirectory)
    fun transcribe(
        request: RefinementExecutionRequest,
        cancellation: TranscriptionCancellation = TranscriptionCancellation(),
        onProgress: (Double) -> Unit = {},
    ): RefinementExecutionResult {
        if (cancellation.isCancelled()) return RefinementExecutionResult.Cancelled
        if (isRecordingActive()) return deferred()
        resourcePauseReason()?.let { return RefinementExecutionResult.Deferred(it) }
        val interruptedByCapture = AtomicBoolean()
        val resourceReason = AtomicReference<String?>()
        val execution = TranscriptionCancellation()
        val parent = cancellation.invokeOnCancel { signalCancellation(execution) }
        var capture: AutoCloseable? = null
        var resources: AutoCloseable? = null
        var snapshot: OwnedRefinementAudio? = null
        return try {
            capture = onRecordingStarted {
                interruptedByCapture.set(true)
                signalCancellation(execution)
            }
            try {
                resources = onResourcesPaused { reason ->
                    resourceReason.compareAndSet(null, reason)
                    signalCancellation(execution)
                }
            } catch (_: RuntimeException) {
                return RefinementExecutionResult.Deferred("refinement_resources_unavailable")
            }
            fun stopped(): RefinementExecutionResult? {
                if (isRecordingActive()) {
                    interruptedByCapture.set(true)
                    signalCancellation(execution)
                }
                resourcePauseReason()?.let { reason ->
                    resourceReason.compareAndSet(null, reason)
                    signalCancellation(execution)
                }
                return when {
                    interruptedByCapture.get() -> deferred()
                    resourceReason.get() != null -> RefinementExecutionResult.Deferred(checkNotNull(resourceReason.get()))
                    execution.isCancelled() -> RefinementExecutionResult.Cancelled
                    else -> null
                }
            }
            stopped()?.let { return it }
            if (native.engineVersion() != request.engineVersion) {
                return RefinementExecutionResult.Failure("refinement_runtime_mismatch")
            }
            val input = when (val inventory = inspect(request.meetingId, request.audioInventorySha256)) {
                is RefinementAudioInventoryResult.Ready -> inventory.audio
                else -> return inventoryFailure(inventory)
            }
            stopped()?.let { return it }
            snapshot = snapshots.create(input) { stopped() != null }
            // The strict reader authorizes one complete original inventory, never a prefix.
            // Require contiguous decode coverage even when a decoder reports success.
            val completeDecoder = AacPcmDecoder { source, emit ->
                var completedSamples = 0L
                var invalid = false
                val result = decoder.decode(source) { window ->
                    if (stopped() != null) return@decode false
                    if (window.samples.isEmpty() || window.startSample != completedSamples ||
                        window.samples.size.toLong() > source.totalSamples - completedSamples
                    ) {
                        invalid = true
                        return@decode false
                    }
                    val accepted = emit(window)
                    if (accepted) completedSamples += window.samples.size
                    accepted
                }
                when {
                    invalid -> AudioDecodeResult.Failure("refinement_audio_decode_incomplete")
                    result is AudioDecodeResult.Completed && completedSamples != source.totalSamples ->
                        AudioDecodeResult.Failure("refinement_audio_decode_incomplete")
                    else -> result
                }
            }
            val result = WhisperPostSessionEngine(
                AuthoritativeAudioProvider { checkNotNull(snapshot).audio }, modelProvider(request.model), completeDecoder, native,
            ).transcribe(request.meetingId, execution, request.languageHint) { progress ->
                if (stopped() == null) onProgress(progress)
            }
            stopped()?.let { return it }
            when (result) {
                PostSessionTranscriptionResult.Cancelled -> RefinementExecutionResult.Cancelled
                is PostSessionTranscriptionResult.Failure -> RefinementExecutionResult.Failure(result.code)
                is PostSessionTranscriptionResult.Completed -> {
                    if (result.engineVersion != request.engineVersion || result.warningCode != null) {
                        return RefinementExecutionResult.Failure("refinement_runtime_mismatch")
                    }
                    when (val verified = inspect(request.meetingId, request.audioInventorySha256)) {
                        is RefinementAudioInventoryResult.Ready -> {
                            stopped()?.let { return it }
                            RefinementExecutionResult.Completed(
                                result.copy(segments = result.segments.map { it.copy(displayText = it.rawText) }),
                            )
                        }
                        else -> inventoryFailure(verified)
                    }
                }
            }
        } catch (_: RefinementSnapshotCancelled) {
            when {
                interruptedByCapture.get() -> deferred()
                resourceReason.get() != null -> RefinementExecutionResult.Deferred(checkNotNull(resourceReason.get()))
                else -> RefinementExecutionResult.Cancelled
            }
        } catch (_: RefinementSnapshotInputChanged) {
            RefinementExecutionResult.Failure("refinement_audio_changed")
        } catch (_: RefinementSnapshotBusy) {
            RefinementExecutionResult.Deferred("refinement_worker_busy")
        } catch (_: IOException) {
            RefinementExecutionResult.Failure("refinement_snapshot_unavailable")
        } catch (_: OutOfMemoryError) {
            RefinementExecutionResult.Failure("transcription_native_out_of_memory")
        } catch (_: LinkageError) {
            RefinementExecutionResult.Failure("transcription_native_unavailable")
        } catch (_: RuntimeException) {
            RefinementExecutionResult.Failure("transcription_native_failed")
        } finally {
            var cleanupFailed = false
            try {
                snapshot?.close()
            } catch (_: Exception) {
                cleanupFailed = true
            }
            try {
                resources?.close()
            } catch (_: Throwable) {
                cleanupFailed = true
            }
            try {
                capture?.close()
            } catch (_: Exception) {
                cleanupFailed = true
            }
            try {
                parent.close()
            } catch (_: Exception) {
                cleanupFailed = true
            }
            if (cleanupFailed) return RefinementExecutionResult.Failure("refinement_cleanup_failed")
        }
    }

    private fun signalCancellation(cancellation: TranscriptionCancellation) {
        try {
            cancellation.cancel()
        } catch (_: Exception) {
            // Cancellation is already latched; native failures cannot escape onto capture.
        } catch (_: LinkageError) {
            // An unavailable optional native library must not prevent recording.
        } catch (_: OutOfMemoryError) {
            // Resource pressure may stop AI, never capture ownership.
        }
    }

    private fun inventoryFailure(result: RefinementAudioInventoryResult): RefinementExecutionResult = when (result) {
        is RefinementAudioInventoryResult.Failure -> RefinementExecutionResult.Failure(result.code)
        is RefinementAudioInventoryResult.Deferred -> RefinementExecutionResult.Deferred(result.code)
        RefinementAudioInventoryResult.Cancelled -> RefinementExecutionResult.Cancelled
        is RefinementAudioInventoryResult.Ready -> error("ready inventory is not a failure")
    }

    private fun deferred() = RefinementExecutionResult.Deferred("refinement_recording_active")
}
