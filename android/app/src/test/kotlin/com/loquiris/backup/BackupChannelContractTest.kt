package com.loquiris.backup

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BackupChannelContractTest {
    @Test
    fun `decodes bounded backup request`() {
        val result =
            BackupChannelContract.decodeRequest(
                mapOf(
                    "v" to 1,
                    "operationId" to "backup_1",
                    "schemaVersion" to 4,
                    "exportedAtUtc" to "2026-10-01T00:00:00.000Z",
                    "snapshotRelativePath" to "backup_staging/backup_1.sqlite",
                    "audioPlan" to
                        listOf(
                            mapOf(
                                "relativePath" to "recordings/${"a".repeat(64)}/segment-00000.adts",
                                "committedBytes" to 42L,
                            ),
                        ),
                ),
            )

        val request = (result as BackupRequestDecodeResult.Success).request
        assertEquals("backup_1", request.operationId)
        assertEquals(42L, request.audioPlan.single().committedBytes)
    }

    @Test
    fun `rejects unknown fields by type and unbounded plans`() {
        assertTrue(BackupChannelContract.decodeRequest(null) is BackupRequestDecodeResult.Failure)
        assertTrue(
            BackupChannelContract.decodeRequest(
                mapOf(
                    "v" to 1,
                    "operationId" to "backup_1",
                    "schemaVersion" to 4,
                    "exportedAtUtc" to "bad",
                    "snapshotRelativePath" to "../database.sqlite",
                    "audioPlan" to emptyList<Any>(),
                ),
            ) is BackupRequestDecodeResult.Failure,
        )
    }

    @Test
    fun `decodes restore verification request`() {
        val result =
            BackupChannelContract.decodeVerificationRequest(
                mapOf(
                    "v" to 1,
                    "operationId" to "restore_1",
                    "archiveRelativePath" to "backups/loquiris-backup-backup_1.zip",
                    "currentSchemaVersion" to 4,
                ),
            )

        val request = (result as BackupVerificationDecodeResult.Success).request
        assertEquals("restore_1", request.operationId)
        assertEquals(4, request.currentSchemaVersion)
    }

    @Test
    fun `decodes bounded restore recording operations`() {
        val transfer =
            BackupChannelContract.decodeRecordingTransfer(
                mapOf(
                    "v" to 1,
                    "operationId" to "restore_1",
                    "sourceMeetingId" to "meeting-a",
                    "targetMeetingId" to "meeting-copy",
                    "contentFingerprint" to "a".repeat(64),
                ),
            )

        assertEquals("meeting-copy", transfer!!.targetMeetingId)
        assertEquals(
            listOf("meeting-a", "meeting-copy"),
            BackupChannelContract.decodeMeetingIds(
                mapOf(
                    "v" to 1,
                    "meetingIds" to listOf("meeting-a", "meeting-copy"),
                ),
            ),
        )
        assertEquals(
            "restore_1",
            BackupChannelContract.decodeOperationId(
                mapOf("v" to 1, "operationId" to "restore_1"),
            ),
        )
    }
}
