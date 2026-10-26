package com.loquiris.recording

/** Map native interruption evidence, never an inference completion wall time. */
fun RecordingInterruptionDecision.inferenceBoundary(): PcmCaptureBoundary? = when {
    !shouldPause -> null
    markers.any { it.source == RecordingInterruptionSource.audioFocus && it.phase == RecordingInterruptionPhase.began } ->
        PcmCaptureBoundary.AUDIO_FOCUS
    else -> PcmCaptureBoundary.DISCONTINUITY
}
