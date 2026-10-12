package com.loquiris.spike

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.lang.ref.Reference

@RunWith(AndroidJUnit4::class)
class AuthenticAacForceStopPreparationInstrumentedTest {
    @Test
    fun waitForHostForceStopAfterWritingAuthenticAacWithAnUncommittedTail() {
        val arguments = InstrumentationRegistry.getArguments()
        assumeTrue(
            arguments.getString(AuthenticAacAbruptTerminationFixture.PHASE_ARGUMENT) ==
                AuthenticAacAbruptTerminationFixture.FORCE_STOP_PREPARE_PHASE,
        )
        val nonce = AuthenticAacAbruptTerminationFixture.requireNonce(arguments)
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val root = File(context.filesDir, AuthenticAacForceStopRecoveryInstrumentedTest.FIXTURE_DIRECTORY)

        val store = AuthenticAacAbruptTerminationFixture.prepare(root, nonce)
        try {
            Thread.sleep(120_000L)
            Reference.reachabilityFence(store)
            error("Host did not force-stop the package before the timeout")
        } finally {
            store.close()
        }
    }
}
