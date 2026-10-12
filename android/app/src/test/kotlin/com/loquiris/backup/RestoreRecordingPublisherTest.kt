package com.loquiris.backup

import com.loquiris.recording.RecordingSegmentEntry
import com.loquiris.recording.RecordingSegmentManifest
import com.loquiris.recording.RecordingSegmentManifestCodec
import com.loquiris.recording.RecordingSegmentManifestDecodeResult
import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class RestoreRecordingPublisherTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `publishes exact files atomically and rewrites only meeting identity`() {
        val root = temporaryFolder.newFolder("files")
        val fixture = recordingFixture(root, "restore_1", "meeting-a")
        val publisher = RestoreRecordingPublisher(root, FakeOperations())

        val result =
            publisher.publish(
                RestoreRecordingTransfer(
                    operationId = "restore_1",
                    sourceMeetingId = "meeting-a",
                    targetMeetingId = "meeting-copy",
                    contentFingerprint = fixture.fingerprint,
                ),
            )

        assertEquals(RestoreRecordingPublishResult.Success(published = true), result)
        val target = File(root, "recordings/${sha256("meeting-copy")}")
        assertTrue(target.isDirectory)
        assertEquals("audio", File(target, "segment-00000.adts").readText())
        val decoded = RecordingSegmentManifestCodec.decode(File(target, "segments.manifest").readBytes())
        assertEquals(
            "meeting-copy",
            (decoded as RecordingSegmentManifestDecodeResult.Success).manifest.sessionId,
        )
        assertEquals(fixture.fingerprint, publisher.fingerprints(listOf("meeting-copy"))!!["meeting-copy"])
    }

    @Test
    fun `is idempotent for identical target and rolls back only requested publication`() {
        val root = temporaryFolder.newFolder("idempotent")
        val fixture = recordingFixture(root, "restore_2", "meeting-a")
        val publisher = RestoreRecordingPublisher(root, FakeOperations())
        val request =
            RestoreRecordingTransfer(
                operationId = "restore_2",
                sourceMeetingId = "meeting-a",
                targetMeetingId = "meeting-copy",
                contentFingerprint = fixture.fingerprint,
            )

        assertEquals(RestoreRecordingPublishResult.Success(true), publisher.publish(request))
        assertEquals(RestoreRecordingPublishResult.Success(true), publisher.publish(request))
        assertTrue(publisher.rollback("restore_2", listOf("meeting-copy")))
        assertFalse(File(root, "recordings/${sha256("meeting-copy")}").exists())
        assertTrue(publisher.discardStaging("restore_2"))
        assertFalse(File(root, "restore_staging/restore_2").exists())
    }

    @Test
    fun `finalize removes pending marker and makes publication established`() {
        val root = temporaryFolder.newFolder("finalize")
        val fixture = recordingFixture(root, "restore_3", "meeting-a")
        val publisher = RestoreRecordingPublisher(root, FakeOperations())
        val request =
            RestoreRecordingTransfer(
                operationId = "restore_3",
                sourceMeetingId = "meeting-a",
                targetMeetingId = "meeting-copy",
                contentFingerprint = fixture.fingerprint,
            )

        assertEquals(RestoreRecordingPublishResult.Success(true), publisher.publish(request))
        assertTrue(publisher.finalize("restore_3", listOf("meeting-copy")))
        assertEquals(RestoreRecordingPublishResult.Success(false), publisher.publish(request))
        assertTrue(publisher.rollback("restore_3", listOf("meeting-copy")))
        assertTrue(File(root, "recordings/${sha256("meeting-copy")}").isDirectory)
    }

    private fun recordingFixture(
        root: File,
        operationId: String,
        meetingId: String,
    ): Fixture {
        val directory = File(root, "restore_staging/$operationId/recordings/${sha256(meetingId)}")
        directory.mkdirs()
        val manifest =
            RecordingSegmentManifest(
                sessionId = meetingId,
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
        File(directory, "segments.manifest").writeBytes(RecordingSegmentManifestCodec.encode(manifest))
        val audio = File(directory, "segment-00000.adts").apply { writeText("audio") }
        val journal = File(directory, "segment-00000.commit").apply { writeText("journal") }
        val fingerprint =
            restoreRecordingFingerprint(
                manifest,
                listOf(
                    RestoreRecordingFileDigest(audio.name, audio.length(), sha256(audio.readBytes())),
                    RestoreRecordingFileDigest(journal.name, journal.length(), sha256(journal.readBytes())),
                ),
            )
        return Fixture(fingerprint)
    }

    private fun sha256(value: String): String = sha256(value.toByteArray())

    private fun sha256(value: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(value).joinToString("") { "%02x".format(it) }

    private data class Fixture(
        val fingerprint: String,
    )

    private class FakeOperations : RestoreFileOperations {
        override fun syncFile(file: File): Boolean = true

        override fun atomicMove(
            source: File,
            target: File,
        ): Boolean {
            Files.move(source.toPath(), target.toPath(), StandardCopyOption.ATOMIC_MOVE)
            return true
        }

        override fun syncDirectory(directory: File): Boolean = true
    }
}
