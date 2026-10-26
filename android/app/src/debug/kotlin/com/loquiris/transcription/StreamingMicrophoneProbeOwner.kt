package com.loquiris.transcription

import java.util.concurrent.CompletableFuture
import java.util.concurrent.CompletionStage
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** Worker-owned diagnostic capture; all supplied callbacks are non-UI work. */
internal class StreamingMicrophoneProbeOwner(
    private val startRemote: ((StreamingStopCause?) -> Unit) -> Unit,
    private val runProbe: ((Long) -> Boolean, () -> Boolean, () -> Boolean) -> StreamingMicrophoneProbeReport,
    private val closeInference: () -> CompletionStage<Unit>,
    private val closeRemote: () -> CompletionStage<Unit>,
    private val onReport: (StreamingMicrophoneProbeReport) -> Unit,
    private val onFailure: (StreamingStopCause) -> Unit,
) : StreamingPlatformLease {
    private val lock = Any()
    private val worker = Executors.newSingleThreadExecutor()
    private val wake = CountDownLatch(1)
    private val ready = CompletableFuture<StreamingStopCause?>()
    private val released = CompletableFuture<Unit>()
    @Volatile private var closing: StreamingPlatformCloseReason? = null
    private var started = false
    private var captureReleaseUncertain = false // Worker confined.

    override fun start(): CompletionStage<StreamingStopCause?> {
        synchronized(lock) {
            if (!started && closing == null) {
                started = true
                worker.execute {
                    try { startRemote(::remoteReady) }
                    catch (problem: Throwable) { remoteReady(if (problem is OutOfMemoryError) StreamingStopCause.MEMORY else StreamingStopCause.ENGINE) }
                }
            }
        }
        return MicrophoneOwnerStage(ready)
    }

    private fun remoteReady(cause: StreamingStopCause?) {
        synchronized(lock) {
            if (closing != null || ready.isDone) return
            // Queue capture before exposing readiness; close is queued after it.
            if (cause == null) worker.execute {
                try {
                    val report = runProbe({ millis -> !wake.await(millis, TimeUnit.MILLISECONDS) },
                        { closing != null && closing != StreamingPlatformCloseReason.STOPPED },
                        { closing == StreamingPlatformCloseReason.STOPPED })
                    captureReleaseUncertain = !report.resourcesReleased
                    onReport(report)
                    report.failure?.let(onFailure)
                } catch (problem: Throwable) {
                    captureReleaseUncertain = true
                    onFailure(if (problem is OutOfMemoryError) StreamingStopCause.MEMORY else StreamingStopCause.ENGINE)
                }
            }
            ready.complete(cause)
            if (cause != null) onFailure(cause)
        }
    }

    override fun close(reason: StreamingPlatformCloseReason): CompletionStage<Unit> {
        synchronized(lock) {
            if (closing == StreamingPlatformCloseReason.STOPPED && reason != StreamingPlatformCloseReason.STOPPED) {
                closing = reason
                try { closeInference() } catch (_: Throwable) { /* Independent queued cleanup still owns the ACK. */ }
            }
            if (closing == null) {
                closing = reason
                wake.countDown()
                ready.complete(StreamingStopCause.ENGINE)
                // Nonblocking request can interrupt an in-flight PCM call; STOP
                // instead lets the worker drain and explicitly finish first.
                if (reason != StreamingPlatformCloseReason.STOPPED) {
                    try { closeInference() } catch (_: Throwable) { /* Retry independently below. */ }
                }
                worker.execute {
                    var problem: Throwable? = null
                    try { closeInference().toCompletableFuture().join() }
                    catch (failure: Throwable) { problem = failure }
                    try { closeRemote().toCompletableFuture().join() }
                    catch (failure: Throwable) { if (problem == null) problem = failure else problem.addSuppressed(failure) }
                    if (captureReleaseUncertain && problem == null) problem = IllegalStateException("streaming_capture_release_unconfirmed")
                    if (problem == null) released.complete(Unit) else released.completeExceptionally(problem)
                    worker.shutdown()
                }
            }
        }
        return MicrophoneOwnerStage(released)
    }
}

private class MicrophoneOwnerStage<T>(private val root: CompletableFuture<T>) : CompletionStage<T> by root {
    override fun toCompletableFuture(): CompletableFuture<T> = root.thenApply { it }
}
