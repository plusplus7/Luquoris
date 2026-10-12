package com.loquiris.transcription

class WhisperPostSessionEngine(
    private val audioProvider: AuthoritativeAudioProvider,
    private val modelProvider: WhisperModelProvider,
    private val decoder: AacPcmDecoder,
    private val native: WhisperNativeApi,
    private val arbiter: WhisperInferenceArbiter = WhisperInferenceArbiter.process,
) {
    fun transcribe(
        meetingId: String,
        cancellation: TranscriptionCancellation = TranscriptionCancellation(),
        languageHint: TranscriptionLanguageHint = TranscriptionLanguageHint.mixed,
        onProgress: (Double) -> Unit = {},
    ): PostSessionTranscriptionResult {
        if (cancellation.isCancelled()) return PostSessionTranscriptionResult.Cancelled
        var warningCode: String? = null
        val audio =
            when (val resolved = audioProvider.resolve(meetingId)) {
                is AuthoritativeAudioResolution.Ready -> resolved
                is AuthoritativeAudioResolution.Partial -> {
                    if (resolved.segments.isEmpty() || resolved.totalSamples <= 0) {
                        return failure(resolved.code)
                    }
                    warningCode = resolved.code
                    AuthoritativeAudioResolution.Ready(
                        segments = resolved.segments,
                        totalSamples = resolved.totalSamples,
                        sampleRateHz = resolved.sampleRateHz,
                        codecSpecificData = resolved.codecSpecificData,
                    )
                }
                is AuthoritativeAudioResolution.Failure -> return failure(resolved.code)
            }
        val model =
            when (val materialized = modelProvider.materialize()) {
                is ModelMaterializationResult.Ready -> materialized.file
                is ModelMaterializationResult.Failure -> return failure(materialized.code)
            }
        val context =
            try {
                native.createContext(model.absolutePath)
            } catch (_: OutOfMemoryError) {
                return failure("transcription_native_out_of_memory")
            } catch (_: LinkageError) {
                return failure("transcription_native_unavailable")
            } catch (_: RuntimeException) {
                return failure("transcription_native_failed")
            }
        if (context == 0L) return failure(stableNativeFailure())
        var run = 0L
        return try {
            run = native.createRun()
            if (run == 0L) return failure(stableNativeFailure())
            val cancelRegistration = cancellation.invokeOnCancel { native.cancelRun(run) }
            try {
                transcribeDecodedAudio(
                    audio,
                    context,
                    run,
                    cancellation,
                    warningCode,
                    languageHint,
                    onProgress,
                )
            } finally {
                cancelRegistration.close()
            }
        } catch (_: OutOfMemoryError) {
            failure("transcription_native_out_of_memory")
        } catch (_: LinkageError) {
            failure("transcription_native_unavailable")
        } catch (_: RuntimeException) {
            failure("transcription_native_failed")
        } finally {
            if (run != 0L) native.freeRun(run)
            native.freeContext(context)
        }
    }

    private fun transcribeDecodedAudio(
        audio: AuthoritativeAudioResolution.Ready,
        context: Long,
        run: Long,
        cancellation: TranscriptionCancellation,
        warningCode: String?,
        languageHint: TranscriptionLanguageHint,
        onProgress: (Double) -> Unit,
    ): PostSessionTranscriptionResult {
        val segments = mutableListOf<TranscriptionSegment>()
        var previousEnd = 0L
        var nativeFailureCode: String? = null
        val decodeResult =
            decoder.decode(audio) { window ->
                if (cancellation.isCancelled()) return@decode false
                val windowStartMilliseconds = window.startSample * 1_000L / audio.sampleRateHz
                val lease = arbiter.acquirePostSession(cancellation::isCancelled) ?: return@decode false
                val result = lease.use {
                    native.transcribePcm(
                        context,
                        run,
                        window.samples,
                        windowStartMilliseconds,
                        languageHint,
                    )
                }
                if (result == 0L) {
                    nativeFailureCode = stableNativeFailure()
                    return@decode false
                }
                try {
                    repeat(native.segmentCount(result)) { index ->
                        val rawStart = native.segmentStartMilliseconds(result, index)
                        val rawEnd = native.segmentEndMilliseconds(result, index)
                        val start = maxOf(previousEnd, rawStart)
                        val end = maxOf(start, rawEnd)
                        val rawText = native.segmentText(result, index)
                        segments +=
                            TranscriptionSegment(
                                id = "segment-${segments.size.toString().padStart(6, '0')}",
                                startMilliseconds = start,
                                endMilliseconds = end,
                                rawText = rawText,
                                displayText = rawText.trim(),
                            )
                        previousEnd = end
                    }
                } finally {
                    native.freeResult(result)
                }
                val completedSamples = window.startSample + window.samples.size
                onProgress((completedSamples.toDouble() / audio.totalSamples).coerceIn(0.0, 1.0))
                !cancellation.isCancelled()
            }
        if (cancellation.isCancelled() || decodeResult is AudioDecodeResult.Cancelled) {
            if (nativeFailureCode != null && nativeFailureCode != "transcription_cancelled") {
                return failure(checkNotNull(nativeFailureCode))
            }
            return PostSessionTranscriptionResult.Cancelled
        }
        nativeFailureCode?.let { code -> return failure(code) }
        if (decodeResult is AudioDecodeResult.Failure) return failure(decodeResult.code)
        onProgress(1.0)
        return PostSessionTranscriptionResult.Completed(
            engineVersion = native.engineVersion(),
            segments = segments,
            warningCode = warningCode,
        )
    }

    private fun stableNativeFailure(): String =
        native.lastErrorCode().takeIf { it in SAFE_NATIVE_FAILURE_CODES } ?: "transcription_native_failed"

    private fun failure(code: String) = PostSessionTranscriptionResult.Failure(code)

    private companion object {
        val SAFE_NATIVE_FAILURE_CODES =
            setOf(
                "transcription_cancelled",
                "transcription_model_load_failed",
                "transcription_native_out_of_memory",
                "transcription_native_unavailable",
                "transcription_native_invalid_handle",
                "transcription_native_inference_failed",
                "transcription_native_input_invalid",
            )
    }
}
