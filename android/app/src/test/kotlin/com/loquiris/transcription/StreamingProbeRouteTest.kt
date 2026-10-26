package com.loquiris.transcription

import org.junit.Assert.*
import org.junit.Test

class StreamingProbeRouteTest {
    @Test fun existingRecorderRouteRequiresPinnedBundleAndAlreadyGrantedMicrophone() {
        val pinned = "18c2bc28a25d62131b108329f79a446429a2b1a757102d70288a7c777fe7933b"
        assertEquals(StreamingProbeRoute.RECORDER, StreamingProbeRoute.resolve("debug-native-recorder-probe", pinned, true))
        assertNull(StreamingProbeRoute.resolve("debug-native-recorder-probe", pinned, false))
        assertNull(StreamingProbeRoute.resolve("debug-native-recorder-probe", "b".repeat(64), true))
    }
    private val digest = "18c2bc28a25d62131b108329f79a446429a2b1a757102d70288a7c777fe7933b"
    @Test fun fileInputDoesNotRequireMicrophonePermission() {
        assertEquals(StreamingProbeRoute.FILE, StreamingProbeRoute.resolve("debug-native-file-probe", digest, false))
    }
    @Test fun microphoneRequiresPinnedInventoryAndAlreadyGrantedPermission() {
        assertEquals(StreamingProbeRoute.MICROPHONE, StreamingProbeRoute.resolve("debug-native-microphone-probe", digest, true))
        assertNull(StreamingProbeRoute.resolve("debug-native-microphone-probe", digest, false))
        assertNull(StreamingProbeRoute.resolve("debug-native-microphone-probe", "a".repeat(64), true))
        assertNull(StreamingProbeRoute.resolve("production-model", digest, true))
    }
}
