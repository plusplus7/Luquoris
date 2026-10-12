package com.loquiris.recording

import android.Manifest
import android.content.pm.PackageManager
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RecordingServiceProcessRecreationRecoveryInstrumentedTest {
    @Test
    fun newProcessMarksPersistedActiveSessionRecoverableWithoutReopeningMicrophone() {
        val arguments = InstrumentationRegistry.getArguments()
        assumeTrue(
            arguments.getString(RecordingServiceRecreationFixture.PHASE_ARGUMENT) ==
                RecordingServiceRecreationFixture.RECOVER_PHASE,
        )
        val expectedNonce = RecordingServiceRecreationFixture.requireNonce(arguments)
        val marker = RecordingServiceRecreationFixture.readMarker()
        assertEquals(expectedNonce, marker.nonce)
        assertEquals(
            "the host must revoke microphone permission before cold-process recovery",
            PackageManager.PERMISSION_DENIED,
            RecordingInstrumentedTestHarness.context.checkSelfPermission(Manifest.permission.RECORD_AUDIO),
        )

        val loaded =
            RecordingChannelSnapshotReader(
                SharedPreferencesRecordingStateStore(RecordingInstrumentedTestHarness.context),
            ).read()
        assertTrue(loaded is RecordingStateLoadResult.Loaded)
        val recovered = (loaded as RecordingStateLoadResult.Loaded).snapshot
        assertEquals(marker.sessionId, recovered.sessionId)
        assertEquals(NativeRecordingState.recoverable, recovered.state)
        assertTrue(recovered.bytesWritten >= marker.bytesWritten)
        assertTrue(recovered.revision > marker.revision)
        assertFalse(RecordingProcessLiveness.owns(marker.sessionId))
        assertTrue(RecordingInstrumentedTestHarness.activeNotifications().isEmpty())
        assertEquals(
            RecordingForegroundServiceStartResult.Failed("recording_permission_denied"),
            RecordingForegroundService.start(RecordingInstrumentedTestHarness.context, marker.sessionId),
        )
        assertTrue(RecordingServiceRecreationFixture.consumeMarker())
    }
}
