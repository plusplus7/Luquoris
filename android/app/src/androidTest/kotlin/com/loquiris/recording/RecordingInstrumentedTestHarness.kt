package com.loquiris.recording

import android.Manifest
import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.ParcelFileDescriptor
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import com.loquiris.MainActivity
import java.io.File
import org.junit.Assert.assertTrue

internal object RecordingInstrumentedTestHarness {
    val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    fun permissions(): GrantPermissionRule =
        GrantPermissionRule.grant(
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.POST_NOTIFICATIONS,
        )

    fun reset() {
        wakeScreen()
        val existing = snapshotOrNull()
        val sessionId = existing?.sessionId
        if (
            sessionId != null &&
            existing.state in PersistedRecordingStateMachine.activeStates &&
            RecordingProcessLiveness.owns(sessionId)
        ) {
            RecordingForegroundService.stop(context, sessionId, "instrumented-test-cleanup")
        } else {
            context.stopService(Intent(context, RecordingForegroundService::class.java))
            RecordingChannelSnapshotReader(SharedPreferencesRecordingStateStore(context)).read()
        }
        assertTrue(
            "recording service cleanup did not reach an owned terminal state",
            waitUntil {
                val current = snapshotOrNull()
                activeNotifications().isEmpty() &&
                    !RecordingProcessLiveness.owns(sessionId) &&
                    (current == null || current.state !in PersistedRecordingStateMachine.activeStates)
            },
        )
        context.stopService(Intent(context, RecordingForegroundService::class.java))
        context.getSharedPreferences("loquiris-recording-state", Context.MODE_PRIVATE).edit().clear().commit()
        context.getSharedPreferences("recording-command-receipts-v1", Context.MODE_PRIVATE).edit().clear().commit()
        File(context.filesDir, "recordings").deleteRecursively()
        File(context.filesDir, "recording-events").deleteRecursively()
        File(context.filesDir, "recording-interruptions").deleteRecursively()
        File(context.filesDir, "recording-storage-failures").deleteRecursively()
    }

    fun startAndAwaitRecording(sessionId: String): NativeRecordingSnapshot {
        val result = RecordingForegroundService.start(context, sessionId)
        assertTrue(
            "foreground recording request was rejected: $result",
            result is RecordingForegroundServiceStartResult.RequestAccepted,
        )
        assertTrue(
            "recording did not produce canonical bytes",
            waitUntil {
                snapshotOrNull()?.let {
                    it.sessionId == sessionId &&
                        it.state == NativeRecordingState.recording &&
                        it.bytesWritten > 0L
                } == true
            },
        )
        return requireSnapshot()
    }

    fun requireSnapshot(): NativeRecordingSnapshot =
        requireNotNull(snapshotOrNull()) { "authoritative recording snapshot is unavailable" }

    fun activeNotifications() =
        context.getSystemService(NotificationManager::class.java).activeNotifications.toList()

    fun singleNotification(): Notification = activeNotifications().single().notification

    fun awaitStablePausedSnapshot(): NativeRecordingSnapshot {
        val first = requireSnapshot()
        require(first.state == NativeRecordingState.pausedByUser) { "recording is not paused by the user" }
        Thread.sleep(PAUSED_STABILITY_WINDOW_MILLIS)
        val second = requireSnapshot()
        assertTrue("recording left paused state during stability window", second.state == NativeRecordingState.pausedByUser)
        assertTrue(
            "canonical bytes changed while paused: ${first.bytesWritten} -> ${second.bytesWritten}",
            second.bytesWritten == first.bytesWritten,
        )
        assertTrue(
            "media time changed while paused: ${first.elapsedMilliseconds} -> ${second.elapsedMilliseconds}",
            second.elapsedMilliseconds == first.elapsedMilliseconds,
        )
        return second
    }

    fun launchMainActivity() {
        val output =
            executeShell(
                "am start -W -n ${context.packageName}/${MainActivity::class.java.name}",
            )
        assertTrue("unable to launch target app: $output", output.contains("Status: ok"))
    }

    fun pressHome() {
        executeShell("input keyevent KEYCODE_HOME")
    }

    fun turnScreenOff() {
        executeShell("input keyevent KEYCODE_SLEEP")
    }

    fun wakeScreen() {
        executeShell("input keyevent KEYCODE_WAKEUP")
        executeShell("wm dismiss-keyguard")
    }

    fun waitUntil(
        timeoutMilliseconds: Long = 15_000L,
        predicate: () -> Boolean,
    ): Boolean {
        val deadline = android.os.SystemClock.elapsedRealtime() + timeoutMilliseconds
        do {
            if (runCatching(predicate).getOrDefault(false)) return true
            Thread.sleep(100L)
        } while (android.os.SystemClock.elapsedRealtime() < deadline)
        return runCatching(predicate).getOrDefault(false)
    }

    private fun snapshotOrNull(): NativeRecordingSnapshot? =
        (SharedPreferencesRecordingStateStore(context).load() as? RecordingStateLoadResult.Loaded)?.snapshot

    private fun executeShell(command: String): String =
        ParcelFileDescriptor.AutoCloseInputStream(
            InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand(command),
        ).bufferedReader().use { it.readText() }

    private const val PAUSED_STABILITY_WINDOW_MILLIS = 2_200L
}
