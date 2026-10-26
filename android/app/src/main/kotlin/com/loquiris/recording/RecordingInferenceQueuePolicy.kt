package com.loquiris.recording

/** Selects a bounded derived queue without changing canonical recording capacity. */
object RecordingInferenceQueuePolicy {
    // At full 640-byte reads this retains 5.12 seconds (160 KiB of PCM payload).
    // Short reads retain less audio; this is not a latency or backlog qualification.
    private const val STREAMING_STARTUP_CAPACITY_FRAMES = 256

    fun capacityFrames(isDebugBuild: Boolean, streamingNativeSpike: Boolean): Int =
        if (isDebugBuild && streamingNativeSpike) {
            STREAMING_STARTUP_CAPACITY_FRAMES
        } else {
            RecordingCapturePipeline.DEFAULT_INFERENCE_QUEUE_CAPACITY
        }
}
