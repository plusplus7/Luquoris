package com.loquiris.recording

import android.media.AudioManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingInterruptionPlatformMappingTest {
    @Test
    fun `audio focus changes map to conservative recorder signals`() {
        assertEquals(
            RecordingInterruptionSignal.transientFocusLost,
            RecordingInterruptionPlatformMapping.focusSignal(AudioManager.AUDIOFOCUS_LOSS_TRANSIENT),
        )
        assertEquals(
            RecordingInterruptionSignal.transientFocusLost,
            RecordingInterruptionPlatformMapping.focusSignal(AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK),
        )
        assertEquals(
            RecordingInterruptionSignal.permanentFocusLost,
            RecordingInterruptionPlatformMapping.focusSignal(AudioManager.AUDIOFOCUS_LOSS),
        )
        assertEquals(
            RecordingInterruptionSignal.focusGained,
            RecordingInterruptionPlatformMapping.focusSignal(AudioManager.AUDIOFOCUS_GAIN),
        )
        assertEquals(null, RecordingInterruptionPlatformMapping.focusSignal(123_456))
    }

    @Test
    fun `telephony and communication modes are call like but ringtone is not`() {
        assertTrue(RecordingInterruptionPlatformMapping.isCallLikeMode(AudioManager.MODE_IN_CALL))
        assertTrue(RecordingInterruptionPlatformMapping.isCallLikeMode(AudioManager.MODE_IN_COMMUNICATION))
        assertFalse(RecordingInterruptionPlatformMapping.isCallLikeMode(AudioManager.MODE_RINGTONE))
        assertFalse(RecordingInterruptionPlatformMapping.isCallLikeMode(AudioManager.MODE_NORMAL))
    }

    @Test
    fun `notification resume is hidden while confirmation is required`() {
        assertFalse(
            RecordingInterruptionNotificationPolicy.showResumeAction(
                NativeRecordingState.pausedByInterruption,
                confirmationRequired = true,
            ),
        )
        assertTrue(
            RecordingInterruptionNotificationPolicy.showResumeAction(
                NativeRecordingState.pausedByInterruption,
                confirmationRequired = false,
            ),
        )
        assertFalse(
            RecordingInterruptionNotificationPolicy.showResumeAction(
                NativeRecordingState.pausedByUser,
                confirmationRequired = true,
            ),
        )
    }

    @Test
    fun `stale user pause action cannot roll back an interruption pause`() {
        assertTrue(RecordingInterruptionCommandPolicy.canApplyUserPause(NativeRecordingState.recording))
        assertFalse(
            RecordingInterruptionCommandPolicy.canApplyUserPause(
                NativeRecordingState.pausedByInterruption,
            ),
        )
    }
}
