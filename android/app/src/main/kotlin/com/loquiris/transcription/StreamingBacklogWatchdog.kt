package com.loquiris.transcription

import com.loquiris.recording.PcmInferenceBacklog
import java.util.concurrent.CompletionStage
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

enum class StreamingStopCause { BACKLOG, INVALID_PCM, MEMORY, THERMAL, ENGINE, MODEL_UNAVAILABLE }

/** Subscribe/cancel must be nonblocking; observations are independent of inference. */
fun interface StreamingSecondTicker {
    fun subscribe(observe: (Long) -> Unit): AutoCloseable
}

/** The caller owns an inference-independent executor and a nonthrowing monotonic clock. */
class ScheduledStreamingSecondTicker(private val executor: ScheduledExecutorService, private val nowMs: () -> Long) : StreamingSecondTicker {
    override fun subscribe(observe: (Long) -> Unit): AutoCloseable {
        // A fixed-rate timer can jitter from 1001ms to 2000ms: the latter is
        // correctly too early for a second independent observation. Delay from
        // completion instead, guaranteeing a full second and no catch-up burst.
        val task = executor.scheduleWithFixedDelay({ observe(nowMs()) }, 1, 1, TimeUnit.SECONDS)
        return AutoCloseable { task.cancel(false) }
    }
}

/**
 * One owner-scoped observer. Closure cancels observation and requests asynchronous
 * release without waiting for native work or a snapshot already being sampled.
 * The adapter owns event/run filtering and executor shutdown after acknowledgement.
 */
class StreamingBacklogWatchdog(
    sampleRate: Int,
    private val snapshot: () -> PcmInferenceBacklog,
    private val owner: StreamingReleaseOwner,
    private val ticker: StreamingSecondTicker,
    private val onDegraded: (StreamingStopCause, CompletionStage<Unit>) -> Unit = { _, _ -> },
) {
    private val guard = StreamingBacklogGuard(sampleRate)
    private val observationLock = Any()
    private val started = AtomicBoolean()
    private val stopped = AtomicBoolean()
    private val registration = AtomicReference<AutoCloseable?>()
    @Volatile var stopCause: StreamingStopCause? = null
        private set
    @Volatile var latestObservation: StreamingBacklogDecision? = null
        private set

    fun start() {
        if (stopped.get() || !started.compareAndSet(false, true)) return
        try {
            val subscription = ticker.subscribe(::observe)
            registration.set(subscription)
            // close/degrade may win even while subscribe is returning.
            if (stopped.get()) cancelObservation()
        } catch (failure: Throwable) {
            degrade(if (failure is OutOfMemoryError) StreamingStopCause.MEMORY else StreamingStopCause.ENGINE)
        }
    }

    private fun observe(nowMs: Long) {
        if (stopped.get()) return
        val cause = synchronized(observationLock) {
            if (stopped.get()) return
            try {
                val decision = guard.observeBacklog(nowMs, snapshot())
                if (stopped.get()) return
                latestObservation = decision
                when (decision.failure) {
                    null -> null
                    StreamingBacklogFailure.SUSTAINED_BACKLOG -> StreamingStopCause.BACKLOG
                    StreamingBacklogFailure.INVALID_INPUT -> StreamingStopCause.INVALID_PCM
                }
            } catch (_: OutOfMemoryError) {
                StreamingStopCause.MEMORY
            } catch (_: Throwable) {
                StreamingStopCause.ENGINE
            }
        }
        cause?.let(::degrade)
    }

    /** First failure wins; notification failure cannot prevent resource closure. */
    fun degrade(cause: StreamingStopCause): CompletionStage<Unit> {
        val first = stopped.compareAndSet(false, true)
        if (first) {
            stopCause = cause
            cancelObservation()
        }
        val acknowledgement = owner.closeAsync()
        if (first) runCatching { onDegraded(cause, acknowledgement) }
        return acknowledgement
    }

    fun closeAsync(): CompletionStage<Unit> {
        stopped.set(true)
        cancelObservation()
        return owner.closeAsync()
    }

    private fun cancelObservation() {
        registration.getAndSet(null)?.let { runCatching { it.close() } }
    }
}
