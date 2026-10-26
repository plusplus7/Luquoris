package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame

/** Why capture continuity was explicitly cut; these are not localized UI strings. */
enum class StreamingBoundaryReason { PAUSE, AUDIO_FOCUS, DISCONTINUITY, STOP }

/** Owner-scoped media events; sequence orders both text and coverage markers. */
sealed interface StreamingCaptureEvent {
    val owner: StreamingRemoteIdentity
    val sequence: Long
}

/** Conservative capture bounds, not inferred word boundaries or voiced timestamps. */
data class StreamingCaptureText(
    override val owner: StreamingRemoteIdentity,
    override val sequence: Long,
    val utteranceId: String,
    val startSample: Long,
    val endSampleExclusive: Long,
    val captureEpoch: Long,
    val rawText: String,
    val finalized: Boolean,
) : StreamingCaptureEvent

/** Missing media or an explicit zero-length capture-generation boundary, never text. */
data class StreamingCaptureGap(
    override val owner: StreamingRemoteIdentity,
    override val sequence: Long,
    val startSample: Long,
    val endSampleExclusive: Long,
    val captureEpoch: Long,
    val reason: StreamingBoundaryReason,
) : StreamingCaptureEvent

/** Pure capture-coordinate reconciliation, used only after matching remote ACKs. */
class StreamingCaptureTimeline(private val owner: StreamingRemoteIdentity) {
    private var nextSample: Long? = null
    private var captureEpoch: Long? = null
    private var windowStart: Long? = null
    private var utteranceId: String? = null
    private var lastText: String? = null
    private var nextUtterance = 1L
    private var sequence = 0L
    private var pendingBoundary: StreamingBoundaryReason? = null
    private var closed = false

    /** Repeated partial text is suppressed; endpoint results always seal existing text. */
    @Synchronized
    fun accept(frame: PcmCaptureFrame, result: StreamingRemoteResult.Text): List<StreamingCaptureEvent> {
        if (closed) return emptyList()
        val start = requireNotNull(frame.canonicalStartSample)
        val end = requireNotNull(frame.canonicalEndSampleExclusive)
        require(end - start in 1..16000L)
        require(result.text.length <= 16000)
        val previousEnd = nextSample
        val previousEpoch = captureEpoch
        val boundary = pendingBoundary
        if (previousEnd != null) {
            require(if (boundary == null) start == previousEnd else start >= previousEnd)
            require(if (boundary == null) frame.captureEpoch == previousEpoch
                else frame.captureEpoch >= requireNotNull(previousEpoch))
        }
        val events = mutableListOf<StreamingCaptureEvent>()
        if (boundary != null) {
            events.add(StreamingCaptureGap(owner, takeSequence(), previousEnd ?: 0L,
                start, frame.captureEpoch, boundary))
            pendingBoundary = null
            windowStart = start
        } else if (previousEnd == null) {
            if (start > 0) events.add(StreamingCaptureGap(owner, takeSequence(), 0,
                start, frame.captureEpoch, StreamingBoundaryReason.DISCONTINUITY))
            windowStart = start
        }
        nextSample = end
        captureEpoch = frame.captureEpoch
        appendText(events, result, end, frame.captureEpoch)
        return events.toList()
    }

    /** Flush padding never advances nextSample; repeated boundaries do not repeat text. */
    @Synchronized
    fun finishBoundary(result: StreamingRemoteResult.Text, reason: StreamingBoundaryReason): List<StreamingCaptureEvent> {
        if (closed) return emptyList()
        require(result.endpoint && result.text.length <= 16000)
        if (pendingBoundary != null) {
            if (reason == StreamingBoundaryReason.STOP) closed = true
            return emptyList()
        }
        val through = nextSample ?: 0L
        // No sample interval exists for a fresh stream or immediately after
        // endpoint. Nonempty text there would fabricate a zero-length utterance.
        require(result.text.isBlank() || windowStart != null && through > requireNotNull(windowStart))
        val events = mutableListOf<StreamingCaptureEvent>()
        appendText(events, result, through, captureEpoch ?: 0L)
        pendingBoundary = reason
        if (reason == StreamingBoundaryReason.STOP) closed = true
        return events.toList()
    }

    /** Cancellation seals the owner without converting an old guess into final text. */
    @Synchronized
    fun close() { closed = true }

    private fun appendText(
        events: MutableList<StreamingCaptureEvent>, result: StreamingRemoteResult.Text,
        through: Long, epoch: Long,
    ) {
        if ((result.text.isNotBlank() || utteranceId != null) &&
            (result.endpoint || result.text != lastText)) {
            val id = utteranceId ?: "utterance-$nextUtterance".also {
                nextUtterance = Math.addExact(nextUtterance, 1L)
                utteranceId = it
            }
            // Empty text is a retraction of this existing provisional only,
            // never a new silence utterance or evidence of recognized speech.
            events.add(StreamingCaptureText(owner, takeSequence(), id,
                requireNotNull(windowStart), through, epoch, result.text, result.endpoint))
            lastText = result.text
        }
        if (result.endpoint) {
            utteranceId = null
            lastText = null
            windowStart = through
        }
    }

    private fun takeSequence(): Long {
        val current = sequence
        sequence = Math.addExact(sequence, 1L)
        return current
    }
}
