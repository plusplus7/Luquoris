package com.loquiris.backup

import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest
import java.util.zip.ZipFile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class BackupArchivePublisherTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `publishes synced complete archive atomically and removes snapshot`() {
        val root = temporaryFolder.newFolder("files")
        val snapshot = File(root, "backup_staging/backup_1.sqlite").apply {
            parentFile!!.mkdirs()
            writeText("sqlite")
        }
        val operations = FakeBackupFileOperations()
        val publisher =
            BackupArchivePublisher(
                filesRoot = root,
                appVersion = "1.0.0+1",
                fileOperations = operations,
            )

        val result =
            publisher.create(
                BackupArchiveRequest(
                    operationId = "backup_1",
                    schemaVersion = 4,
                    exportedAtUtc = "2026-10-01T00:00:00.000Z",
                    snapshotRelativePath = "backup_staging/backup_1.sqlite",
                    audioPlan = emptyList(),
                ),
            )

        val success = result as BackupArchiveResult.Success
        val archive = File(root, success.relativePath)
        assertTrue(archive.isFile)
        assertEquals(archive.length(), success.bytes)
        assertEquals(
            MessageDigest
                .getInstance("SHA-256")
                .digest(archive.readBytes())
                .joinToString("") { "%02x".format(it) },
            success.sha256,
        )
        assertFalse(snapshot.exists())
        assertEquals(1, operations.syncedFiles.size)
        assertTrue(operations.syncedFiles.single().name.endsWith(".tmp"))
        assertEquals(listOf(archive.parentFile), operations.syncedDirectories)
        ZipFile(archive).use { zip ->
            assertEquals("manifest.json", zip.entries().nextElement().name)
            assertTrue(zip.getEntry("payload/database/loquiris.sqlite") != null)
        }
        assertTrue(File(root, "backups").listFiles().orEmpty().none { it.name.endsWith(".tmp") })
    }

    @Test
    fun `failed atomic publication removes temporary output and snapshot`() {
        val root = temporaryFolder.newFolder("failed")
        val snapshot = File(root, "backup_staging/backup_2.sqlite").apply {
            parentFile!!.mkdirs()
            writeText("sqlite")
        }
        val publisher =
            BackupArchivePublisher(
                filesRoot = root,
                appVersion = "1.0.0+1",
                fileOperations = FakeBackupFileOperations(replaceSucceeds = false),
            )

        val result =
            publisher.create(
                BackupArchiveRequest(
                    operationId = "backup_2",
                    schemaVersion = 4,
                    exportedAtUtc = "2026-10-01T00:00:00.000Z",
                    snapshotRelativePath = "backup_staging/backup_2.sqlite",
                    audioPlan = emptyList(),
                ),
            )

        assertEquals(BackupArchiveResult.Failure("backup_publish_failed"), result)
        assertFalse(snapshot.exists())
        assertTrue(File(root, "backups").listFiles().orEmpty().isEmpty())
    }

    private class FakeBackupFileOperations(
        private val replaceSucceeds: Boolean = true,
    ) : BackupFileOperations {
        val syncedFiles = mutableListOf<File>()
        val syncedDirectories = mutableListOf<File>()

        override fun syncFile(file: File): Boolean {
            syncedFiles += file
            return true
        }

        override fun atomicMove(
            source: File,
            target: File,
        ): Boolean {
            if (!replaceSucceeds) return false
            Files.move(source.toPath(), target.toPath(), StandardCopyOption.ATOMIC_MOVE)
            return true
        }

        override fun syncDirectory(directory: File): Boolean {
            syncedDirectories += directory
            return true
        }
    }
}
