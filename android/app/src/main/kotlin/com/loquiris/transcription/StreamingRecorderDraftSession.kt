package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureBoundary
import com.loquiris.recording.PcmCaptureBoundaryConsumer
import com.loquiris.recording.PcmCaptureFrame
import com.loquiris.recording.PcmInferenceBoundaryResult
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CompletionStage

/** Recorder-registry adapter. Construction never allocates native state or capture. */
class StreamingRecorderDraftSession(
    private val startRuntime: () -> LiveDraftStartResult,
    private val input: () -> PcmCaptureBoundaryConsumer,
    private val cancelRuntime: () -> Unit,
    private val onDegraded: (String) -> Unit,
) : LiveDraftSession, PcmCaptureBoundaryConsumer {
    private val lock = Any()
    private val stopped = CompletableFuture<PcmInferenceBoundaryResult>()
    private var closed = false
    private var terminalCompleted = false
    private var degraded = false

    /** Worker completion/cancellation only, not a native release acknowledgement. */
    val stopResult: CompletionStage<PcmInferenceBoundaryResult>
        get() = RecorderSessionStage(stopped)

    override fun start(): LiveDraftStartResult {
        if (synchronized(lock) { closed }) return LiveDraftStartResult.Failure("transcription_live_closed")
        val result = startRuntime()
        return if (synchronized(lock) { closed }) LiveDraftStartResult.Failure("transcription_live_closed") else result
    }

    override fun consume(frame: PcmCaptureFrame) {
        if (synchronized(lock) { closed || terminalCompleted }) return
        input().consume(frame)
    }

    override fun onCaptureBoundary(boundary: PcmCaptureBoundary) {
        if (synchronized(lock) { closed || terminalCompleted }) return
        input().onCaptureBoundary(boundary)
        if (boundary == PcmCaptureBoundary.STOP) {
            val result = synchronized(lock) {
                terminalCompleted = true
                if (closed) PcmInferenceBoundaryResult.closed else PcmInferenceBoundaryResult.completed
            }
            stopped.complete(result)
        }
    }

    override fun onBoundaryRejected(result: PcmInferenceBoundaryResult) {
        when (result) {
            PcmInferenceBoundaryResult.completed -> Unit
            PcmInferenceBoundaryResult.failed, PcmInferenceBoundaryResult.queueFull -> degrade("transcription_live_boundary_failed")
            PcmInferenceBoundaryResult.closed, PcmInferenceBoundaryResult.detached -> close()
        }
    }

    override fun onFailure(code: String) = degrade(code)

    override fun degrade(code: String) {
        val first = synchronized(lock) { if (degraded) false else { degraded = true; true } }
        try { if (first) onDegraded(code) } finally { close() }
    }

    /** Must not wait for worker/native ACK; callbacks may invoke this reentrantly. */
    override fun close() {
        val first = synchronized(lock) { if (closed) false else { closed = true; true } }
        if (!first) return
        try { cancelRuntime() } finally { stopped.complete(PcmInferenceBoundaryResult.closed) }
    }
}

private class RecorderSessionStage<T>(private val root: CompletableFuture<T>) : CompletionStage<T> by root {
    override fun toCompletableFuture(): CompletableFuture<T> = root.thenApply { it }
}
