package com.loquiris.spike

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AdtsDurabilityBudgetTest {
    @Test
    fun `measured commit time is included in the recoverable loss budget`() {
        val budget =
            AdtsDurabilityBudget.evaluate(
                maximumUncommittedFrames = 75,
                frameDurationUs = 64_000L,
                maximumCommitSyncUs = 5_902L,
            )

        assertEquals(4_805_902L, budget.measuredRiskWindowUs)
        assertEquals(194_098L, budget.remainingHeadroomUs)
        assertTrue(budget.hasRequiredUnmeasuredHeadroom)
    }

    @Test
    fun `eight milliseconds of raw headroom fails the unmeasured margin gate`() {
        val budget =
            AdtsDurabilityBudget.evaluate(
                maximumUncommittedFrames = 78,
                frameDurationUs = 64_000L,
                maximumCommitSyncUs = 5_902L,
            )

        assertEquals(4_997_902L, budget.measuredRiskWindowUs)
        assertTrue(!budget.hasRequiredUnmeasuredHeadroom)
    }
}
