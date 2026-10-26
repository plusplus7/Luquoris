package com.loquiris.transcription

import org.junit.Assert.*
import org.junit.Test

class RefinementResourceGuardTest {
    @Test fun `repeated chunk checks cache platform reads for one second`() {
        var now = 0L
        var reads = 0
        var snapshot = RefinementResourceSnapshot(0, false, false, 80, false)
        val guard = RefinementResourceGuard({ reads++; snapshot }, { AutoCloseable {} }, { now })
        repeat(1000) { assertNull(guard.pauseReason()) }
        assertEquals(1, reads)
        snapshot = snapshot.copy(lowMemory = true)
        now = 999
        assertNull(guard.pauseReason())
        now = 1000
        assertEquals("refinement_memory_pressure", guard.pauseReason())
        snapshot = snapshot.copy(lowMemory = false)
        now = 2000
        assertNull(guard.pauseReason())
    }

    @Test fun `new observer invalidates old healthy cache and propagates immediate signals without reading`() {
        var reads = 0
        var snapshot = RefinementResourceSnapshot(0, false, false, 80, false)
        var callback: ((String) -> Unit)? = null
        val guard = RefinementResourceGuard({ reads++; snapshot }, { callback = it; AutoCloseable { callback = null } }, { 0 })
        assertNull(guard.pauseReason())
        snapshot = snapshot.copy(thermalStatus = 3)
        val reasons = mutableListOf<String>()
        val owner = guard.observe(reasons::add)
        assertEquals("refinement_thermal_severe", guard.pauseReason())
        val readsBeforeCallback = reads
        callback!!("refinement_battery_low")
        assertEquals(listOf("refinement_battery_low"), reasons)
        assertEquals(readsBeforeCallback, reads)
        owner.close()
        assertNull(callback)
    }

    @Test fun `sensor exceptions fail closed and allow subsequent explicit resume`() {
        var now = 0L
        var broken = true
        val guard = RefinementResourceGuard({
            if (broken) throw SecurityException("private")
            RefinementResourceSnapshot(0, false, false, 80, false)
        }, { AutoCloseable {} }, { now })
        assertEquals("refinement_resources_unavailable", guard.pauseReason())
        broken = false
        now = 1000
        assertNull(guard.pauseReason())
    }
}
