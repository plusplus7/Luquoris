package com.loquiris.recording

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import java.lang.ref.Reference
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RecordingDeviceRestartPreparationInstrumentedTest {
    @get:Rule
    val permissions: GrantPermissionRule = RecordingInstrumentedTestHarness.permissions()

    @Test
    fun waitForHostRebootAfterCanonicalAudioIsDurable() {
        val arguments = InstrumentationRegistry.getArguments()
        assumeTrue(arguments.getString(PHASE_ARGUMENT) == PREPARE_PHASE)
        val nonce = RecordingServiceRecreationFixture.requireNonce(arguments)
        RecordingInstrumentedTestHarness.reset()
        RecordingInstrumentedTestHarness.launchMainActivity()
        val sessionId = "device-restart-$nonce"
        RecordingInstrumentedTestHarness.startAndAwaitRecording(sessionId)
        Thread.sleep(COMMIT_WINDOW_MILLIS)
        check(RecordingForegroundService.pause(RecordingInstrumentedTestHarness.context, sessionId))
        check(
            RecordingInstrumentedTestHarness.waitUntil {
                RecordingInstrumentedTestHarness.requireSnapshot().state == NativeRecordingState.pausedByUser
            },
        )
        val snapshot = RecordingInstrumentedTestHarness.awaitStablePausedSnapshot()
        RecordingDeviceRestartFixture.writeMarker(nonce, snapshot)

        Thread.sleep(HOST_REBOOT_TIMEOUT_MILLIS)
        Reference.reachabilityFence(snapshot)
        error("Host did not reboot the device before the timeout")
    }

    companion object {
        const val PHASE_ARGUMENT = "loquirisDeviceRestartPhase"
        const val PREPARE_PHASE = "prepare"
        const val RECOVER_PHASE = "recover"
        private const val COMMIT_WINDOW_MILLIS = 6_000L
        private const val HOST_REBOOT_TIMEOUT_MILLIS = 300_000L
    }
}
