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
class AdtsForceStopRecoveryInstrumentedTest {
    @Test
    fun forceStopPreservesTheLastDurablePrefixWithinFiveSeconds() {
        assumeTrue(
            InstrumentationRegistry.getArguments().getString(AdtsAbruptTerminationFixture.PHASE_ARGUMENT) ==
                "force-stop-recover",
        )
        val expectedNonce = AdtsAbruptTerminationFixture.requireNonce(InstrumentationRegistry.getArguments())
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val root = File(context.filesDir, FIXTURE_DIRECTORY)
        val dataFile = File(root, AdtsAbruptTerminationFixture.DATA_FILE)
        val journalFile = File(root, AdtsAbruptTerminationFixture.JOURNAL_FILE)
        val markerFile = File(root, AdtsAbruptTerminationFixture.MARKER_FILE)

        assertTrue("Missing force-stop data fixture", dataFile.isFile)
        assertTrue("Missing force-stop journal fixture", journalFile.isFile)
        assertTrue("Missing force-stop completion marker", markerFile.isFile)

        val marker = AdtsAbruptTerminationFixture.readMarker(markerFile)
        assertEquals(expectedNonce, marker.nonce)
        assertEquals(AdtsAbruptTerminationFixture.GENERATED_FRAMES, marker.generatedFrames)
        assertEquals(AdtsAbruptTerminationFixture.COMMITTED_FRAMES, marker.committedFrames)
        assertEquals(marker.generatedBytes.toLong(), dataFile.length())
        val recovered =
            AdtsCommittedPrefixRecovery.recover(
                dataBytes = dataFile.readBytes(),
                journalBytes = journalFile.readBytes(),
            )
        val lossUs =
            (marker.generatedFrames - recovered.committedFrames).toLong() *
                AdtsAbruptTerminationFixture.FRAME_DURATION_US

        assertEquals(150, recovered.committedFrames)
        assertEquals(19_200, recovered.committedBytes)
        assertEquals(153_600L, recovered.committedSamples)
        assertTrue("Force-stop loss was $lossUs us", lossUs <= AdtsAbruptTerminationFixture.FIVE_SECONDS_US)
        assertTrue("Unable to consume force-stop marker", markerFile.delete())
    }

    companion object {
        const val FIXTURE_DIRECTORY = "adts-force-stop"
    }
}
