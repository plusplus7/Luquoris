package com.loquiris.transcription

import android.content.Context
import android.os.SystemClock
import com.loquiris.recording.*
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executors

/** Debug-only hardware composition. Never constructs a microphone source or writes recording files. */
internal class StreamingRecorderHardwareLease(
    private val context: Context,
    private val request: StreamingPlatformStart,
    private val identity: StreamingRemoteIdentity,
    private val events: (StreamingCaptureEvent) -> Unit,
    private val failure: (StreamingStopCause) -> Unit,
) {
    private val registry = LivePcmInferenceRegistry.process
    @Volatile private var binding: StreamingMessengerBinding? = null
    @Volatile private var consumer: StreamingPcmConsumer? = null
    private var adapter: PcmCaptureBoundaryConsumer? = null
    private var reservation: AutoCloseable? = null
    private var constructionUncertain = false // Start/release worker confined.
    private var watchdog: StreamingBacklogWatchdog? = null
    private var tickerWorker: java.util.concurrent.ScheduledExecutorService? = null

    val lease: StreamingPlatformLease = StreamingRecorderPlatformLease(registry,
        LiveDraftRequest(identity.runId, request.owner.meetingId, request.modelId, TranscriptionLanguageHint.mixed, request.parameterVersion),
        ::startRuntime, { checkNotNull(adapter) },
        { consumer?.closeAsync() ?: binding?.session?.closeRemote() },
        ::releaseRuntime, { code -> failure(when (code) {
            "transcription_live_thermal" -> StreamingStopCause.THERMAL
            "transcription_live_memory" -> StreamingStopCause.MEMORY
            else -> StreamingStopCause.ENGINE
        }) },
    )

    private fun startRuntime(cancelled: () -> Boolean): LiveDraftStartResult {
        val endpoint = registry.captureEndpoint(request.owner.meetingId)
            ?: return LiveDraftStartResult.Failure("transcription_live_recording_stopped")
        reservation = WhisperInferenceArbiter.process.acquireLive(cancelled)
            ?: return LiveDraftStartResult.Failure("transcription_live_busy")
        if (cancelled() || registry.captureEndpoint(request.owner.meetingId) !== endpoint) {
            return LiveDraftStartResult.Failure("transcription_live_closed")
        }
        val ready = CompletableFuture<StreamingStopCause?>()
        // If a constructor throws after retaining resources, never claim its release.
        constructionUncertain = true
        val remote = StreamingMessengerBinding(context, identity, request.bundleSha256,
            "com.loquiris.spike.StreamingNativeKernelProbeService",
            { cause -> ready.complete(cause); failure(cause) },
            { reply, _ -> if (reply is StreamingRemoteReply.Ready) ready.complete(null) })
        binding = remote
        constructionUncertain = false
        val pcm = StreamingPcmConsumer(remote.session, { batch -> batch.forEach(events) }, failure)
        consumer = pcm
        adapter = object : PcmCaptureBoundaryConsumer {
            override fun consume(frame: PcmCaptureFrame) = pcm.consume(frame)
            override fun onCaptureBoundary(boundary: PcmCaptureBoundary) = pcm.finishBoundary(when (boundary) {
                PcmCaptureBoundary.PAUSE -> StreamingBoundaryReason.PAUSE
                PcmCaptureBoundary.AUDIO_FOCUS -> StreamingBoundaryReason.AUDIO_FOCUS
                PcmCaptureBoundary.DISCONTINUITY -> StreamingBoundaryReason.DISCONTINUITY
                PcmCaptureBoundary.STOP -> StreamingBoundaryReason.STOP
            })
            override fun onBoundaryRejected(result: PcmInferenceBoundaryResult) { pcm.closeAsync() }
        }
        if (!remote.bindRemote()) return LiveDraftStartResult.Failure("transcription_live_engine_failed")
        val timer = Executors.newSingleThreadScheduledExecutor()
        tickerWorker = timer
        val backlog = StreamingBacklogWatchdog(16_000, endpoint::inferenceBacklog, pcm,
            ScheduledStreamingSecondTicker(timer, SystemClock::elapsedRealtime), { cause, _ -> failure(cause) })
        watchdog = backlog
        val startup = awaitStreamingRuntimeReady(ready, cancelled, backlog)
        if (startup is LiveDraftStartResult.Failure) return startup
        if (cancelled() || registry.captureEndpoint(request.owner.meetingId) !== endpoint) {
            return LiveDraftStartResult.Failure("transcription_live_closed")
        }
        return LiveDraftStartResult.Started
    }

    private fun releaseRuntime(): java.util.concurrent.CompletionStage<Unit> {
        watchdog?.closeAsync()
        tickerWorker?.shutdown()
        consumer?.closeAsync()?.toCompletableFuture()?.join()
        binding?.closeBinding()?.toCompletableFuture()?.join()
        check(!constructionUncertain) { "streaming_recorder_construction_release_unconfirmed" }
        // A timeout, local detach or worker STOP can never free the shared reservation.
        reservation?.close()
        return CompletableFuture.completedFuture(Unit)
    }
}
