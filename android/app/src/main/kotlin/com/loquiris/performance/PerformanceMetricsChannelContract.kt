package com.loquiris.performance

data class PerformanceMetricsSnapshot(
    val observedAtMonotonicMs: Long,
    val processCpuTimeMs: Long,
    val processPssBytes: Long,
    val thermalState: String,
    val remainingDeviceEnergyNanowattHours: Long?,
    val isCharging: Boolean,
)

sealed interface PerformanceMetricsRequest {
    data object ReadSnapshot : PerformanceMetricsRequest

    data class Rejected(
        val code: String,
    ) : PerformanceMetricsRequest
}

object PerformanceMetricsChannelContract {
    const val channelName = "com.loquiris/performance_metrics_v1"
    private const val version = 1

    fun decode(
        method: String,
        arguments: Any?,
    ): PerformanceMetricsRequest {
        if (method != "readSnapshot") {
            return PerformanceMetricsRequest.Rejected(
                "performance_metrics_method_unsupported",
            )
        }
        val request = arguments as? Map<*, *>
        if (request == null || request.keys != setOf("v") || request["v"] != version) {
            return PerformanceMetricsRequest.Rejected(
                "performance_metrics_request_invalid",
            )
        }
        return PerformanceMetricsRequest.ReadSnapshot
    }

    fun success(snapshot: PerformanceMetricsSnapshot): Map<String, Any?> =
        mapOf(
            "v" to version,
            "ok" to true,
            "snapshot" to
                mapOf(
                    "observedAtMonotonicMs" to snapshot.observedAtMonotonicMs,
                    "processCpuTimeMs" to snapshot.processCpuTimeMs,
                    "processPssBytes" to snapshot.processPssBytes,
                    "thermalState" to snapshot.thermalState,
                    "remainingDeviceEnergyNanowattHours" to
                        snapshot.remainingDeviceEnergyNanowattHours,
                    "isCharging" to snapshot.isCharging,
                ),
        )

    fun failure(code: String): Map<String, Any> =
        mapOf(
            "v" to version,
            "ok" to false,
            "failure" to mapOf("code" to code),
        )
}
