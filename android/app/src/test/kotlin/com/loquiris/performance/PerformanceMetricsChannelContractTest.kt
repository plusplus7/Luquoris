package com.loquiris.performance

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PerformanceMetricsChannelContractTest {
    @Test
    fun `read snapshot accepts only version one`() {
        assertEquals(
            PerformanceMetricsRequest.ReadSnapshot,
            PerformanceMetricsChannelContract.decode(
                method = "readSnapshot",
                arguments = mapOf("v" to 1),
            ),
        )
        assertEquals(
            PerformanceMetricsRequest.Rejected("performance_metrics_request_invalid"),
            PerformanceMetricsChannelContract.decode(
                method = "readSnapshot",
                arguments = mapOf("v" to 2),
            ),
        )
        assertEquals(
            PerformanceMetricsRequest.Rejected("performance_metrics_request_invalid"),
            PerformanceMetricsChannelContract.decode(
                method = "readSnapshot",
                arguments = mapOf("v" to 1, "extra" to true),
            ),
        )
    }

    @Test
    fun `unsupported method and malformed request return stable failures`() {
        assertEquals(
            PerformanceMetricsRequest.Rejected("performance_metrics_method_unsupported"),
            PerformanceMetricsChannelContract.decode(
                method = "futureMethod",
                arguments = mapOf("v" to 1),
            ),
        )
        assertEquals(
            PerformanceMetricsRequest.Rejected("performance_metrics_request_invalid"),
            PerformanceMetricsChannelContract.decode(
                method = "readSnapshot",
                arguments = null,
            ),
        )

        val failure =
            PerformanceMetricsChannelContract.failure("performance_metrics_read_failed")
        assertEquals(
            mapOf(
                "v" to 1,
                "ok" to false,
                "failure" to mapOf("code" to "performance_metrics_read_failed"),
            ),
            failure,
        )
        assertEquals(setOf("v", "ok", "failure"), failure.keys)
    }

    @Test
    fun `success uses the fixed primitive snapshot shape`() {
        val response =
            PerformanceMetricsChannelContract.success(
                PerformanceMetricsSnapshot(
                    observedAtMonotonicMs = 11,
                    processCpuTimeMs = 12,
                    processPssBytes = 13,
                    thermalState = "warm",
                    remainingDeviceEnergyNanowattHours = null,
                    isCharging = true,
                ),
            )

        assertEquals(1, response["v"])
        assertEquals(true, response["ok"])
        assertEquals(
            mapOf(
                "observedAtMonotonicMs" to 11L,
                "processCpuTimeMs" to 12L,
                "processPssBytes" to 13L,
                "thermalState" to "warm",
                "remainingDeviceEnergyNanowattHours" to null,
                "isCharging" to true,
            ),
            response["snapshot"],
        )
        assertTrue(response.keys == setOf("v", "ok", "snapshot"))
    }
}
