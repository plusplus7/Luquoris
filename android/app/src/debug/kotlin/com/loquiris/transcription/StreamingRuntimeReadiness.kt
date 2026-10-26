package com.loquiris.transcription

import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/** Worker-only readiness wait. The lease owns watchdog cancellation and real release acknowledgement. */
internal fun awaitStreamingRuntimeReady(
    ready: CompletableFuture<StreamingStopCause?>,
    cancelled: () -> Boolean,
    watchdog: StreamingBacklogWatchdog,
): LiveDraftStartResult {
    if (cancelled()) return LiveDraftStartResult.Failure("transcription_live_closed")
    // Readiness/model loading is part of live backlog, not an exemption from it.
    watchdog.start()
    while (true) {
        if (cancelled()) return LiveDraftStartResult.Failure("transcription_live_closed")
        try {
            val cause = ready.get(50, TimeUnit.MILLISECONDS)
            if (cause != null) return LiveDraftStartResult.Failure(when (cause) {
                StreamingStopCause.MEMORY -> "transcription_live_memory"
                StreamingStopCause.THERMAL -> "transcription_live_thermal"
                StreamingStopCause.MODEL_UNAVAILABLE -> "transcription_model_unavailable"
                else -> "transcription_live_engine_failed"
            })
            return LiveDraftStartResult.Started
        } catch (_: TimeoutException) { /* Cancellation never substitutes for a release ACK. */ }
    }
}
