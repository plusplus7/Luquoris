package com.loquiris.transcription

internal enum class StreamingProbeRoute {
    FILE, MICROPHONE, RECORDER;
    companion object {
        fun resolve(modelId: String, digest: String, microphoneGranted: Boolean): StreamingProbeRoute? {
            if (digest != StreamingProbeBundle.digest) return null
            return when (modelId) {
                StreamingProbeBundle.fileModelId -> FILE
                "debug-native-microphone-probe" -> if (microphoneGranted) MICROPHONE else null
                "debug-native-recorder-probe" -> if (microphoneGranted) RECORDER else null
                else -> null
            }
        }
    }
}
