package com.loquiris.performance

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class PerformanceMetricsReaderTest {
    @Test
    fun `thermal statuses map to coarse states`() {
        val expected =
            mapOf(
                0 to "nominal",
                1 to "nominal",
                2 to "warm",
                3 to "hot",
                4 to "critical",
                5 to "critical",
                6 to "critical",
                99 to "unknown",
            )

        expected.forEach { (status, state) ->
            assertEquals(state, reader(thermalStatus = { status }).readSnapshot().thermalState)
        }
    }

    @Test
    fun `pss kilobytes convert to bytes with overflow rejection`() {
        assertEquals(
            42L * 1024L,
            reader(processPssKilobytes = { 42L }).readSnapshot().processPssBytes,
        )
        assertThrows(ArithmeticException::class.java) {
            reader(processPssKilobytes = { Long.MAX_VALUE }).readSnapshot()
        }
    }

    @Test
    fun `unsupported or negative energy becomes null`() {
        assertNull(
            reader(remainingEnergy = { -1L })
                .readSnapshot()
                .remainingDeviceEnergyNanowattHours,
        )
        assertNull(
            reader(remainingEnergy = { throw UnsupportedOperationException("unsupported") })
                .readSnapshot()
                .remainingDeviceEnergyNanowattHours,
        )
        assertEquals(
            123L,
            reader(remainingEnergy = { 123L })
                .readSnapshot()
                .remainingDeviceEnergyNanowattHours,
        )
    }

    private fun reader(
        thermalStatus: () -> Int = { 0 },
        processPssKilobytes: () -> Long = { 3L },
        remainingEnergy: () -> Long = { 4L },
    ): PerformanceMetricsReader =
        PerformanceMetricsReader(
            observedAtMonotonicMs = { 1L },
            processCpuTimeMs = { 2L },
            processPssKilobytes = processPssKilobytes,
            thermalStatus = thermalStatus,
            remainingDeviceEnergyNanowattHours = remainingEnergy,
            isCharging = { true },
        )
}
