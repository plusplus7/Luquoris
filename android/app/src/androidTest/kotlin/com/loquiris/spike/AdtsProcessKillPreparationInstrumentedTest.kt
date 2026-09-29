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
class AdtsProcessKillPreparationInstrumentedTest {
    @Test
    fun killProcessWithACommittedPrefixAndUncommittedTail() {
        assumeTrue(
            InstrumentationRegistry.getArguments().getString(AdtsAbruptTerminationFixture.PHASE_ARGUMENT) ==
                "process-kill-prepare",
        )
        val nonce = AdtsAbruptTerminationFixture.requireNonce(InstrumentationRegistry.getArguments())
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val root = File(context.filesDir, AdtsProcessKillRecoveryInstrumentedTest.FIXTURE_DIRECTORY)
        check(!root.exists() || root.deleteRecursively()) { "Unable to clear process-death fixture" }
        check(root.mkdirs()) { "Unable to create process-death fixture" }
        val dataFile = File(root, AdtsAbruptTerminationFixture.DATA_FILE).apply { createNewFile() }
        val journalFile = File(root, AdtsAbruptTerminationFixture.JOURNAL_FILE).apply { createNewFile() }

        val store = AdtsDurableCommitStore.open(dataFile, journalFile)
        repeat(AdtsAbruptTerminationFixture.GENERATED_FRAMES) { frameIndex ->
            store.appendFrame(
                frame = AdtsAbruptTerminationFixture.syntheticFrame(frameIndex),
                mediaSamples = AdtsAbruptTerminationFixture.SAMPLES_PER_FRAME,
            )
            if ((frameIndex + 1) % AdtsAbruptTerminationFixture.FRAMES_PER_COMMIT == 0) {
                store.commit()
            }
        }
        AdtsAbruptTerminationFixture.writeMarker(
            File(root, AdtsAbruptTerminationFixture.MARKER_FILE),
            nonce,
        )

        Process.killProcess(Process.myPid())
        Reference.reachabilityFence(store)
        Thread.sleep(10_000L)
        error("Process.killProcess returned without terminating the process")
    }
}
