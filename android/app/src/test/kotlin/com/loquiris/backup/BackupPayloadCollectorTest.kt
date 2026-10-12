package com.loquiris.backup

import com.loquiris.recording.RecordingSegmentEntry
import com.loquiris.recording.RecordingSegmentManifest
import com.loquiris.recording.RecordingSegmentManifestCodec
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.zip.CRC32
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class BackupPayloadCollectorTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `collects snapshot manifest and exact committed audio and journal prefixes`() {
        val root = temporaryFolder.newFolder("files")
        val snapshot = File(root, "backup_staging/backup-1.sqlite").apply {
            parentFile!!.mkdirs()
            writeText("sqlite")
        }
        val storageKey = "a".repeat(64)
        val recordingDirectory = File(root, "recordings/$storageKey").apply { mkdirs() }
        val committedAudio = "committed".encodeToByteArray()
        val audioFile = File(recordingDirectory, "segment-00000.adts").apply {
            writeBytes(committedAudio + "tail".encodeToByteArray())
        }
        val validJournal = journalRecord(committedAudio)
        File(recordingDirectory, "segment-00000.commit").writeBytes(validJournal + byteArrayOf(1, 2, 3))
        val manifestBytes =
            RecordingSegmentManifestCodec.encode(
                RecordingSegmentManifest(
                    sessionId = "meeting-1",
                    sampleRateHz = 16_000,
                    channelCount = 1,
                    bitRateBitsPerSecond = 48_000,
                    codecSpecificData = listOf(byteArrayOf(1, 2)),
                    segments =
                        listOf(
                            RecordingSegmentEntry(
                                index = 0,
                                startSample = 0,
                                dataFileName = audioFile.name,
                                journalFileName = "segment-00000.commit",
                            ),
                        ),
                ),
            )
        File(recordingDirectory, "segments.manifest").writeBytes(manifestBytes)

        val result =
            BackupPayloadCollector(root).collect(
                snapshotRelativePath = "backup_staging/backup-1.sqlite",
                audioPlan =
                    listOf(
                        BackupAudioPlanEntry(
                            relativePath = "recordings/$storageKey/${audioFile.name}",
                            committedBytes = committedAudio.size.toLong(),
                        ),
                    ),
            )

        val sources = (result as BackupPayloadCollectionResult.Success).sources.associateBy { it.path }
        assertEquals(4, sources.size)
        assertArrayEquals(
            "sqlite".encodeToByteArray(),
            sources.getValue("payload/database/loquiris.sqlite").open().use { it.readBytes() },
        )
        assertArrayEquals(
            committedAudio,
            sources.getValue("payload/recordings/$storageKey/segment-00000.adts").open().use { it.readBytes() },
        )
        assertArrayEquals(
            validJournal,
            sources.getValue("payload/recordings/$storageKey/segment-00000.commit").open().use { it.readBytes() },
        )
        assertArrayEquals(
            manifestBytes,
            sources.getValue("payload/recordings/$storageKey/segments.manifest").open().use { it.readBytes() },
        )
    }

    @Test
    fun `fails closed when database prefix disagrees with valid journal`() {
        val root = temporaryFolder.newFolder("mismatch")
        File(root, "backup_staging/backup-2.sqlite").apply {
            parentFile!!.mkdirs()
            writeText("sqlite")
        }
        val storageKey = "b".repeat(64)
        val recordingDirectory = File(root, "recordings/$storageKey").apply { mkdirs() }
        val audio = "audio".encodeToByteArray()
        File(recordingDirectory, "segment-00000.adts").writeBytes(audio)
        File(recordingDirectory, "segment-00000.commit").writeBytes(journalRecord(audio))
        File(recordingDirectory, "segments.manifest").writeBytes(
            RecordingSegmentManifestCodec.encode(
                RecordingSegmentManifest(
                    sessionId = "meeting-2",
                    sampleRateHz = 16_000,
                    channelCount = 1,
                    bitRateBitsPerSecond = 48_000,
                    codecSpecificData = listOf(byteArrayOf(1)),
                    segments =
                        listOf(
                            RecordingSegmentEntry(0, 0, "segment-00000.adts", "segment-00000.commit"),
                        ),
                ),
            ),
        )

        val result =
            BackupPayloadCollector(root).collect(
                snapshotRelativePath = "backup_staging/backup-2.sqlite",
                audioPlan =
                    listOf(
                        BackupAudioPlanEntry(
                            relativePath = "recordings/$storageKey/segment-00000.adts",
                            committedBytes = 2,
                        ),
                    ),
            )

        assertEquals(
            BackupPayloadCollectionResult.Failure("backup_audio_journal_mismatch"),
            result,
        )
    }

    @Test
    fun `rejects traversal and non-authoritative recording artifacts`() {
        val root = temporaryFolder.newFolder("unsafe")
        File(root, "backup_staging/backup-3.sqlite").apply {
            parentFile!!.mkdirs()
            writeText("sqlite")
        }
        listOf(
            "../outside.adts",
            "recordings/${"c".repeat(64)}/recording.m4a",
            "cache/${"c".repeat(64)}/segment-00000.adts",
        ).forEach { relativePath ->
            val result =
                BackupPayloadCollector(root).collect(
                    snapshotRelativePath = "backup_staging/backup-3.sqlite",
                    audioPlan = listOf(BackupAudioPlanEntry(relativePath, 1)),
                )
            assertTrue(result is BackupPayloadCollectionResult.Failure)
        }
    }

    private fun journalRecord(audioPrefix: ByteArray): ByteArray {
        val record = ByteArray(56)
        val buffer = ByteBuffer.wrap(record).order(ByteOrder.BIG_ENDIAN)
        buffer.putInt(0x4c_51_43_4d)
        buffer.putInt(1)
        buffer.putLong(1)
        buffer.putLong(1)
        buffer.putLong(audioPrefix.size.toLong())
        buffer.putLong(1_024)
        buffer.putLong(CRC32().apply { update(audioPrefix) }.value)
        buffer.putLong(CRC32().apply { update(record, 0, 48) }.value)
        return record
    }
}
