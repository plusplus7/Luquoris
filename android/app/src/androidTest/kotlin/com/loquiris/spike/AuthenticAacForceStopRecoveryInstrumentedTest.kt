package com.loquiris.spike

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class AuthenticAacForceStopRecoveryInstrumentedTest {
    @Test
    fun authenticAacCommittedPrefixSurvivesHostForceStopAndDecodes() {
        val arguments = InstrumentationRegistry.getArguments()
        assumeTrue(
            arguments.getString(AuthenticAacAbruptTerminationFixture.PHASE_ARGUMENT) ==
                AuthenticAacAbruptTerminationFixture.FORCE_STOP_RECOVER_PHASE,
        )
        val nonce = AuthenticAacAbruptTerminationFixture.requireNonce(arguments)
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val root = File(context.filesDir, FIXTURE_DIRECTORY)

        val report = AuthenticAacAbruptTerminationFixture.recoverAndVerify(root, nonce)

        assertEquals(256_000, report.sourceSamples)
        assertEquals(report.committedFrames * 1_024L, report.committedSamples)
        assertTrue("encoder coverage was ${report.encodedSampleCoverage}", report.encodedSampleCoverage >= 0.99)
        assertTrue("source-to-commit loss was ${report.sourceToCommittedLossUs} us", report.sourceToCommittedLossUs <= 5_000_000L)
    }

    companion object {
        const val FIXTURE_DIRECTORY = "authentic-aac-force-stop"
    }
}
