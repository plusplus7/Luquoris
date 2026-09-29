package com.loquiris.spike

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.lang.ref.Reference

@RunWith(AndroidJUnit4::class)
class AdtsForceStopPreparationInstrumentedTest {
    @Test
    fun waitForHostForceStopWithACommittedPrefixAndUncommittedTail() {
        assumeTrue(
            InstrumentationRegistry.getArguments().getString(AdtsAbruptTerminationFixture.PHASE_ARGUMENT) ==
                "force-stop-prepare",
        )
        val nonce = AdtsAbruptTerminationFixture.requireNonce(InstrumentationRegistry.getArguments())
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val root = File(context.filesDir, AdtsForceStopRecoveryInstrumentedTest.FIXTURE_DIRECTORY)
        check(!root.exists() || root.deleteRecursively()) { "Unable to clear force-stop fixture" }
        check(root.mkdirs()) { "Unable to create force-stop fixture" }
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

        Thread.sleep(120_000L)
        Reference.reachabilityFence(store)
        error("Host did not force-stop the package before the timeout")
    }
}
