package com.loquiris.spike

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class AuthenticAacTruncationMatrixInstrumentedTest {
    @Test
    fun authenticAacControlledTruncationsRecoverDecodablePrefixWithinFiveSeconds() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val root = File(context.filesDir, "authentic-aac-truncation-matrix")

        val report = AuthenticAacTruncationMatrixSpike(root).run()
        val reportJson = report.toJson()

        File(context.filesDir, REPORT_NAME).writeText(reportJson)
        InstrumentationRegistry.getArguments().getString("additionalTestOutputDir")?.let { outputPath ->
            val outputDirectory = File(outputPath)
            check(outputDirectory.mkdirs() || outputDirectory.isDirectory)
            File(outputDirectory, REPORT_NAME).writeText(reportJson)
        }
        assertEquals(
            setOf(
                "truncate_tail_after_commit_by_one_byte",
                "truncate_tail_mid_frame",
                "truncate_tail_at_frame_boundary",
                "truncate_latest_journal_record",
                "truncate_latest_committed_frame",
            ),
            report.scenarios.map(AuthenticAacTruncationScenario::name).toSet(),
        )
        assertTrue(
            "Authentic AAC truncation exceeded the five-second recovery gate: ${report.toJson()}",
            report.durabilityBudget.hasRequiredUnmeasuredHeadroom,
        )
        assertTrue(
            "A controlled truncation recovered the wrong AAC prefix: ${report.toJson()}",
            report.scenarios.all(AuthenticAacTruncationScenario::recoveredPrefixMatches),
        )
        assertTrue(
            "A recovered AAC prefix was not decodable: ${report.toJson()}",
            report.scenarios.all { scenario ->
                scenario.decodedSampleCoverage in 0.90..1.10 && scenario.decodedRms > 100.0
            },
        )
        assertTrue(
            "A recovered sample watermark disagreed with its frame count: ${report.toJson()}",
            report.scenarios.all(AuthenticAacTruncationScenario::committedSamplesMatchFrames),
        )
        assertTrue(
            "A scenario decoded without reloading persisted codec metadata: ${report.toJson()}",
            report.scenarios.all(AuthenticAacTruncationScenario::codecConfigReloadedFromDisk),
        )

        val byName = report.scenarios.associateBy(AuthenticAacTruncationScenario::name)
        val afterCommit = checkNotNull(byName["truncate_tail_after_commit_by_one_byte"])
        assertEquals(afterCommit.recoveredBytes + 1, afterCommit.observedDataBytes)
        assertEquals(150, afterCommit.completeFramesAfterTruncation)
        assertEquals(1, afterCommit.trailingBytesAfterTruncation)

        val midFrame = checkNotNull(byName["truncate_tail_mid_frame"])
        assertEquals(187, midFrame.completeFramesAfterTruncation)
        assertTrue(midFrame.trailingBytesAfterTruncation > 0)

        val frameBoundary = checkNotNull(byName["truncate_tail_at_frame_boundary"])
        assertEquals(187, frameBoundary.completeFramesAfterTruncation)
        assertEquals(0, frameBoundary.trailingBytesAfterTruncation)

        val journalTear = checkNotNull(byName["truncate_latest_journal_record"])
        assertEquals(journalTear.originalDataBytes, journalTear.observedDataBytes)
        assertEquals(1, journalTear.originalJournalBytes - journalTear.observedJournalBytes)
        assertEquals(225, journalTear.completeFramesAfterTruncation)

        val committedFrameTear = checkNotNull(byName["truncate_latest_committed_frame"])
        assertEquals(1, committedFrameTear.originalDataBytes - committedFrameTear.observedDataBytes)
        assertEquals(committedFrameTear.originalJournalBytes, committedFrameTear.observedJournalBytes)
        assertEquals(224, committedFrameTear.completeFramesAfterTruncation)
        assertTrue(committedFrameTear.trailingBytesAfterTruncation > 0)
    }

    companion object {
        private const val REPORT_NAME = "authentic-aac-truncation-matrix-report.json"
    }
}
