package com.loquiris.recording

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.rule.GrantPermissionRule
import java.io.File
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RecordingNotificationActionsInstrumentedTest {
    @get:Rule
    val permissions: GrantPermissionRule = RecordingInstrumentedTestHarness.permissions()

    @Before
    fun setUp() = RecordingInstrumentedTestHarness.reset()

    @After
    fun tearDown() = RecordingInstrumentedTestHarness.reset()

    @Test
    fun notificationPausesBookmarksAndResumesWithoutOfferingDestructiveStop() {
        val sessionId = "notification-actions-session"
        RecordingInstrumentedTestHarness.startAndAwaitRecording(sessionId)

        val recordingNotification = RecordingInstrumentedTestHarness.singleNotification()
        val actionTitles = recordingNotification.actions.map { it.title.toString() }
        assertEquals(listOf("Pause", "Bookmark"), actionTitles)
        assertFalse(actionTitles.any { it.equals("Stop", ignoreCase = true) })

        recordingNotification.actions.single { it.title.toString() == "Pause" }.actionIntent.send()
        assertTrue(
            RecordingInstrumentedTestHarness.waitUntil {
                RecordingInstrumentedTestHarness.requireSnapshot().state == NativeRecordingState.pausedByUser
            },
        )
        val stablePaused = RecordingInstrumentedTestHarness.awaitStablePausedSnapshot()

        RecordingInstrumentedTestHarness
            .singleNotification()
            .actions
            .single { it.title.toString() == "Bookmark" }
            .actionIntent
            .send()
        val bookmarkFile =
            File(
                File(RecordingInstrumentedTestHarness.context.filesDir, "recording-events"),
                "${sessionId.sha256Hex()}.bookmarks",
            )
        assertTrue(
            "bookmark action did not durably append an event",
            RecordingInstrumentedTestHarness.waitUntil {
                bookmarkFile.isFile &&
                    bookmarkFile.readLines().mapNotNull(RecordingBookmarkFrame::decode).any {
                        it.sessionId == sessionId
                    }
            },
        )

        RecordingInstrumentedTestHarness
            .singleNotification()
            .actions
            .single { it.title.toString() == "Resume" }
            .actionIntent
            .send()
        assertTrue(
            RecordingInstrumentedTestHarness.waitUntil {
                val snapshot = RecordingInstrumentedTestHarness.requireSnapshot()
                snapshot.state == NativeRecordingState.recording && snapshot.bytesWritten > stablePaused.bytesWritten
            },
        )
    }
}
