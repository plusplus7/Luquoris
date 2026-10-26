package com.loquiris.transcription

import org.junit.Assert.*
import org.junit.Test

class RefinementResourcePolicyTest {
    private val healthy = RefinementResourceSnapshot(0, false, false, 80, false)

    @Test fun `healthy resources permit optional work`() {
        assertNull(RefinementResourcePolicy.pauseReason(healthy))
        assertNull(RefinementResourcePolicy.pauseReason(healthy.copy(thermalStatus = 2)))
        assertNull(RefinementResourcePolicy.pauseReason(healthy.copy(batteryPercent = 16)))
        assertNull(RefinementResourcePolicy.pauseReason(healthy.copy(batteryPercent = 1, charging = true)))
    }

    @Test fun `memory pressure thresholds include intermediate and future levels but not hidden UI`() {
        for (level in listOf(0, 5, 9, 20, 40, 59)) assertNull(RefinementResourcePolicy.memoryTrimPauseReason(level))
        for (level in listOf(10, 11, 15, 19, 60, 70, 80, 90)) {
            assertEquals("refinement_memory_pressure", RefinementResourcePolicy.memoryTrimPauseReason(level))
        }
    }

    @Test fun `unsafe resources defer with stable reasons`() {
        for (status in 3..6) assertEquals("refinement_thermal_severe", RefinementResourcePolicy.pauseReason(healthy.copy(thermalStatus = status)))
        assertEquals("refinement_memory_pressure", RefinementResourcePolicy.pauseReason(healthy.copy(lowMemory = true)))
        assertEquals("refinement_power_save", RefinementResourcePolicy.pauseReason(healthy.copy(powerSave = true)))
        assertEquals("refinement_battery_low", RefinementResourcePolicy.pauseReason(healthy.copy(batteryPercent = 15)))
        assertEquals("refinement_battery_low", RefinementResourcePolicy.pauseReason(healthy.copy(batteryPercent = 0)))
    }

    @Test fun `missing or invalid platform observations never authorize allocation`() {
        val unknown = listOf(
            healthy.copy(thermalStatus = null), healthy.copy(thermalStatus = -1), healthy.copy(thermalStatus = 7),
            healthy.copy(lowMemory = null), healthy.copy(powerSave = null), healthy.copy(batteryPercent = null),
            healthy.copy(batteryPercent = -1), healthy.copy(batteryPercent = 101), healthy.copy(charging = null),
        )
        for (snapshot in unknown) assertEquals("refinement_resources_unavailable", RefinementResourcePolicy.pauseReason(snapshot))
    }
}
