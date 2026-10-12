package com.loquiris.recording

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingInterruptionPolicyTest {
    @Test
    fun `transient focus loss pauses and focus gain auto resumes only its own pause`() {
        val policy = RecordingInterruptionPolicy()

        val loss = policy.onSignal(RecordingInterruptionSignal.transientFocusLost, NativeRecordingState.recording)

        assertTrue(loss.shouldPause)
        assertFalse(loss.shouldResume)
        assertFalse(loss.confirmationRequired)
        assertEquals(
            listOf(RecordingInterruptionMarker(RecordingInterruptionSource.audioFocus, RecordingInterruptionPhase.began)),
            loss.markers,
        )

        val gain = policy.onSignal(RecordingInterruptionSignal.focusGained, NativeRecordingState.pausedByInterruption)

        assertFalse(gain.shouldPause)
        assertTrue(gain.shouldResume)
        assertFalse(gain.confirmationRequired)
        assertEquals(
            listOf(RecordingInterruptionMarker(RecordingInterruptionSource.audioFocus, RecordingInterruptionPhase.ended)),
            gain.markers,
        )
    }

    @Test
    fun `focus callbacks never resume a user pause`() {
        val policy = RecordingInterruptionPolicy()

        policy.onSignal(RecordingInterruptionSignal.transientFocusLost, NativeRecordingState.pausedByUser)
        val gain = policy.onSignal(RecordingInterruptionSignal.focusGained, NativeRecordingState.pausedByUser)

        assertFalse(gain.shouldResume)
        assertTrue(gain.canUserResume)
    }

    @Test
    fun `call mode upgrades a transient pause and requires confirmation after call ends`() {
        val policy = RecordingInterruptionPolicy()
        policy.onSignal(RecordingInterruptionSignal.transientFocusLost, NativeRecordingState.recording)

        val call = policy.onSignal(RecordingInterruptionSignal.callModeEntered, NativeRecordingState.pausedByInterruption)
        val focus = policy.onSignal(RecordingInterruptionSignal.focusGained, NativeRecordingState.pausedByInterruption)
        val ended = policy.onSignal(RecordingInterruptionSignal.callModeExited, NativeRecordingState.pausedByInterruption)

        assertTrue(call.confirmationRequired)
        assertEquals(
            listOf(
                RecordingInterruptionMarker(RecordingInterruptionSource.call, RecordingInterruptionPhase.began),
                RecordingInterruptionMarker(RecordingInterruptionSource.call, RecordingInterruptionPhase.confirmationRequired),
            ),
            call.markers,
        )
        assertFalse(focus.shouldResume)
        assertFalse(ended.shouldResume)
        assertFalse(ended.canUserResume)

        val confirmed =
            policy.onSignal(
                RecordingInterruptionSignal.confirmationGranted,
                NativeRecordingState.pausedByInterruption,
            )

        assertTrue(confirmed.shouldResume)
        assertFalse(confirmed.confirmationRequired)
        assertEquals(
            listOf(RecordingInterruptionMarker(RecordingInterruptionSource.call, RecordingInterruptionPhase.confirmed)),
            confirmed.markers,
        )
    }

    @Test
    fun `ambiguous microphone silence requires confirmation and cannot auto resume`() {
        val policy = RecordingInterruptionPolicy()

        val silenced = policy.onSignal(RecordingInterruptionSignal.microphoneSilenced, NativeRecordingState.recording)
        policy.onSignal(RecordingInterruptionSignal.microphoneAvailable, NativeRecordingState.pausedByInterruption)
        val focus = policy.onSignal(RecordingInterruptionSignal.focusGained, NativeRecordingState.pausedByInterruption)

        assertTrue(silenced.shouldPause)
        assertTrue(silenced.confirmationRequired)
        assertFalse(focus.shouldResume)
        assertFalse(focus.canUserResume)
    }

    @Test
    fun `explicit confirmation can retry an ambiguous microphone interruption`() {
        val policy = RecordingInterruptionPolicy()
        policy.onSignal(RecordingInterruptionSignal.microphoneSilenced, NativeRecordingState.recording)

        val confirmed =
            policy.onSignal(
                RecordingInterruptionSignal.confirmationGranted,
                NativeRecordingState.pausedByInterruption,
            )

        assertTrue(confirmed.shouldResume)
        assertFalse(confirmed.confirmationRequired)
        assertEquals(
            listOf(
                RecordingInterruptionMarker(RecordingInterruptionSource.microphone, RecordingInterruptionPhase.ended),
                RecordingInterruptionMarker(RecordingInterruptionSource.microphone, RecordingInterruptionPhase.confirmed),
            ),
            confirmed.markers,
        )
    }

    @Test
    fun `permanent focus loss persists audio focus and system markers without auto resume`() {
        val policy = RecordingInterruptionPolicy()

        val loss = policy.onSignal(RecordingInterruptionSignal.permanentFocusLost, NativeRecordingState.recording)
        assertTrue(policy.focusReacquisitionRequired())
        val gain = policy.onSignal(RecordingInterruptionSignal.focusGained, NativeRecordingState.pausedByInterruption)

        assertTrue(loss.shouldPause)
        assertEquals(
            listOf(
                RecordingInterruptionMarker(RecordingInterruptionSource.audioFocus, RecordingInterruptionPhase.began),
                RecordingInterruptionMarker(RecordingInterruptionSource.system, RecordingInterruptionPhase.began),
            ),
            loss.markers,
        )
        assertFalse(gain.shouldResume)
        assertTrue(gain.canUserResume)
        assertFalse(policy.focusReacquisitionRequired())
    }
}
