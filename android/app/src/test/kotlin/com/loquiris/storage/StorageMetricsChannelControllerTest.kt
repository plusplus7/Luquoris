package com.loquiris.storage

import java.util.concurrent.Executor
import org.junit.Assert.assertEquals
import org.junit.Test

class StorageMetricsChannelControllerTest {
    private val direct = Executor { it.run() }

    @Test
    fun `measures off the caller executor and replies with metrics`() {
        val controller =
            StorageMetricsChannelController(
                executor = direct,
                replyExecutor = direct,
                reader =
                    StorageMetricsReader {
                        StorageMetricsReadResult.Success(
                            StorageMetricsObservation(1, 2, 3, 4),
                        )
                    },
            )
        var response: Any? = null

        controller.handle("measure", mapOf("v" to 1)) { response = it }

        assertEquals(true, (response as Map<*, *>)["ok"])
    }

    @Test
    fun `rejects malformed requests and unsupported methods`() {
        val controller =
            StorageMetricsChannelController(
                executor = direct,
                replyExecutor = direct,
                reader = StorageMetricsReader { error("must not measure") },
            )
        val responses = mutableListOf<Any?>()

        controller.handle("measure", mapOf("v" to 2), responses::add)
        controller.handle("future", mapOf("v" to 1), responses::add)

        assertEquals("storage_metrics_request_invalid", responses[0].failureCode())
        assertEquals("storage_metrics_method_unsupported", responses[1].failureCode())
    }

    @Test
    fun `returns a stable reader failure`() {
        val controller =
            StorageMetricsChannelController(
                executor = direct,
                replyExecutor = direct,
                reader =
                    StorageMetricsReader {
                        StorageMetricsReadResult.Failure("storage_stats_unavailable")
                    },
            )
        var response: Any? = null

        controller.handle("measure", mapOf("v" to 1)) { response = it }

        assertEquals("storage_stats_unavailable", response.failureCode())
    }

    @Test
    fun `clears rebuildable cache on the worker executor`() {
        var cleanupCalls = 0
        val controller =
            StorageMetricsChannelController(
                executor = direct,
                replyExecutor = direct,
                reader = StorageMetricsReader { error("must not measure") },
                cleanup =
                    RebuildableCacheCleanup {
                        cleanupCalls += 1
                        RebuildableCacheCleanupResult.Success(
                            RebuildableCacheCleanupReceipt(2, 12L),
                        )
                    },
            )
        var response: Any? = null

        controller.handle("clearRebuildableCache", mapOf("v" to 1)) { response = it }

        assertEquals(1, cleanupCalls)
        assertEquals(true, (response as Map<*, *>)["ok"])
        assertEquals(12L, ((response as Map<*, *>)["receipt"] as Map<*, *>)["bytesDeleted"])
    }

    @Test
    fun `preserves partial cleanup counts in a typed failure`() {
        val controller =
            StorageMetricsChannelController(
                executor = direct,
                replyExecutor = direct,
                reader = StorageMetricsReader { error("must not measure") },
                cleanup =
                    RebuildableCacheCleanup {
                        RebuildableCacheCleanupResult.Failure(
                            code = "rebuildable_cache_cleanup_failed",
                            filesDeleted = 1,
                            bytesDeleted = 7L,
                        )
                    },
            )
        var response: Any? = null

        controller.handle("clearRebuildableCache", mapOf("v" to 1)) { response = it }

        assertEquals("rebuildable_cache_cleanup_failed", response.failureCode())
        val failure = (response as Map<*, *>)["failure"] as Map<*, *>
        assertEquals(1, failure["filesDeleted"])
        assertEquals(7L, failure["bytesDeleted"])
    }
}

private fun Any?.failureCode(): Any? =
    (((this as Map<*, *>)["failure"] as Map<*, *>)["code"])
