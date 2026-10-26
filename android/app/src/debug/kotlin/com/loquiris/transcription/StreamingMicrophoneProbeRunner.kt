package com.loquiris.transcription

import com.loquiris.recording.PcmInferenceConsumer
import com.loquiris.recording.RecordingCapturePipeline
import com.loquiris.recording.RecordingCapturePipelineSnapshot
import com.loquiris.recording.RecordingCapturePipelineState
import com.loquiris.recording.RecordingCaptureCommandResult
import java.util.concurrent.CompletionStage

internal enum class StreamingMicrophoneProbeStatus { COMPLETED, CANCELLED, FAILED }
internal data class StreamingMicrophoneProbeReport(
    val status: StreamingMicrophoneProbeStatus,
    val capture: RecordingCapturePipelineSnapshot?,
    val failure: StreamingStopCause?,
    val controlsMs: List<Long>,
    val cleanupFailed: Boolean,
    val resourcesReleased: Boolean,
)

/** Runs only on a dedicated worker. Factories clean partial construction themselves. */
internal class StreamingMicrophoneProbeRunner(
    private val createCapture: () -> RecordingCapturePipeline,
    private val consumer: PcmInferenceConsumer,
    private val finishBoundary: (StreamingBoundaryReason) -> Unit,
    private val releaseInference: () -> CompletionStage<Unit>,
    private val waitWindow: (Long) -> Boolean,
    private val isCancelled: () -> Boolean = { false },
    private val isStopRequested: () -> Boolean = { false },
    private val nowMs: () -> Long = { System.nanoTime() / 1_000_000 },
) {
    fun run(): StreamingMicrophoneProbeReport {
        var capture: RecordingCapturePipeline? = null
        var status = StreamingMicrophoneProbeStatus.COMPLETED
        var failure: StreamingStopCause? = null
        var cleanupFailed = false
        var captureReleased = false
        var inferenceReleased = false
        val controls = mutableListOf<Long>()
        try {
          run captureRun@{
            if (isCancelled()) throw ProbeCaptureCancelled()
            if (isStopRequested()) return@captureRun
            val active = createCapture()
            capture = active
            if (isCancelled()) throw ProbeCaptureCancelled()
            if (isStopRequested()) return@captureRun
            active.replaceInferenceConsumer(consumer)
            check(active.start() is RecordingCaptureCommandResult.Success)
            val firstWindowElapsed = waitWindow(10000)
            if (isCancelled() || (!firstWindowElapsed && !isStopRequested())) throw ProbeCaptureCancelled()
            var before = nowMs()
            check(active.pause() is RecordingCaptureCommandResult.Success)
            controls.add(nowMs() - before)
            awaitDrain(active)
            if (isCancelled()) throw ProbeCaptureCancelled()
            if (isStopRequested()) {
                finishBoundary(StreamingBoundaryReason.STOP)
                return@captureRun
            }
            finishBoundary(StreamingBoundaryReason.PAUSE)
            val pausedBytes = active.snapshot().bytesWritten
            val pauseWindowElapsed = waitWindow(1000)
            if (isCancelled() || (!pauseWindowElapsed && !isStopRequested())) throw ProbeCaptureCancelled()
            if (isStopRequested()) return@captureRun
            check(active.snapshot().bytesWritten == pausedBytes)
            before = nowMs()
            check(active.resume() is RecordingCaptureCommandResult.Success)
            controls.add(nowMs() - before)
            val finalWindowElapsed = waitWindow(10000)
            if (isCancelled() || (!finalWindowElapsed && !isStopRequested())) throw ProbeCaptureCancelled()
            check(active.pause() is RecordingCaptureCommandResult.Success)
            awaitDrain(active)
            if (isCancelled()) throw ProbeCaptureCancelled()
            finishBoundary(StreamingBoundaryReason.STOP)
          }
        } catch (_: ProbeCaptureCancelled) { status = StreamingMicrophoneProbeStatus.CANCELLED }
        catch (problem: Throwable) {
            status = StreamingMicrophoneProbeStatus.FAILED
            failure = if (problem is OutOfMemoryError) StreamingStopCause.MEMORY else StreamingStopCause.ENGINE
        } finally {
            // Request release even if capture cleanup later throws. Never wait on
            // this stage until the microphone has independently been stopped.
            var acknowledgement: CompletionStage<Unit>? = null
            try { acknowledgement = releaseInference() }
            catch (problem: Throwable) {
                cleanupFailed = true
                if (failure == null) failure = if (problem is OutOfMemoryError) StreamingStopCause.MEMORY else StreamingStopCause.ENGINE
            }
            try {
                val active = capture
                if (active == null) captureReleased = true // Factory owns partial construction.
                else if (active.snapshot().state == RecordingCapturePipelineState.idle) {
                    active.close()
                    captureReleased = true
                }
                else {
                    val result = active.finish()
                    captureReleased = result is RecordingCaptureCommandResult.Success
                    if (!captureReleased) cleanupFailed = true
                }
            } catch (problem: Throwable) {
                cleanupFailed = true
                if (failure == null) failure = if (problem is OutOfMemoryError) StreamingStopCause.MEMORY else StreamingStopCause.ENGINE
            }
            // Independent abort still runs if finalization failed or threw.
            try { capture?.close() }
            catch (problem: Throwable) {
                cleanupFailed = true
                captureReleased = false
                if (failure == null) failure = if (problem is OutOfMemoryError) StreamingStopCause.MEMORY else StreamingStopCause.ENGINE
            }
            try {
                acknowledgement?.toCompletableFuture()?.join()
                inferenceReleased = acknowledgement != null
            } catch (problem: Throwable) {
                cleanupFailed = true
                var cause = problem
                repeat(16) {
                    if (cause is java.util.concurrent.CompletionException || cause is java.util.concurrent.ExecutionException) {
                        cause.cause?.let { cause = it }
                    }
                }
                if (failure == null) failure = if (cause is OutOfMemoryError) StreamingStopCause.MEMORY else StreamingStopCause.ENGINE
            }
            if (cleanupFailed) {
                status = StreamingMicrophoneProbeStatus.FAILED
                if (failure == null) failure = StreamingStopCause.ENGINE
            }
        }
        return StreamingMicrophoneProbeReport(status, capture?.snapshot(), failure,
            controls.toList(), cleanupFailed, captureReleased && inferenceReleased)
    }

    private fun awaitDrain(capture: RecordingCapturePipeline) {
        val deadline = nowMs() + 5000
        while (nowMs() < deadline) {
            if (isCancelled()) throw ProbeCaptureCancelled()
            val snapshot = capture.snapshot()
            check(snapshot.state == RecordingCapturePipelineState.paused)
            val metrics = snapshot.fanOut
            if (metrics.canonicalProcessedFrames == metrics.canonicalAcceptedFrames &&
                metrics.inferenceProcessedFrames + metrics.inferenceDroppedFrames == metrics.inferenceAcceptedFrames) return
            Thread.sleep(10)
        }
        error("streaming_capture_drain_unsettled") // A timeout is failure, never release proof.
    }
}

private class ProbeCaptureCancelled : RuntimeException()
