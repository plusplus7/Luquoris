package com.loquiris.recording

import com.loquiris.transcription.LivePcmInferenceRegistry

class RecordingLiveInferenceLifecycle(
    private val registry: LivePcmInferenceRegistry = LivePcmInferenceRegistry.process,
) {
    fun attach(meetingId: String, endpoint: CaptureInferenceEndpoint) = registry.bindCaptureEndpoint(meetingId, endpoint)
    fun recordingStopping(meetingId: String) = registry.recordingStopping(meetingId)
    fun recordingFinalized(meetingId: String) = registry.recordingFinalized(meetingId)

    fun attach(
        meetingId: String,
        replaceConsumer: (PcmInferenceConsumer?) -> Unit,
    ) {
        registry.bindCapture(meetingId, replaceConsumer)
    }

    fun recordingEnded(meetingId: String) {
        registry.unbindCapture(meetingId, TRANSCRIPTION_LIVE_RECORDING_STOPPED)
    }

    fun severeThermal(meetingId: String) {
        registry.degradeForThermal(meetingId)
    }

    private companion object {
        const val TRANSCRIPTION_LIVE_RECORDING_STOPPED =
            "transcription_live_recording_stopped"
    }
}
