package com.loquiris.spike

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class AdtsDurabilitySpikeInstrumentedTest {
    @Test
    fun syntheticCommitAndTailTruncationMatrixStaysInsideFiveSeconds() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext

        val report = AdtsDurabilitySpike(File(context.filesDir, "adts-durability-spike")).run()

        File(context.filesDir, REPORT_NAME).writeText(report.toJson())
        assertTrue("No durability scenarios ran: ${report.toJson()}", report.scenarios.isNotEmpty())
        assertTrue("No durable commits were measured: ${report.toJson()}", report.commitSyncMicros.isNotEmpty())
        assertTrue(
            "Synthetic recovery budget left insufficient unmeasured headroom: ${report.toJson()}",
            report.durabilityBudget.hasRequiredUnmeasuredHeadroom,
        )
        assertTrue(
            "A synthetic crash-tail scenario lost committed data: ${report.toJson()}",
            report.scenarios.all(AdtsDurabilityScenario::committedPrefixPreserved),
        )
    }

    companion object {
        private const val REPORT_NAME = "adts-durability-spike-report.json"
    }
}
