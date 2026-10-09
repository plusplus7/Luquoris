package com.loquiris.transcription

import com.loquiris.recording.RecordingAdtsFrameCodec
import com.loquiris.recording.RecordingSegmentEntry
import com.loquiris.recording.RecordingSegmentManifest
import com.loquiris.recording.RecordingSegmentManifestCodec
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.file.Files
import java.util.zip.CRC32
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AuthoritativeAudioResolverTest {
    @Test
    fun `resolves ordered journal-authorized prefixes beneath the meeting directory`() {
        val fixture = AudioFixture.create("meeting-1")
        fixture.writeSegment(index = 0, startSample = 0, committedSamples = 1_024, tailBytes = 3)
        fixture.writeSegment(index = 1, startSample = 1_024, committedSamples = 1_024)
        fixture.writeManifest()

        val result = fixture.resolver().resolve("meeting-1")

        val partial = result as AuthoritativeAudioResolution.Partial
        assertEquals("transcription_audio_uncommitted_tail", partial.code)
        assertEquals(listOf(0, 1), partial.segments.map(AuthoritativeAudioSegment::index))
        assertEquals(listOf(11L, 11L), partial.segments.map(AuthoritativeAudioSegment::committedBytes))
        assertEquals(2_048L, partial.totalSamples)
    }

    @Test
    fun `rejects cross-root meeting resolution and mismatched ownership`() {
        val fixture = AudioFixture.create("meeting-1")
        fixture.writeSegment(index = 0, startSample = 0, committedSamples = 1_024)
        fixture.writeManifest(manifestMeetingId = "another-meeting")

        assertEquals(
            AuthoritativeAudioResolution.Failure("transcription_audio_meeting_mismatch"),
            fixture.resolver().resolve("meeting-1"),
        )

        val outside = Files.createTempDirectory("loquiris-transcription-outside").toFile()
        val unsafe =
            AuthoritativeAudioResolver(
                recordingsRoot = fixture.root,
                sessionDirectoryFor = { outside },
            )
        assertEquals(
            AuthoritativeAudioResolution.Failure("transcription_audio_path_invalid"),
            unsafe.resolve("meeting-1"),
        )
    }

    @Test
    fun `reports timeline gaps and missing inputs as partial without crossing the gap`() {
        val fixture = AudioFixture.create("meeting-1")
        fixture.writeSegment(index = 0, startSample = 0, committedSamples = 1_024)
        fixture.writeSegment(index = 1, startSample = 2_048, committedSamples = 1_024)
        fixture.writeManifest()
        File(fixture.session, "segment-00001.adts").delete()

        val result = fixture.resolver().resolve("meeting-1")

        val partial = result as AuthoritativeAudioResolution.Partial
        assertEquals("transcription_audio_timeline_gap", partial.code)
        assertEquals(listOf(0), partial.segments.map(AuthoritativeAudioSegment::index))
        assertEquals(1_024L, partial.totalSamples)
    }

    @Test
    fun `rejects a journal prefix that does not end on its claimed ADTS frame`() {
        val fixture = AudioFixture.create("meeting-1")
        fixture.writeSegment(
            index = 0,
            startSample = 0,
            committedSamples = 1_024,
            committedFrames = 2,
        )
        fixture.writeManifest()

        val result = fixture.resolver().resolve("meeting-1") as AuthoritativeAudioResolution.Partial

        assertEquals("transcription_audio_segment_corrupt", result.code)
        assertTrue(result.segments.isEmpty())
    }

    @Test
    fun `rejects oversized journals before reading unbounded metadata`() {
        val fixture = AudioFixture.create("meeting-1")
        fixture.writeSegment(index = 0, startSample = 0, committedSamples = 1_024)
        fixture.writeManifest()
        File(fixture.session, "segment-00000.commit").writeBytes(ByteArray(AuthoritativeAudioResolver.MAX_JOURNAL_BYTES + 1))

        assertEquals(
            AuthoritativeAudioResolution.Failure("transcription_audio_journal_too_large"),
            fixture.resolver().resolve("meeting-1"),
        )
    }
}

private class AudioFixture private constructor(
    val root: File,
    val session: File,
    private val meetingId: String,
) {
    private val entries = mutableListOf<RecordingSegmentEntry>()

    fun resolver() =
        AuthoritativeAudioResolver(
            recordingsRoot = root,
            sessionDirectoryFor = { session },
        )

    fun writeSegment(
        index: Int,
        startSample: Long,
        committedSamples: Long,
        committedFrames: Long = 1,
        tailBytes: Int = 0,
    ) {
        val name = index.toString().padStart(5, '0')
        val data =
            RecordingAdtsFrameCodec.wrap(
                accessUnit = byteArrayOf(1, 2, 3, (index + 4).toByte()),
                sampleRateHz = 16_000,
                channelCount = 1,
            )
        File(session, "segment-$name.adts").writeBytes(data + ByteArray(tailBytes) { 99 })
        File(session, "segment-$name.commit").writeBytes(
            journalRecord(data, committedSamples, committedFrames),
        )
        entries += RecordingSegmentEntry(index, startSample, "segment-$name.adts", "segment-$name.commit")
    }

    fun writeManifest(manifestMeetingId: String = meetingId) {
        val manifest =
            RecordingSegmentManifest(
                sessionId = manifestMeetingId,
                sampleRateHz = 16_000,
                channelCount = 1,
                bitRateBitsPerSecond = 64_000,
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
                segments = entries,
            )
        File(session, "segments.manifest").writeBytes(RecordingSegmentManifestCodec.encode(manifest))
    }

    companion object {
        fun create(meetingId: String): AudioFixture {
            val root = Files.createTempDirectory("loquiris-transcription-root").toFile()
            val session = File(root, "meeting-hash").apply { mkdirs() }
            return AudioFixture(root, session, meetingId)
        }
    }
}

private fun journalRecord(
    data: ByteArray,
    committedSamples: Long,
    committedFrames: Long,
): ByteArray {
    val bytes = ByteArray(56)
    val buffer = ByteBuffer.wrap(bytes).order(ByteOrder.BIG_ENDIAN)
    buffer.putInt(0x4c_51_43_4d)
    buffer.putInt(1)
    buffer.putLong(1)
    buffer.putLong(committedFrames)
    buffer.putLong(data.size.toLong())
    buffer.putLong(committedSamples)
    buffer.putLong(CRC32().also { it.update(data) }.value)
    buffer.putLong(CRC32().also { it.update(bytes, 0, 48) }.value)
    return bytes
}
