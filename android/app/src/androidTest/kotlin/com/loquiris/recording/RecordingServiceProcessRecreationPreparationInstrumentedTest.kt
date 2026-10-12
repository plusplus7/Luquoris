package com.loquiris.recording

import android.os.Process
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import java.lang.ref.Reference
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RecordingServiceProcessRecreationPreparationInstrumentedTest {
    @get:Rule
    val permissions: GrantPermissionRule = RecordingInstrumentedTestHarness.permissions()

    @Test
    fun killOwningProcessAfterCanonicalAudioIsDurable() {
        val arguments = InstrumentationRegistry.getArguments()
        assumeTrue(
            arguments.getString(RecordingServiceRecreationFixture.PHASE_ARGUMENT) ==
                RecordingServiceRecreationFixture.PREPARE_PHASE,
        )
        val nonce = RecordingServiceRecreationFixture.requireNonce(arguments)
        RecordingInstrumentedTestHarness.reset()
        RecordingInstrumentedTestHarness.launchMainActivity()
        val sessionId = "service-recreation-$nonce"
        val snapshot = RecordingInstrumentedTestHarness.startAndAwaitRecording(sessionId)
        RecordingServiceRecreationFixture.writeMarker(nonce, snapshot)

        Process.killProcess(Process.myPid())
        Reference.reachabilityFence(snapshot)
        Thread.sleep(10_000L)
        error("Process.killProcess returned without terminating the service process")
    }
}
