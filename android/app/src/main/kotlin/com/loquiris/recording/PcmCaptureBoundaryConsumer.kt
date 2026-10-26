package com.loquiris.recording

/** Recorder state transitions, not inference wall-clock positions. */
enum class PcmCaptureBoundary { PAUSE, AUDIO_FOCUS, DISCONTINUITY, STOP }

/** Optional capability. Native boundary work executes only on the inference worker. */
interface PcmCaptureBoundaryConsumer : PcmInferenceConsumer {
    fun onCaptureBoundary(boundary: PcmCaptureBoundary)

    /**
     * Idempotent, nonblocking cancellation/degradation; may run on a recorder
     * caller and repeat for queued markers plus their capture abort.
     */
    fun onBoundaryRejected(result: PcmInferenceBoundaryResult)
}
