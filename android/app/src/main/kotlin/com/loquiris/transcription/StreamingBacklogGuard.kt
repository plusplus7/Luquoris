package com.loquiris.transcription

import com.loquiris.recording.PcmInferenceBacklog

/** Half-open interval in the canonical captured sample coordinate system. */
data class PcmSampleInterval(val startSample: Long, val endSampleExclusive: Long)

enum class StreamingBacklogFailure { SUSTAINED_BACKLOG, INVALID_INPUT }

data class StreamingBacklogDecision(
    val uniqueSamples: Long?,
    val consecutiveOverloadObservations: Int,
    val failure: StreamingBacklogFailure? = null,
)

/**
 * One worker-owned policy per live owner. Not called on the capture callback.
 *
 * Call once per monotonic second with an atomic, immutable snapshot of ALL
 * unprocessed queued AND in-flight canonical sample intervals. Decode-window
 * overlap must not be mistaken for additional captured audio. No PCM is retained.
 * Early/stale observations are ignored; a missed second breaks the streak.
 * A failure stays latched: resuming inference requires a new owner/policy.
 * This policy neither schedules checks nor releases the recognizer itself.
 */
class StreamingBacklogGuard(private val sampleRate: Int) {
    /** Consume canonical fan-out ownership without treating legacy offsets as zero. */
    fun observeBacklog(monotonicMs: Long, backlog: PcmInferenceBacklog): StreamingBacklogDecision {
        if (decision.failure != null) return decision
        if (backlog.hasUnknownPosition || backlog.pendingFrames < 0 || backlog.pendingFrames > 512 ||
            backlog.intervals.size != backlog.pendingFrames
        ) {
            decision = StreamingBacklogDecision(null, 0, StreamingBacklogFailure.INVALID_INPUT)
            return decision
        }
        return observe(monotonicMs, backlog.intervals.map { PcmSampleInterval(it.startSample, it.endSampleExclusive) })
    }

    init {
        require(sampleRate > 0)
    }

    private var lastObservationMs: Long? = null
    private var decision = StreamingBacklogDecision(0, 0)

    fun observe(monotonicMs: Long, pending: List<PcmSampleInterval>): StreamingBacklogDecision {
        if (decision.failure != null) return decision
        if (monotonicMs < 0) {
            decision = StreamingBacklogDecision(null, 0, StreamingBacklogFailure.INVALID_INPUT)
            return decision
        }
        val previousMs = lastObservationMs
        if (previousMs != null &&
            (monotonicMs < previousMs || monotonicMs - previousMs < 1000)
        ) return decision

        // Bound both sorting work and temporary metadata, even for corrupt input.
        if (pending.size > 512 || pending.any {
                it.startSample < 0 || it.endSampleExclusive <= it.startSample
            }
        ) {
            decision = StreamingBacklogDecision(null, 0, StreamingBacklogFailure.INVALID_INPUT)
            return decision
        }

        var unique = 0L
        var coveredThrough = 0L
        for (interval in pending.sortedBy { it.startSample }) {
            val uncoveredStart = maxOf(coveredThrough, interval.startSample)
            if (interval.endSampleExclusive > uncoveredStart) {
                unique += interval.endSampleExclusive - uncoveredStart
                coveredThrough = interval.endSampleExclusive
            }
        }
        val priorStreak = if (previousMs != null && monotonicMs - previousMs < 2000) {
            decision.consecutiveOverloadObservations
        } else 0
        val streak = if (unique > sampleRate.toLong() * 5) priorStreak + 1 else 0
        lastObservationMs = monotonicMs
        decision = StreamingBacklogDecision(
            unique,
            streak,
            if (streak >= 3) StreamingBacklogFailure.SUSTAINED_BACKLOG else null,
        )
        return decision
    }
}
