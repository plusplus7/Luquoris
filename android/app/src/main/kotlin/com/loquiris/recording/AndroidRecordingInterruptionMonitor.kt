package com.loquiris.recording

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Handler
import java.io.Closeable

object RecordingInterruptionPlatformMapping {
    fun focusSignal(focusChange: Int): RecordingInterruptionSignal? =
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK,
            -> RecordingInterruptionSignal.transientFocusLost
            AudioManager.AUDIOFOCUS_LOSS -> RecordingInterruptionSignal.permanentFocusLost
            AudioManager.AUDIOFOCUS_GAIN -> RecordingInterruptionSignal.focusGained
            else -> null
        }

    fun isCallLikeMode(mode: Int): Boolean =
        mode == AudioManager.MODE_IN_CALL ||
            mode == AudioManager.MODE_IN_COMMUNICATION ||
            mode == AudioManager.MODE_CALL_SCREENING ||
            mode == AudioManager.MODE_CALL_REDIRECT ||
            mode == AudioManager.MODE_COMMUNICATION_REDIRECT
}

object RecordingInterruptionNotificationPolicy {
    fun showResumeAction(
        state: NativeRecordingState,
        confirmationRequired: Boolean,
    ): Boolean =
        !confirmationRequired &&
            (state == NativeRecordingState.pausedByUser || state == NativeRecordingState.pausedByInterruption)
}

object RecordingInterruptionCommandPolicy {
    fun canApplyUserPause(state: NativeRecordingState): Boolean =
        state == NativeRecordingState.recording || state == NativeRecordingState.pausedByUser
}

class AndroidRecordingInterruptionMonitor(
    context: Context,
    callbackHandler: Handler,
    private val onSignal: (RecordingInterruptionSignal) -> Unit,
) : Closeable {
    private val audioManager = context.applicationContext.getSystemService(AudioManager::class.java)
    private val focusListener =
        AudioManager.OnAudioFocusChangeListener { change ->
            if (change == AudioManager.AUDIOFOCUS_LOSS) focusHeld = false
            if (change == AudioManager.AUDIOFOCUS_GAIN) focusHeld = true
            RecordingInterruptionPlatformMapping.focusSignal(change)?.let(onSignal)
        }
    private val focusRequest =
        AudioFocusRequest
            .Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
            .setAudioAttributes(
                AudioAttributes
                    .Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            ).setWillPauseWhenDucked(true)
            .setOnAudioFocusChangeListener(focusListener, callbackHandler)
            .build()
    private var focusHeld = false
    private var callLikeMode = false

    fun start(): Boolean {
        callLikeMode = RecordingInterruptionPlatformMapping.isCallLikeMode(audioManager.mode)
        if (callLikeMode) return false
        focusHeld =
            try {
                audioManager.requestAudioFocus(focusRequest) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
            } catch (_: RuntimeException) {
                false
            }
        return focusHeld
    }

    fun pollAudioMode() {
        val current =
            try {
                RecordingInterruptionPlatformMapping.isCallLikeMode(audioManager.mode)
            } catch (_: RuntimeException) {
                false
            }
        if (current == callLikeMode) return
        callLikeMode = current
        onSignal(
            if (current) {
                RecordingInterruptionSignal.callModeEntered
            } else {
                RecordingInterruptionSignal.callModeExited
            },
        )
    }

    fun reacquireFocus(): Boolean {
        if (focusHeld) return true
        focusHeld =
            try {
                audioManager.requestAudioFocus(focusRequest) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
            } catch (_: RuntimeException) {
                false
            }
        return focusHeld
    }

    override fun close() {
        if (!focusHeld) return
        focusHeld = false
        try {
            audioManager.abandonAudioFocusRequest(focusRequest)
        } catch (_: RuntimeException) {
            // The recording is already stopping, so a failed abandon needs no retry.
        }
    }
}
