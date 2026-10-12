package com.loquiris.recording

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingServiceStartPolicyTest {
    @Test
    fun `microphone permission denial blocks foreground service start`() {
        val decision =
            RecordingServiceStartPolicy.evaluate(
                hasRecordAudioPermission = false,
                notificationPermissionRequired = true,
                hasNotificationPermission = true,
            )

        assertEquals(
            "recording_permission_denied",
            (decision as RecordingServiceStartDecision.Denied).code,
        )
    }

    @Test
    fun `notification denial permits start but reports reduced visibility`() {
        val decision =
            RecordingServiceStartPolicy.evaluate(
                hasRecordAudioPermission = true,
                notificationPermissionRequired = true,
                hasNotificationPermission = false,
            ) as RecordingServiceStartDecision.Allowed

        assertTrue(decision.notificationVisibilityReduced)
    }

    @Test
    fun `granted prerequisites permit normally visible start`() {
        val decision =
            RecordingServiceStartPolicy.evaluate(
                hasRecordAudioPermission = true,
                notificationPermissionRequired = true,
                hasNotificationPermission = true,
            ) as RecordingServiceStartDecision.Allowed

        assertFalse(decision.notificationVisibilityReduced)
    }

    @Test
    fun `pre Android 13 does not require runtime notification permission`() {
        val decision =
            RecordingServiceStartPolicy.evaluate(
                hasRecordAudioPermission = true,
                notificationPermissionRequired = false,
                hasNotificationPermission = false,
            ) as RecordingServiceStartDecision.Allowed

        assertFalse(decision.notificationVisibilityReduced)
    }

    @Test
    fun `only service-owned states may keep a foreground recording service`() {
        val owned =
            setOf(
                NativeRecordingState.preparing,
                NativeRecordingState.recording,
                NativeRecordingState.pausedByUser,
                NativeRecordingState.pausedByInterruption,
                NativeRecordingState.stopping,
            )

        NativeRecordingState.entries.forEach { state ->
            assertEquals(
                "$state ownership",
                state in owned,
                RecordingServiceStartPolicy.canOwnForeground(state),
            )
        }
    }

    @Test
    fun `notification action identity is isolated by session`() {
        val meetingA = RecordingNotificationActionIdentity.uri("pause", "meeting-a")
        val meetingB = RecordingNotificationActionIdentity.uri("pause", "meeting-b")

        assertTrue(meetingA != meetingB)
        assertTrue(meetingA.startsWith("loquiris-action:/recording/"))
        assertFalse(meetingA.contains("meeting-a"))
    }

    @Test
    fun `active session route preserves one encoded path segment`() {
        assertEquals(
            "loquiris:/recordings/meeting%2Fa%20b",
            RecordingActiveSessionRoute.uri("meeting/a b"),
        )
    }
}
