package com.loquiris.recording

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RecordingDeviceRestartRecoveryInstrumentedTest {
    @Test
    fun rebootedProcessRecoversCommittedAudioWithoutReopeningMicrophone() {
        val arguments = InstrumentationRegistry.getArguments()
        assumeTrue(
            arguments.getString(RecordingDeviceRestartPreparationInstrumentedTest.PHASE_ARGUMENT) ==
                RecordingDeviceRestartPreparationInstrumentedTest.RECOVER_PHASE,
        )
        val expectedNonce = RecordingServiceRecreationFixture.requireNonce(arguments)
        val marker = RecordingDeviceRestartFixture.readMarker()
        assertEquals(expectedNonce, marker.nonce)
        assertEquals(
            marker.manifestSha256,
            RecordingDeviceRestartFixture.currentManifestSha256(marker.sessionId),
        )
        assertEquals(
            marker.prefixes,
            RecordingDeviceRestartFixture.currentPrefixes(marker.sessionId),
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

        val inventory =
            RecordingStartupReconciler(
                File(RecordingInstrumentedTestHarness.context.filesDir, "recordings"),
            ).scan()
        val session = inventory.sessions.single { it.meetingId == marker.sessionId }
        assertTrue(session.segments.any { it.state == RecordingRecoverySegmentState.committed })
        assertTrue(session.rawExportSegments.isNotEmpty())
        assertTrue(RecordingDeviceRestartFixture.consumeMarker())
    }
}
