package com.loquiris.backup

import com.loquiris.recording.RecordingSegmentEntry
import com.loquiris.recording.RecordingSegmentManifest
import com.loquiris.recording.RecordingSegmentManifestCodec
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class BackupPackageReaderTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `verifies every payload before atomically publishing restore staging`() {
        val root = temporaryFolder.newFolder("files")
        val archive = File(root, "backups/valid.zip").apply {
            parentFile!!.mkdirs()
            writeBytes(validArchive())
        }
        val operations = FakeRestoreFileOperations()

        val result =
            BackupPackageReader(root, operations).verifyAndStage(
                BackupVerificationRequest(
                    operationId = "restore_1",
                    archiveRelativePath = "backups/valid.zip",
                    currentSchemaVersion = 4,
                ),
            )

        val success = result as BackupVerificationResult.Success
        assertEquals(1, success.formatVersion)
        assertEquals(4, success.schemaVersion)
        assertEquals("restore_staging/restore_1/database/loquiris.sqlite", success.databaseRelativePath)
        assertEquals("restore_staging/restore_1/checksums.json", success.checksumIndexRelativePath)
        assertEquals("meeting-a", success.recordings.single().sourceMeetingId)
        assertEquals(STORAGE_KEY, success.recordings.single().storageKey)
        assertTrue(success.recordings.single().contentFingerprint.matches(Regex("[a-f0-9]{64}")))
        assertEquals("segment-00000.adts", success.recordings.single().segments.single().fileName)
        assertEquals(5L, success.recordings.single().segments.single().committedBytes)
        assertArrayEquals(
            "database".encodeToByteArray(),
            File(root, success.databaseRelativePath).readBytes(),
        )
        assertArrayEquals(
            "audio".encodeToByteArray(),
            File(root, "restore_staging/restore_1/recordings/$STORAGE_KEY/segment-00000.adts")
                .readBytes(),
        )
        assertTrue(operations.syncedFiles >= 3)
        assertFalse(File(root, "restore_staging/.restore_1.tmp").exists())
    }

    @Test
    fun `rejects changed payload and removes unpublished staging`() {
        val root = temporaryFolder.newFolder("tampered")
        val valid = validArchive()
        val entries = unzip(valid).toMutableMap()
        entries["payload/database/loquiris.sqlite"] = "changed".encodeToByteArray()
        val archive = File(root, "backups/tampered.zip").apply {
            parentFile!!.mkdirs()
            writeBytes(zip(entries))
        }

        val result =
            BackupPackageReader(root, FakeRestoreFileOperations()).verifyAndStage(
                BackupVerificationRequest("restore_2", "backups/tampered.zip", 4),
            )

        assertEquals(BackupVerificationResult.Failure("restore_payload_checksum_mismatch"), result)
        assertFalse(File(root, "restore_staging/restore_2").exists())
        assertFalse(File(root, "restore_staging/.restore_2.tmp").exists())
    }

    @Test
    fun `rejects unlisted entries before extraction`() {
        val root = temporaryFolder.newFolder("unlisted")
        val entries = unzip(validArchive()).toMutableMap()
        entries["payload/logs/private.log"] = "private".encodeToByteArray()
        val archive = File(root, "backups/unlisted.zip").apply {
            parentFile!!.mkdirs()
            writeBytes(zip(entries))
        }

        val result =
            BackupPackageReader(root, FakeRestoreFileOperations()).verifyAndStage(
                BackupVerificationRequest("restore_3", "backups/unlisted.zip", 4),
            )

        assertEquals(BackupVerificationResult.Failure("restore_entry_set_invalid"), result)
        assertFalse(File(root, "restore_staging/restore_3").exists())
    }

    @Test
    fun `rejects unsupported future database schema`() {
        val root = temporaryFolder.newFolder("future")
        val archive = File(root, "backups/future.zip").apply {
            parentFile!!.mkdirs()
            writeBytes(validArchive(schemaVersion = 5))
        }

        val result =
            BackupPackageReader(root, FakeRestoreFileOperations()).verifyAndStage(
                BackupVerificationRequest("restore_4", "backups/future.zip", 4),
            )

        assertEquals(BackupVerificationResult.Failure("restore_schema_unsupported"), result)
    }

    private fun validArchive(schemaVersion: Int = 4): ByteArray {
        val output = ByteArrayOutputStream()
        val manifest =
            RecordingSegmentManifest(
                sessionId = "meeting-a",
                sampleRateHz = 16_000,
                channelCount = 1,
                bitRateBitsPerSecond = 64_000,
                codecSpecificData = listOf(byteArrayOf(0x12, 0x10)),
                segments =
                    listOf(
                        RecordingSegmentEntry(
                            index = 0,
                            startSample = 0,
                            dataFileName = "segment-00000.adts",
                            journalFileName = "segment-00000.commit",
                        ),
                    ),
            )
        val result =
            BackupPackageWriter().write(
                BackupPackageRequest(
                    formatVersion = 1,
                    schemaVersion = schemaVersion,
                    appVersion = "0.1.0+1",
                    exportedAtUtc = "2026-10-01T00:00:00.000Z",
                    sources =
                        listOf(
                            source("payload/database/loquiris.sqlite", "database"),
                            BackupPayloadSource("payload/recordings/$STORAGE_KEY/segments.manifest") {
                                ByteArrayInputStream(RecordingSegmentManifestCodec.encode(manifest))
                            },
                            source("payload/recordings/$STORAGE_KEY/segment-00000.adts", "audio"),
                            source("payload/recordings/$STORAGE_KEY/segment-00000.commit", "journal"),
                        ),
                ),
                output,
            )
        assertTrue(result is BackupWriteResult.Success)
        return output.toByteArray()
    }

    private fun source(
        path: String,
        content: String,
    ) = BackupPayloadSource(path) { ByteArrayInputStream(content.encodeToByteArray()) }

    private fun unzip(bytes: ByteArray): LinkedHashMap<String, ByteArray> {
        val file = temporaryFolder.newFile("source-${System.nanoTime()}.zip").apply { writeBytes(bytes) }
        return java.util.zip.ZipFile(file).use { archive ->
            linkedMapOf<String, ByteArray>().apply {
                archive.entries().asSequence().forEach { entry ->
                    put(entry.name, archive.getInputStream(entry).use { it.readBytes() })
                }
            }
        }
    }

    private fun zip(entries: Map<String, ByteArray>): ByteArray =
        ByteArrayOutputStream().also { output ->
            ZipOutputStream(output).use { zip ->
                entries.forEach { (name, bytes) ->
                    zip.putNextEntry(ZipEntry(name).apply { time = 0L })
                    zip.write(bytes)
                    zip.closeEntry()
                }
            }
        }.toByteArray()

    private class FakeRestoreFileOperations : RestoreFileOperations {
        var syncedFiles = 0

        override fun syncFile(file: File): Boolean {
            syncedFiles += 1
            return true
        }

        override fun atomicMove(
            source: File,
            target: File,
        ): Boolean {
            Files.move(source.toPath(), target.toPath(), StandardCopyOption.ATOMIC_MOVE)
            return true
        }

        override fun syncDirectory(directory: File): Boolean = true
    }

    private companion object {
        const val STORAGE_KEY =
            "7959c765f2ac5d6f4e75f18fa56177d2826e66700c5cc0f3d542858b1abc87d6"
    }
}
