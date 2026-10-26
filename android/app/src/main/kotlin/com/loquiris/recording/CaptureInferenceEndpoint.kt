package com.loquiris.recording

import java.util.concurrent.CompletionStage

/** Existing recorder-owned fan-out; never creates a source or owns microphone permission. */
interface CaptureInferenceEndpoint {
    val acceptsInference: Boolean
    fun replaceInferenceConsumer(consumer: PcmInferenceConsumer?)
    fun finishInference(consumer: PcmInferenceConsumer, action: () -> Unit): CompletionStage<PcmInferenceBoundaryResult>
    fun inferenceBacklog(): PcmInferenceBacklog
}
