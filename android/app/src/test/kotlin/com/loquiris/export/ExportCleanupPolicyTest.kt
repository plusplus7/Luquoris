package com.loquiris.export

import org.junit.Assert.assertEquals
import org.junit.Test

class ExportCleanupPolicyTest {
    @Test
    fun `cleanup refusal identifies that incomplete output may remain`() {
        assertEquals(
            "export_incomplete_output_cleanup_failed",
            ExportCleanupPolicy.failureCode(
                originalCode = "export_cancelled",
                destinationDeleted = false,
            ),
        )
    }

    @Test
    fun `successful cleanup preserves the original structured failure`() {
        assertEquals(
            "export_destination_write_failed",
            ExportCleanupPolicy.failureCode(
                originalCode = "export_destination_write_failed",
                destinationDeleted = true,
            ),
        )
    }
}
