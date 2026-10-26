package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame
import com.loquiris.recording.PcmInferenceConsumer
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CompletionStage

private class StreamingConsumerStage(private val root: CompletableFuture<Unit>) : CompletionStage<Unit> by root {
    override fun toCompletableFuture(): CompletableFuture<Unit> = root.thenApply { it }
}

/**
 * Worker-only PCM/finish operations; closure is independently nonblocking.
 * Callbacks may request closure, but must not wait for this owner's release ACK:
 * that ACK intentionally waits for their own publication lease to finish.
 */
class StreamingPcmConsumer(
    private val remote: StreamingRemoteSession,
    private val onEvents: (List<StreamingCaptureEvent>) -> Unit,
    private val onDegraded: (StreamingStopCause) -> Unit = {},
) : PcmInferenceConsumer, StreamingReleaseOwner {
    private val workLock = Any()
    private val stateLock = Any()
    private val timeline = StreamingCaptureTimeline(remote.ownerIdentity)
    private val release = CompletableFuture<Unit>()
    private val releaseStage = StreamingConsumerStage(release)
    private var stopped = false
    private var remoteReleased = false
    private var publications = 0
    private var previousEnd: Long? = null
    private var previousEpoch: Long? = null
    @Volatile var stopCause: StreamingStopCause? = null
        private set

    /** Never call from microphone or UI callbacks: waits for matching inference ACK. */
    override fun consume(frame: PcmCaptureFrame): Unit = synchronized(workLock) {
        if (synchronized(stateLock) { stopped }) return
        try {
            val start = frame.canonicalStartSample
            val end = frame.canonicalEndSampleExclusive
            val priorEnd = previousEnd
            val priorEpoch = previousEpoch
            if (start == null || end == null || end - start !in 1..16000L ||
                priorEnd != null && (start < priorEnd || frame.captureEpoch < requireNotNull(priorEpoch))) {
                degrade(StreamingStopCause.INVALID_PCM)
                return
            }
            if (priorEnd != null && (start != priorEnd || frame.captureEpoch != priorEpoch)) {
                finishInternal(StreamingBoundaryReason.DISCONTINUITY)
            }
            if (synchronized(stateLock) { stopped }) return
            val result = awaitResult(remote.submitRemote(frame)) ?: return
            if (synchronized(stateLock) { stopped }) return
            val events = timeline.accept(frame, result)
            previousEnd = end
            previousEpoch = frame.captureEpoch
            publish(events)
        } catch (_: OutOfMemoryError) { degrade(StreamingStopCause.MEMORY) }
        catch (_: Throwable) { degrade(StreamingStopCause.ENGINE) }
        Unit
    }

    /** Queue on the same worker as consume; STOP flushes, whereas close cancels. */
    fun finishBoundary(reason: StreamingBoundaryReason) = synchronized(workLock) {
        try { finishInternal(reason) }
        catch (_: OutOfMemoryError) { degrade(StreamingStopCause.MEMORY) }
        catch (_: Throwable) { degrade(StreamingStopCause.ENGINE) }
        Unit
    }

    private fun finishInternal(reason: StreamingBoundaryReason) {
        if (synchronized(stateLock) { stopped }) return
        val result = awaitResult(remote.finishRemoteUtterance()) ?: return
        if (synchronized(stateLock) { stopped }) return
        publish(timeline.finishBoundary(result, reason))
        if (reason == StreamingBoundaryReason.STOP) closeAsync()
    }

    private fun awaitResult(stage: CompletionStage<StreamingRemoteResult>?): StreamingRemoteResult.Text? {
        if (stage == null) {
            degrade(StreamingStopCause.ENGINE)
            return null
        }
        // No timeout, cancellation or interrupt can pretend native work settled.
        return when (val result = stage.toCompletableFuture().join()) {
            is StreamingRemoteResult.Text -> result
            is StreamingRemoteResult.Failed -> { degrade(result.cause); null }
            StreamingRemoteResult.Cancelled -> { closeAsync(); null }
        }
    }

    private fun publish(events: List<StreamingCaptureEvent>) {
        if (events.isEmpty()) return
        synchronized(stateLock) {
            if (stopped) return
            publications++
        }
        try { onEvents(events) } finally { endPublication() }
    }

    /** First failure wins. Notification failure cannot strand native resources. */
    fun degrade(cause: StreamingStopCause): CompletionStage<Unit> {
        synchronized(stateLock) {
            if (stopped) return releaseStage
            stopped = true
            stopCause = cause
            publications++
        }
        requestRelease()
        try { runCatching { onDegraded(cause) } } finally { endPublication() }
        return releaseStage
    }

    /** Does not acquire the inference/publication lock or wait for either. */
    override fun closeAsync(): CompletionStage<Unit> {
        synchronized(stateLock) {
            if (stopped) return releaseStage
            stopped = true
        }
        requestRelease()
        return releaseStage
    }

    private fun requestRelease() {
        remote.closeRemote().whenComplete { _, failure ->
            if (failure != null) release.completeExceptionally(failure)
            else {
                val complete = synchronized(stateLock) {
                    remoteReleased = true
                    publications == 0
                }
                if (complete) release.complete(Unit)
            }
        }
    }

    private fun endPublication() {
        val complete = synchronized(stateLock) {
            publications--
            stopped && remoteReleased && publications == 0
        }
        if (complete) release.complete(Unit)
    }
}
