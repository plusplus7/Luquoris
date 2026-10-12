package com.loquiris.storage

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StorageMetricsChannelContractTest {
    @Test
    fun `accepts only the versioned measure request`() {
        assertTrue(StorageMetricsChannelContract.isMeasureRequest(mapOf("v" to 1)))
        assertFalse(StorageMetricsChannelContract.isMeasureRequest(mapOf("v" to 2)))
        assertFalse(StorageMetricsChannelContract.isMeasureRequest(null))
    }

    @Test
    fun `encodes non-negative metrics in a versioned envelope`() {
        val response =
            StorageMetricsChannelContract.success(
                StorageMetricsObservation(
                    appBytes = 1L,
                    dataBytes = 2L,
                    cacheBytes = 3L,
                    availableBytes = 4L,
                ),
            )

        assertEquals(1, response["v"])
        assertEquals(true, response["ok"])
        assertEquals(
            mapOf(
                "appBytes" to 1L,
                "dataBytes" to 2L,
                "cacheBytes" to 3L,
                "availableBytes" to 4L,
            ),
            response["metrics"],
        )
    }

    @Test
    fun `encodes cache cleanup receipts without exposing paths`() {
        val response =
            StorageMetricsChannelContract.cleanupSuccess(
                RebuildableCacheCleanupReceipt(filesDeleted = 3, bytesDeleted = 42L),
            )

        assertEquals(1, response["v"])
        assertEquals(true, response["ok"])
        val receipt = response["receipt"] as Map<*, *>
        assertEquals(3, receipt["filesDeleted"])
        assertEquals(42L, receipt["bytesDeleted"])
        assertFalse(response.toString().contains("path", ignoreCase = true))
    }
}
