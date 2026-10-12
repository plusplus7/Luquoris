package com.loquiris.spike

import android.os.Process
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.lang.ref.Reference

@RunWith(AndroidJUnit4::class)
class AuthenticAacProcessKillPreparationInstrumentedTest {
    @Test
    fun killProcessAfterWritingAuthenticAacWithAnUncommittedTail() {
        val arguments = InstrumentationRegistry.getArguments()
        assumeTrue(
            arguments.getString(AuthenticAacAbruptTerminationFixture.PHASE_ARGUMENT) ==
                AuthenticAacAbruptTerminationFixture.PREPARE_PHASE,
        )
        val nonce = AuthenticAacAbruptTerminationFixture.requireNonce(arguments)
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val root = File(context.filesDir, AuthenticAacProcessKillRecoveryInstrumentedTest.FIXTURE_DIRECTORY)

        val store = AuthenticAacAbruptTerminationFixture.prepare(root, nonce)

        Process.killProcess(Process.myPid())
        Reference.reachabilityFence(store)
        Thread.sleep(10_000L)
        error("Process.killProcess returned without terminating the process")
    }
}
