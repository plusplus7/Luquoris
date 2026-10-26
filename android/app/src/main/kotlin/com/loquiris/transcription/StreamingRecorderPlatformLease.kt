package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureBoundaryConsumer
import com.loquiris.recording.PcmInferenceBoundaryResult
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CompletionStage
import java.util.concurrent.Executors

/** Owns recognizer work only; uses the existing recorder's registry binding. */
class StreamingRecorderPlatformLease(
    private val registry: LivePcmInferenceRegistry,
    private val request: LiveDraftRequest,
    private val startRuntime: (() -> Boolean) -> LiveDraftStartResult,
    private val input: () -> PcmCaptureBoundaryConsumer,
    private val cancelRuntime: () -> Unit,
    private val releaseRuntime: () -> CompletionStage<Unit>,
    private val onDegraded: (String) -> Unit,
) : StreamingPlatformLease {
    private val lock = Any()
    private val worker = Executors.newSingleThreadExecutor()
    private val ready = CompletableFuture<StreamingStopCause?>()
    private val released = CompletableFuture<Unit>()
    @Volatile private var closing: StreamingPlatformCloseReason? = null
    private var started = false
    private var attached = false // Worker confined.
    private val session = StreamingRecorderDraftSession(
        { startRuntime { closing != null || registry.pendingCancellationCode(request.runId) != null } },
        input, cancelRuntime,
        { code -> try { onDegraded(code) } finally { close(StreamingPlatformCloseReason.CANCELLED) } },
    )

    init {
        session.stopResult.whenComplete { result, _ ->
            close(if (result == PcmInferenceBoundaryResult.completed) StreamingPlatformCloseReason.STOPPED
                else StreamingPlatformCloseReason.CANCELLED)
        }
    }

    override fun start(): CompletionStage<StreamingStopCause?> {
        synchronized(lock) {
            if (!started && closing == null) {
                started = true
                worker.execute {
                    try {
                        val endpoint = registry.captureEndpoint(request.meetingId)
                        val result = if (endpoint == null) {
                            LiveDraftStartResult.Failure("transcription_live_recording_stopped")
                        } else registry.start(request, endpoint) { session }
                        attached = result == LiveDraftStartResult.Started && registry.isDraftSession(request.runId, session)
                        val cause = (result as? LiveDraftStartResult.Failure)?.code?.let(::failureCause)
                            ?: if (attached && closing == null) null else StreamingStopCause.ENGINE
                        ready.complete(cause)
                        if (!attached) close(StreamingPlatformCloseReason.CANCELLED)
                    } catch (problem: Throwable) {
                        ready.complete(if (problem is OutOfMemoryError) StreamingStopCause.MEMORY else StreamingStopCause.ENGINE)
                        close(StreamingPlatformCloseReason.CANCELLED)
                    }
                }
            }
        }
        return RecorderLeaseStage(ready)
    }

    override fun close(reason: StreamingPlatformCloseReason): CompletionStage<Unit> {
        val cancel = synchronized(lock) {
            val first = closing == null
            val upgrade = closing == StreamingPlatformCloseReason.STOPPED && reason != StreamingPlatformCloseReason.STOPPED
            if (first || upgrade) closing = reason
            if (first) {
                // A pending registry.start owns its typed result. Its session
                // may close synchronously before registry.start returns it.
                if (!started) ready.complete(StreamingStopCause.ENGINE)
                worker.execute(::releaseOnWorker)
            }
            (first || upgrade) && reason != StreamingPlatformCloseReason.STOPPED
        }
        if (cancel) runCatching { session.close() }
        return RecorderLeaseStage(released)
    }

    private fun releaseOnWorker() {
        var problem: Throwable? = null
        try {
            if (closing == StreamingPlatformCloseReason.STOPPED && attached) {
                if (!registry.finishDraftAtCaptureBoundary(request.runId, session)) session.close()
                session.stopResult.toCompletableFuture().join()
            }
        } catch (failure: Throwable) { problem = failure }
        try { registry.stopDraft(request.runId, session); session.close() }
        catch (failure: Throwable) { if (problem == null) problem = failure else problem.addSuppressed(failure) }
        try { releaseRuntime().toCompletableFuture().join() }
        catch (failure: Throwable) { if (problem == null) problem = failure else problem.addSuppressed(failure) }
        if (problem == null) released.complete(Unit) else released.completeExceptionally(problem)
        worker.shutdown()
    }

    private fun failureCause(code: String): StreamingStopCause = when (code) {
        "transcription_live_thermal" -> StreamingStopCause.THERMAL
        "transcription_live_memory" -> StreamingStopCause.MEMORY
        "transcription_model_unavailable" -> StreamingStopCause.MODEL_UNAVAILABLE
        else -> StreamingStopCause.ENGINE
    }
}

private class RecorderLeaseStage<T>(private val root: CompletableFuture<T>) : CompletionStage<T> by root {
    override fun toCompletableFuture(): CompletableFuture<T> = root.thenApply { it }
}
