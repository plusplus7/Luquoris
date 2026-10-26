package com.loquiris.transcription

import com.loquiris.recording.RecordingAdtsFrameCodec
import com.loquiris.recording.RecordingSegmentEntry
import com.loquiris.recording.RecordingSegmentManifest
import com.loquiris.recording.RecordingSegmentManifestCodec
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.zip.CRC32
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class StrictRefinementAudioTest {
    @get:Rule val temporary = TemporaryFolder()

    @Test
    fun `strict mode accepts a fully committed segment`() {
        val fixture = fixture()
        val audio = fixture.resolve() as AuthoritativeAudioResolution.Ready
        assertEquals(1_024L, audio.totalSamples)
        assertEquals(11L, audio.segments.single().committedBytes)
    }

    @Test
    fun `strict mode rejects a truncated journal suffix instead of accepting an earlier commit`() {
        val fixture = fixture()
        fixture.journal.appendBytes(byteArrayOf(1, 2, 3))
        assertEquals("transcription_audio_journal_invalid", fixture.partialCode())
        assertTrue(fixture.resolve(strict = false) is AuthoritativeAudioResolution.Ready)
    }

    @Test
    fun `strict mode rejects a complete but corrupt last journal record`() {
        val fixture = fixture()
        fixture.journal.appendBytes(ByteArray(56))
        assertEquals("transcription_audio_journal_invalid", fixture.partialCode())
        assertTrue(fixture.resolve(strict = false) is AuthoritativeAudioResolution.Ready)
    }

    @Test
    fun `strict mode rejects recovery to an older commit when the latest audio is lost`() {
        val fixture = fixture()
        val secondFrame = RecordingAdtsFrameCodec.wrap(byteArrayOf(5, 6, 7, 8), 16_000, 1)
        fixture.journal.appendBytes(commit(fixture.data.readBytes() + secondFrame, 2))
        assertEquals("transcription_audio_latest_commit_unavailable", fixture.partialCode())
        assertTrue(fixture.resolve(strict = false) is AuthoritativeAudioResolution.Ready)
    }

    @Test
    fun `inventory has an independently derived content identity unaffected by storage relocation`() {
        val fixture = fixture()
        val original = fixture.inventory() as RefinementAudioInventoryResult.Ready
        assertEquals("837d745d71771f720eac84b4e343b5a3e93dc48ff61bf2ad132a92fecc97d873", original.sha256)
        assertEquals(listOf("03f5408ae7fed64e94ec0a9dc75e99629e66368eeda41c565790f58171677b92"), original.referenceHashes)
        val relocatedRoot = temporary.newFolder()
        val relocated = File(relocatedRoot, "renamed")
        fixture.session.copyRecursively(relocated)
        val copied = RefinementAudioInventoryReader(relocatedRoot, { relocated }).read("meeting")
            as RefinementAudioInventoryResult.Ready
        assertEquals(original.sha256, copied.sha256)
    }

    @Test
    fun `inventory never accepts a recoverable prefix or missing original segment`() {
        val fixture = fixture()
        fixture.data.appendBytes(byteArrayOf(99))
        assertEquals(
            RefinementAudioInventoryResult.Failure("transcription_audio_uncommitted_tail"),
            fixture.inventory(),
        )
        fixture.data.delete()
        assertEquals(
            RefinementAudioInventoryResult.Failure("transcription_audio_segment_missing"),
            fixture.inventory(),
        )
    }

    @Test
    fun `inventory rejects a changed audio identity before refinement`() {
        val fixture = fixture()
        assertEquals(
            RefinementAudioInventoryResult.Failure("refinement_audio_inventory_mismatch"),
            RefinementAudioInventoryReader(fixture.root, { fixture.session })
                .read("meeting", expectedSha256 = "0".repeat(64)),
        )
    }

    @Test
    fun `recording priority and cancellation prevent inventory work`() {
        val fixture = fixture()
        fixture.data.delete()
        assertEquals(
            RefinementAudioInventoryResult.Deferred("refinement_recording_active"),
            RefinementAudioInventoryReader(fixture.root, { fixture.session }, isRecordingActive = { true })
                .read("meeting"),
        )
        assertEquals(
            RefinementAudioInventoryResult.Cancelled,
            RefinementAudioInventoryReader(fixture.root, { fixture.session }, isCancelled = { true })
                .read("meeting"),
        )
    }

    @Test
    fun `inventory identity covers every ordered original segment`() {
        val fixture = fixture()
        val second = File(fixture.session, "second.adts")
        second.writeBytes(RecordingAdtsFrameCodec.wrap(byteArrayOf(5, 6, 7, 8), 16_000, 1))
        val journal = File(fixture.session, "second.commit")
        journal.writeBytes(commit(second.readBytes(), 1))
        File(fixture.session, "segments.manifest").writeBytes(
            RecordingSegmentManifestCodec.encode(
                RecordingSegmentManifest(
                    "meeting", 16_000, 1, 64_000, listOf(byteArrayOf(0x14, 0x08)),
                    listOf(
                        RecordingSegmentEntry(0, 0, fixture.data.name, fixture.journal.name),
                        RecordingSegmentEntry(1, 1_024, second.name, journal.name),
                    ),
                ),
            ),
        )
        val inventory = fixture.inventory() as RefinementAudioInventoryResult.Ready
        assertEquals("561a6fd703366e0cad34d0b109f3d559969ece53872b4a09a2b1b657e03983d3", inventory.sha256)
        assertEquals(2_048L, inventory.audio.totalSamples)
        assertEquals(listOf(0, 1), inventory.audio.segments.map { it.index })
        second.delete()
        assertEquals(
            RefinementAudioInventoryResult.Failure("transcription_audio_segment_missing"),
            fixture.inventory(),
        )
    }

    @Test
    fun `new recording during inventory yields without modifying original audio`() {
        val fixture = fixture()
        val beforeData = fixture.data.readBytes().toList()
        val beforeJournal = fixture.journal.readBytes().toList()
        var checks = 0
        val result = RefinementAudioInventoryReader(
            fixture.root, { fixture.session }, isRecordingActive = { ++checks >= 5 },
        ).read("meeting")
        assertEquals(RefinementAudioInventoryResult.Deferred("refinement_recording_active"), result)
        assertEquals(beforeData, fixture.data.readBytes().toList())
        assertEquals(beforeJournal, fixture.journal.readBytes().toList())
    }

    @Test
    fun `strict mode rejects journal duration that undercounts actual ADTS frames`() {
        val fixture = fixture()
        fixture.data.appendBytes(RecordingAdtsFrameCodec.wrap(byteArrayOf(5, 6, 7, 8), 16_000, 1))
        fixture.journal.writeBytes(commit(fixture.data.readBytes(), 1))
        assertEquals("transcription_audio_segment_corrupt", fixture.partialCode())
    }

    @Test
    fun `inventory refuses same-length audio changed after journal validation`() {
        val fixture = fixture()
        var checks = 0
        val result = RefinementAudioInventoryReader(
            fixture.root, { fixture.session },
            isRecordingActive = {
                if (++checks == 2) {
                    fixture.data.writeBytes(RecordingAdtsFrameCodec.wrap(byteArrayOf(5, 6, 7, 8), 16_000, 1))
                }
                false
            },
        ).read("meeting")
        assertEquals(RefinementAudioInventoryResult.Failure("refinement_audio_changed"), result)
    }

    private fun fixture(): StrictAudioFixture {
        val root = temporary.newFolder()
        val session = File(root, "session").apply { mkdirs() }
        val data = File(session, "original.adts")
        data.writeBytes(RecordingAdtsFrameCodec.wrap(byteArrayOf(1, 2, 3, 4), 16_000, 1))
        val journal = File(session, "original.commit")
        journal.writeBytes(commit(data.readBytes(), 1))
        File(session, "segments.manifest").writeBytes(
            RecordingSegmentManifestCodec.encode(
                RecordingSegmentManifest(
                    sessionId = "meeting",
                    sampleRateHz = 16_000,
                    channelCount = 1,
                    bitRateBitsPerSecond = 64_000,
                    codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
                    segments = listOf(RecordingSegmentEntry(0, 0, data.name, journal.name)),
                ),
            ),
        )
        return StrictAudioFixture(root, session, data, journal)
    }
}

private class StrictAudioFixture(
    val root: File,
    val session: File,
    val data: File,
    val journal: File,
) {
    fun resolve(strict: Boolean = true) =
        AuthoritativeAudioResolver(root, { session }, requireCompleteJournal = strict).resolve("meeting")

    fun partialCode() = (resolve() as AuthoritativeAudioResolution.Partial).code

    fun inventory() = RefinementAudioInventoryReader(root, { session }).read("meeting")
}

private fun commit(data: ByteArray, frames: Long): ByteArray {
    val bytes = ByteArray(56)
    ByteBuffer.wrap(bytes).order(ByteOrder.BIG_ENDIAN).apply {
        putInt(0x4c_51_43_4d)
        putInt(1)
        putLong(frames)
        putLong(frames)
        putLong(data.size.toLong())
        putLong(frames * 1_024)
        putLong(CRC32().also { it.update(data) }.value)
        putLong(CRC32().also { it.update(bytes, 0, 48) }.value)
    }
    return bytes
}
