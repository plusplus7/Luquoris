package com.loquiris.recording

import android.Manifest
import android.app.ActivityManager
import android.os.PowerManager
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.rule.GrantPermissionRule
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RecordingForegroundContinuityInstrumentedTest {
    @get:Rule
    val permissions: GrantPermissionRule = RecordingInstrumentedTestHarness.permissions()

    @Before
    fun setUp() = RecordingInstrumentedTestHarness.reset()

    @After
    fun tearDown() = RecordingInstrumentedTestHarness.reset()

    @Test
    fun captureContinuesWhileAppIsBackgroundedAndScreenIsOff() {
        val sessionId = "background-lock-session"
        RecordingInstrumentedTestHarness.startAndAwaitRecording(sessionId)
        RecordingInstrumentedTestHarness.pressHome()
        val beforeBackground = RecordingInstrumentedTestHarness.requireSnapshot().bytesWritten

        assertTrue(
            "canonical bytes did not grow while backgrounded",
            RecordingInstrumentedTestHarness.waitUntil {
                RecordingInstrumentedTestHarness.requireSnapshot().bytesWritten > beforeBackground
            },
        )

        val power = RecordingInstrumentedTestHarness.context.getSystemService(PowerManager::class.java)
        try {
            RecordingInstrumentedTestHarness.turnScreenOff()
            assertTrue(
                "device did not enter non-interactive screen-off state",
                RecordingInstrumentedTestHarness.waitUntil { !power.isInteractive },
            )
            val beforeScreenOff = RecordingInstrumentedTestHarness.requireSnapshot().bytesWritten
            assertTrue(
                "canonical bytes did not grow while the screen was off",
                RecordingInstrumentedTestHarness.waitUntil {
                    RecordingInstrumentedTestHarness.requireSnapshot().bytesWritten > beforeScreenOff
                },
            )
            assertTrue(RecordingInstrumentedTestHarness.activeNotifications().isNotEmpty())
        } finally {
            RecordingInstrumentedTestHarness.wakeScreen()
        }
    }

    @Test
    fun dismissingRecentTaskDoesNotStopForegroundCapture() {
        val sessionId = "task-dismissal-session"
        RecordingInstrumentedTestHarness.launchMainActivity()
        RecordingInstrumentedTestHarness.startAndAwaitRecording(sessionId)
        val activityManager =
            RecordingInstrumentedTestHarness.context.getSystemService(ActivityManager::class.java)
        activityManager.appTasks.forEach { it.finishAndRemoveTask() }

        assertTrue(
            "target task remained present after finishAndRemoveTask",
            RecordingInstrumentedTestHarness.waitUntil { activityManager.appTasks.isEmpty() },
        )
        val afterDismissal = RecordingInstrumentedTestHarness.requireSnapshot().bytesWritten

        assertTrue(
            "canonical bytes did not grow after recent-task dismissal",
            RecordingInstrumentedTestHarness.waitUntil {
                RecordingInstrumentedTestHarness.requireSnapshot().bytesWritten > afterDismissal
            },
        )
        assertTrue(RecordingInstrumentedTestHarness.activeNotifications().isNotEmpty())
    }
}
