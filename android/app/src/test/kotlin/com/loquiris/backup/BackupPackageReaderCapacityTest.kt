package com.loquiris.backup

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class BackupPackageReaderCapacityTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `low space rejects a valid archive before staging payload`() {
        val root = temporaryFolder.newFolder("files")
        val archive = File(root, "backups/valid.zip").apply {
            parentFile!!.mkdirs()
            writeBytes(databaseOnlyArchive())
        }

        val result =
            BackupPackageReader(
                filesRoot = root,
                availableBytes = { 0L },
            ).verifyAndStage(
                BackupVerificationRequest(
                    operationId = "restore_low_space",
                    archiveRelativePath = "backups/valid.zip",
                    currentSchemaVersion = 4,
                ),
            )

        assertEquals(
            BackupVerificationResult.Failure("restore_insufficient_storage"),
            result,
        )
        assertFalse(File(root, "restore_staging/restore_low_space").exists())
        assertFalse(File(root, "restore_staging/.restore_low_space.tmp").exists())
    }

    private fun databaseOnlyArchive(): ByteArray {
        val output = ByteArrayOutputStream()
        val result =
            BackupPackageWriter().write(
                BackupPackageRequest(
                    formatVersion = 1,
                    schemaVersion = 4,
                    appVersion = "0.1.0+1",
                    exportedAtUtc = "2026-10-01T00:00:00.000Z",
                    sources =
                        listOf(
                            BackupPayloadSource("payload/database/loquiris.sqlite") {
                                ByteArrayInputStream("database".encodeToByteArray())
                            },
                        ),
                ),
                output,
            )
        assertTrue(result is BackupWriteResult.Success)
        return output.toByteArray()
    }
}
