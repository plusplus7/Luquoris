package com.loquiris.spike

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class M4aRebuildSpikeInstrumentedTest {
    @Test
    fun authoritativeAccessUnitsRebuildContinuousM4aAcrossCommitBoundaries() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext

        val rebuiltM4a = File(context.cacheDir, REBUILT_M4A_NAME)
        val report = M4aRebuildSpike().run(rebuiltM4a)
        val reportJson = report.toJson()
        File(context.filesDir, REPORT_NAME).writeText(reportJson)
        InstrumentationRegistry.getArguments().getString("additionalTestOutputDir")?.let { outputPath ->
            val outputDirectory = File(outputPath)
            check(outputDirectory.mkdirs() || outputDirectory.isDirectory)
            File(outputDirectory, REPORT_NAME).writeText(reportJson)
            rebuiltM4a.copyTo(File(outputDirectory, REBUILT_M4A_NAME), overwrite = true)
        }

        assertEquals(4_750, report.sourceAccessUnits)
        assertTrue(report.sourceWasSingleContinuousEncode)
        assertEquals(4_864_000, report.sourcePcmSamples)
        assertTrue(report.sourceEncodeElapsedMilliseconds > 0L)
        assertEquals(report.sourceAccessUnits, report.extractedAccessUnits)
        assertEquals(2, report.authoritativeSegmentFiles)
        assertEquals(listOf(0, 1), report.manifestDiscoveredSegmentIndices)
        assertEquals(listOf(4_650, 100), report.recoveredSegmentFrameCounts)
        assertEquals(listOf(4_761_600L, 102_400L), report.recoveredCommittedSamples)
        assertTrue(report.recoveredSegmentPayloadsMatchTimeline)
        assertTrue(report.unpublishedRotationSegmentWasIgnored)
        assertEquals(3, report.manifestDirectorySyncCount)
        assertEquals(63, report.commitBoundaryCount)
        assertEquals(listOf(4_650), report.calculatedLogicalBoundaryFrameIndices)
        assertEquals(304_000L, report.containerDurationMilliseconds)
        assertTrue(
            "extractor duration was ${report.extractorDurationMilliseconds} ms",
            report.extractorDurationMilliseconds in 303_800L..304_100L,
        )
        assertTrue(report.payloadsMatch)
        assertTrue(report.allTimestampsMatchCumulativeSamples)
        assertEquals(0L, report.firstPresentationTimeMicroseconds)
        assertEquals(303_936_000L, report.lastPresentationTimeMicroseconds)
        assertEquals(64_000L, report.maximumTimestampDeltaMicroseconds)
        assertTrue(report.timestampsStrictlyIncrease)
        assertTrue(report.commitBoundaryTimestampsMatch)
        assertEquals(16_000, report.extractedSampleRateHz)
        assertEquals(1, report.extractedChannelCount)
        assertTrue("container coverage was ${report.containerSampleCoverage}", report.containerSampleCoverage in 0.99..1.01)
        assertTrue("decoder coverage was ${report.decodedSampleCoverage}", report.decodedSampleCoverage in 0.98..1.02)
        assertTrue(
            "platform player duration was ${report.platformPlayerDurationMilliseconds} ms",
            report.platformPlayerDurationMilliseconds in 303_800L..304_100L,
        )
        assertEquals(listOf(0, 4_800, 297_600, 302_000), report.platformPlayerSeekTargetsMilliseconds)
        assertTrue(report.platformPlayerDecodedAllProbePositions)
        assertTrue(report.rebuiltBytes > 0L)
    }

    companion object {
        private const val REPORT_NAME = "m4a-rebuild-spike-report.json"
        private const val REBUILT_M4A_NAME = "m4a-rebuild-spike.m4a"
    }
}
