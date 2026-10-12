package com.loquiris.recording

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.ParcelFileDescriptor
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import androidx.test.runner.lifecycle.ActivityLifecycleMonitorRegistry
import androidx.test.runner.lifecycle.Stage
import com.loquiris.MainActivity
import java.io.File
import java.io.FileOutputStream
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RecordingForegroundServiceInstrumentedTest {
    @Test
    fun insufficientPreflightSpaceReturnsStructuredFailureWithoutStartingCapture() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext

        val result = RecordingForegroundService.start(context, "low-space-meeting") { 0L }

        assertEquals(
            RecordingForegroundServiceStartResult.Failed(
                code = "recording_storage_preflight_insufficient",
                availableBytes = 0L,
                requiredBytes = RecordingStoragePolicy.startRequiredBytes,
            ),
            result,
        )
    }

    @get:Rule
    val permissions: GrantPermissionRule =
        GrantPermissionRule.grant(
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.POST_NOTIFICATIONS,
        )

    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    @Before
    fun clearState() {
        context.getSharedPreferences(RECORDING_STATE_PREFERENCES, Context.MODE_PRIVATE).edit().clear().commit()
        context.getSystemService(NotificationManager::class.java).cancelAll()
        File(context.filesDir, "recordings").deleteRecursively()
    }

    @After
    fun stopServiceAndClearState() {
        context.stopService(Intent(context, RecordingForegroundService::class.java))
        context.getSharedPreferences(RECORDING_STATE_PREFERENCES, Context.MODE_PRIVATE).edit().clear().commit()
    }

    @Test
    fun startCapturesCanonicalAudioAndPublishesOngoingNotification() {
        bringTargetAppToForeground()
        val result = RecordingForegroundService.start(context, "instrumented-meeting")

        assertEquals(
            false,
            (result as RecordingForegroundServiceStartResult.RequestAccepted).notificationVisibilityReduced,
        )
        assertTrue(waitUntil { activeNotifications().isNotEmpty() })
        val notification = activeNotifications().single().notification
        assertTrue(notification.flags and android.app.Notification.FLAG_ONGOING_EVENT != 0)
        assertTrue(notification.contentIntent != null)
        notification.contentIntent.send()
        assertTrue(
            waitUntil {
                resumedMainActivityIntentData() ==
                    Uri.parse(RecordingActiveSessionRoute.uri("instrumented-meeting"))
            },
        )

        assertTrue(
            waitUntil {
                val loaded = SharedPreferencesRecordingStateStore(context).load()
                loaded is RecordingStateLoadResult.Loaded &&
                    loaded.snapshot.state == NativeRecordingState.recording &&
                    loaded.snapshot.bytesWritten > 0
            },
        )
        val stored = SharedPreferencesRecordingStateStore(context).load() as RecordingStateLoadResult.Loaded
        assertEquals("instrumented-meeting", stored.snapshot.sessionId)
        assertEquals(NativeRecordingState.recording, stored.snapshot.state)
        val recordingDirectory = AppPrivateRecordingStorage.sessionDirectory(context, "instrumented-meeting")
        assertTrue(File(recordingDirectory, AtomicRecordingSegmentManifestStore.MANIFEST_FILE_NAME).isFile)
        assertTrue(recordingDirectory.listFiles().orEmpty().any { it.extension == "adts" && it.length() > 0 })

        RecordingForegroundService.start(context, "instrumented-meeting")
        RecordingForegroundService.start(context, "conflicting-meeting")
        context.startService(
            Intent(context, RecordingForegroundService::class.java)
                .setAction("com.loquiris.recording.INVALID"),
        )
        InstrumentationRegistry.getInstrumentation().waitForIdleSync()
        assertTrue(waitUntil { activeNotifications().size == 1 })
        val afterRejectedRequests =
            SharedPreferencesRecordingStateStore(context).load()
                as RecordingStateLoadResult.Loaded
        assertEquals("instrumented-meeting", afterRejectedRequests.snapshot.sessionId)
        assertEquals(NativeRecordingState.recording, afterRejectedRequests.snapshot.state)

        assertTrue(context.stopService(Intent(context, RecordingForegroundService::class.java)))
        assertTrue(waitUntil { activeNotifications().isEmpty() })
    }

    @Test
    fun bookmarkJournalRecoversTornTailInAppPrivateStorage() {
        val sessionId = "instrumented-bookmark"
        val journalFile =
            File(
                File(context.filesDir, "recording-events"),
                "${sessionId.sha256Hex()}.bookmarks",
            )
        journalFile.delete()
        val first =
            RecordingBookmarkEvent(
                sessionId = sessionId,
                mediaElapsedMilliseconds = 1_000L,
                wallClockEpochMilliseconds = 10_000L,
            )
        val second = first.copy(mediaElapsedMilliseconds = 2_000L, wallClockEpochMilliseconds = 11_000L)

        assertTrue(
            RecordingBookmarkJournal(
                AppPrivateRecordingBookmarkSink(context, sessionId),
            ).append(first),
        )
        FileOutputStream(journalFile, true).use { output ->
            output.write("v1\t999\ttorn".toByteArray())
            output.fd.sync()
        }
        assertTrue(
            RecordingBookmarkJournal(
                AppPrivateRecordingBookmarkSink(context, sessionId),
            ).append(second),
        )

        assertEquals(
            listOf(first, second),
            journalFile.readLines().map { line -> requireNotNull(RecordingBookmarkFrame.decode(line)) },
        )
        journalFile.delete()
    }

    private fun activeNotifications() =
        context.getSystemService(NotificationManager::class.java).activeNotifications.toList()

    private fun bringTargetAppToForeground() {
        val command =
            "am start -W -n ${context.packageName}/${MainActivity::class.java.name}"
        ParcelFileDescriptor.AutoCloseInputStream(
            InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand(command),
        ).bufferedReader().use { output ->
            assertTrue(output.readText().contains("Status: ok"))
        }
    }

    private fun resumedMainActivityIntentData(): Uri? {
        var data: Uri? = null
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            data =
                ActivityLifecycleMonitorRegistry
                    .getInstance()
                    .getActivitiesInStage(Stage.RESUMED)
                    .filterIsInstance<MainActivity>()
                    .singleOrNull()
                    ?.intent
                    ?.data
        }
        return data
    }

    private fun waitUntil(predicate: () -> Boolean): Boolean {
        repeat(100) {
            if (predicate()) return true
            Thread.sleep(50)
        }
        return false
    }

    companion object {
        private const val RECORDING_STATE_PREFERENCES = "loquiris-recording-state"
    }
}
