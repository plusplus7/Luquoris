package com.loquiris.storage

data class StorageMetricsObservation(
    val appBytes: Long,
    val dataBytes: Long,
    val cacheBytes: Long,
    val availableBytes: Long,
) {
    init {
        require(appBytes >= 0 && dataBytes >= 0 && cacheBytes >= 0 && availableBytes >= 0)
    }
}

object StorageMetricsChannelContract {
    const val channelName = "com.loquiris/storage_metrics_v1"
    private const val version = 1

    fun isMeasureRequest(arguments: Any?): Boolean =
        (arguments as? Map<*, *>)?.get("v") == version

    fun success(metrics: StorageMetricsObservation): Map<String, Any> =
        mapOf(
            "v" to version,
            "ok" to true,
            "metrics" to
                mapOf(
                    "appBytes" to metrics.appBytes,
                    "dataBytes" to metrics.dataBytes,
                    "cacheBytes" to metrics.cacheBytes,
                    "availableBytes" to metrics.availableBytes,
                ),
        )

    fun cleanupSuccess(receipt: RebuildableCacheCleanupReceipt): Map<String, Any> =
        mapOf(
            "v" to version,
            "ok" to true,
            "receipt" to
                mapOf(
                    "filesDeleted" to receipt.filesDeleted,
                    "bytesDeleted" to receipt.bytesDeleted,
                ),
        )

    fun cleanupFailure(result: RebuildableCacheCleanupResult.Failure): Map<String, Any> =
        mapOf(
            "v" to version,
            "ok" to false,
            "failure" to
                mapOf(
                    "code" to result.code,
                    "filesDeleted" to result.filesDeleted,
                    "bytesDeleted" to result.bytesDeleted,
                ),
        )

    fun failure(code: String): Map<String, Any> =
        mapOf("v" to version, "ok" to false, "failure" to mapOf("code" to code))
}
