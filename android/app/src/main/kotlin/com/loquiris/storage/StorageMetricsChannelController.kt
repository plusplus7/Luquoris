package com.loquiris.storage

import android.content.Context
import java.util.concurrent.Executor

class StorageMetricsChannelController internal constructor(
    private val executor: Executor,
    private val replyExecutor: Executor,
    private val reader: StorageMetricsReader,
    private val cleanup: RebuildableCacheCleanup =
        RebuildableCacheCleanup {
            RebuildableCacheCleanupResult.Failure(
                code = "rebuildable_cache_cleanup_unavailable",
                filesDeleted = 0,
                bytesDeleted = 0,
            )
        },
) {
    constructor(
        context: Context,
        executor: Executor,
        replyExecutor: Executor,
    ) : this(
        executor = executor,
        replyExecutor = replyExecutor,
        reader = AndroidStorageMetricsReader(context),
        cleanup = RebuildableCacheCleaner(context.applicationContext.cacheDir),
    )

    fun handle(
        method: String,
        arguments: Any?,
        reply: (Any?) -> Unit,
    ) {
        if (!StorageMetricsChannelContract.isMeasureRequest(arguments)) {
            reply(StorageMetricsChannelContract.failure("storage_metrics_request_invalid"))
            return
        }
        when (method) {
            "measure" ->
                execute(reply) {
                    when (val result = reader.measure()) {
                        is StorageMetricsReadResult.Success ->
                            StorageMetricsChannelContract.success(result.metrics)
                        is StorageMetricsReadResult.Failure ->
                            StorageMetricsChannelContract.failure(result.code)
                    }
                }
            "clearRebuildableCache" ->
                execute(reply) {
                    when (val result = cleanup.clear()) {
                        is RebuildableCacheCleanupResult.Success ->
                            StorageMetricsChannelContract.cleanupSuccess(result.receipt)
                        is RebuildableCacheCleanupResult.Failure ->
                            StorageMetricsChannelContract.cleanupFailure(result)
                    }
                }
            else -> reply(StorageMetricsChannelContract.failure("storage_metrics_method_unsupported"))
        }
    }

    private fun execute(
        reply: (Any?) -> Unit,
        operation: () -> Map<String, Any>,
    ) {
        executor.execute {
            val response = operation()
            replyExecutor.execute { reply(response) }
        }
    }
}
