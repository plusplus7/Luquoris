package com.loquiris.recording

import java.net.URLEncoder
import java.nio.charset.StandardCharsets

sealed interface RecordingServiceStartDecision {
    data class Allowed(
        val notificationVisibilityReduced: Boolean,
    ) : RecordingServiceStartDecision

    data class Denied(
        val code: String,
    ) : RecordingServiceStartDecision
}

object RecordingServiceStartPolicy {
    fun evaluate(
        hasRecordAudioPermission: Boolean,
        notificationPermissionRequired: Boolean,
        hasNotificationPermission: Boolean,
    ): RecordingServiceStartDecision {
        if (!hasRecordAudioPermission) {
            return RecordingServiceStartDecision.Denied("recording_permission_denied")
        }
        return RecordingServiceStartDecision.Allowed(
            notificationVisibilityReduced =
                notificationPermissionRequired && !hasNotificationPermission,
        )
    }

    fun canOwnForeground(state: NativeRecordingState): Boolean =
        state in
            setOf(
                NativeRecordingState.preparing,
                NativeRecordingState.recording,
                NativeRecordingState.pausedByUser,
                NativeRecordingState.pausedByInterruption,
                NativeRecordingState.stopping,
            )
}

interface WakeLockController {
    val isHeld: Boolean

    fun acquire(): Boolean

    fun release()
}

class WakeLockLease(
    private val controller: WakeLockController,
) {
    @Synchronized
    fun acquire(): Boolean {
        if (controller.isHeld) return true
        return controller.acquire()
    }

    @Synchronized
    fun release() {
        if (controller.isHeld) controller.release()
    }
}

fun interface ForegroundPromoter {
    fun promote()
}

object RecordingForegroundPromotion {
    fun attempt(promoter: ForegroundPromoter): Boolean =
        try {
            promoter.promote()
            true
        } catch (_: RuntimeException) {
            false
        }
}

class RecordingServiceOwnership {
    private var sessionId: String? = null

    fun claim(candidateSessionId: String): Boolean {
        val ownedSessionId = sessionId
        if (ownedSessionId != null && ownedSessionId != candidateSessionId) return false
        sessionId = candidateSessionId
        return true
    }

    fun owns(candidateSessionId: String): Boolean = sessionId == candidateSessionId

    fun release(candidateSessionId: String): Boolean {
        if (sessionId != candidateSessionId) return false
        sessionId = null
        return true
    }

    fun shouldStopAfterRejectedStart(): Boolean = sessionId == null
}

object RecordingNotificationActionIdentity {
    fun uri(
        action: String,
        sessionId: String,
    ): String = "loquiris-action:/recording/${sessionId.sha256Hex()}/${action.sha256Hex()}"
}

object RecordingActiveSessionRoute {
    fun uri(sessionId: String): String {
        val encoded =
            URLEncoder
                .encode(sessionId, StandardCharsets.UTF_8.name())
                .replace("+", "%20")
        return "loquiris:/recordings/$encoded"
    }
}
