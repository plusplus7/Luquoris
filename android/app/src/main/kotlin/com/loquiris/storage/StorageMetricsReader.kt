package com.loquiris.storage

import android.app.usage.StorageStatsManager
import android.content.Context
import android.os.Process

fun interface StorageMetricsReader {
    fun measure(): StorageMetricsReadResult
}

sealed interface StorageMetricsReadResult {
    data class Success(
        val metrics: StorageMetricsObservation,
    ) : StorageMetricsReadResult

    data class Failure(
        val code: String,
    ) : StorageMetricsReadResult
}

class AndroidStorageMetricsReader(
    context: Context,
) : StorageMetricsReader {
    private val applicationContext = context.applicationContext

    override fun measure(): StorageMetricsReadResult =
        try {
            val manager = applicationContext.getSystemService(StorageStatsManager::class.java)
            val storageUuid = applicationContext.applicationInfo.storageUuid
            val stats = manager.queryStatsForUid(storageUuid, Process.myUid())
            StorageMetricsReadResult.Success(
                StorageMetricsObservation(
                    appBytes = stats.appBytes,
                    dataBytes = stats.dataBytes,
                    cacheBytes = stats.cacheBytes,
                    availableBytes = manager.getFreeBytes(storageUuid),
                ),
            )
        } catch (_: Exception) {
            StorageMetricsReadResult.Failure("storage_stats_unavailable")
        }
}
