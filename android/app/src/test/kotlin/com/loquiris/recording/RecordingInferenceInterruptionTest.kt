package com.loquiris.recording

import org.junit.Assert.*
import org.junit.Test

class RecordingInferenceInterruptionTest {
    @Test fun bothFocusLossKindsRemainDistinctFromManualPause() {
        for (signal in listOf(RecordingInterruptionSignal.transientFocusLost, RecordingInterruptionSignal.permanentFocusLost)) {
            val decision = RecordingInterruptionPolicy().onSignal(signal, NativeRecordingState.recording)
            assertTrue(decision.shouldPause)
            assertEquals(PcmCaptureBoundary.AUDIO_FOCUS, decision.inferenceBoundary())
        }
    }

    @Test fun microphoneAndCallPausesAreDiscontinuitiesNotFocusOrManualPause() {
        for (signal in listOf(RecordingInterruptionSignal.microphoneSilenced, RecordingInterruptionSignal.callModeEntered)) {
            val decision = RecordingInterruptionPolicy().onSignal(signal, NativeRecordingState.recording)
            assertTrue(decision.shouldPause)
            assertEquals(PcmCaptureBoundary.DISCONTINUITY, decision.inferenceBoundary())
        }
    }

    @Test fun focusReturnAndAlreadyPausedSignalsDoNotEmitAnotherPauseBoundary() {
        val policy = RecordingInterruptionPolicy()
        policy.onSignal(RecordingInterruptionSignal.transientFocusLost, NativeRecordingState.recording)
        assertNull(policy.onSignal(RecordingInterruptionSignal.focusGained, NativeRecordingState.pausedByInterruption).inferenceBoundary())
        assertNull(policy.onSignal(RecordingInterruptionSignal.transientFocusLost, NativeRecordingState.pausedByUser).inferenceBoundary())
    }

    @Test fun endingFocusMarkerDoesNotMislabelAnotherInterruption() {
        val decision = RecordingInterruptionDecision(true, false, true, false,
            listOf(RecordingInterruptionMarker(RecordingInterruptionSource.audioFocus, RecordingInterruptionPhase.ended),
                RecordingInterruptionMarker(RecordingInterruptionSource.call, RecordingInterruptionPhase.began)))
        assertEquals(PcmCaptureBoundary.DISCONTINUITY, decision.inferenceBoundary())
    }
}
