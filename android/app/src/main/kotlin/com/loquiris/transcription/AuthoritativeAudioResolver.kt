package com.loquiris.transcription

import android.content.Context
import com.loquiris.recording.AppPrivateRecordingStorage
import com.loquiris.recording.AtomicRecordingSegmentManifestStore
import com.loquiris.recording.RecordingCommittedPrefixRecovery
import com.loquiris.recording.RecordingSegmentManifestDecodeResult
import com.loquiris.recording.RecordingSegmentManifestCodec
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.zip.CRC32

class AuthoritativeAudioResolver(
    private val recordingsRoot: File,
    private val sessionDirectoryFor: (String) -> File,
) : AuthoritativeAudioProvider {
    constructor(context: Context) : this(
        recordingsRoot = File(context.applicationContext.filesDir, "recordings"),
        sessionDirectoryFor = { meetingId ->
            AppPrivateRecordingStorage.sessionDirectory(context.applicationContext, meetingId)
        },
    )

    override fun resolve(meetingId: String): AuthoritativeAudioResolution {
        if (meetingId.isBlank()) return failure("transcription_audio_meeting_invalid")
        return try {
            resolveChecked(meetingId)
        } catch (_: IOException) {
            failure("transcription_audio_read_failed")
        } catch (_: RuntimeException) {
            failure("transcription_audio_invalid")
        }
    }

    private fun resolveChecked(meetingId: String): AuthoritativeAudioResolution {
        val canonicalRoot = recordingsRoot.canonicalFile
        val session = sessionDirectoryFor(meetingId).canonicalFile
        if (!session.isStrictChildOf(canonicalRoot)) return failure("transcription_audio_path_invalid")
        if (!session.isDirectory) return failure("transcription_audio_missing")
        val manifestFile = File(session, AtomicRecordingSegmentManifestStore.MANIFEST_FILE_NAME)
        if (!manifestFile.isFile) return failure("transcription_audio_manifest_missing")
        if (manifestFile.length() > MAX_MANIFEST_BYTES) return failure("transcription_audio_manifest_invalid")
        val manifest =
            when (val decoded = RecordingSegmentManifestCodec.decode(manifestFile.readBytes())) {
                is RecordingSegmentManifestDecodeResult.Success -> decoded.manifest
                is RecordingSegmentManifestDecodeResult.Corrupt -> {
                    return failure("transcription_audio_manifest_invalid")
                }
            }
        if (manifest.sessionId != meetingId) return failure("transcription_audio_meeting_mismatch")
        if (manifest.sampleRateHz != TARGET_SAMPLE_RATE_HZ || manifest.channelCount != TARGET_CHANNEL_COUNT) {
            return failure("transcription_audio_format_unsupported")
        }

        val resolved = mutableListOf<AuthoritativeAudioSegment>()
        var totalSamples = 0L
        var partialCode: String? = null
        for (entry in manifest.segments) {
            if (entry.startSample != totalSamples) {
                return partial(manifest, resolved, totalSamples, "transcription_audio_timeline_gap")
            }
            val data = File(session, entry.dataFileName).canonicalFile
            val journal = File(session, entry.journalFileName).canonicalFile
            if (!data.isStrictChildOf(session) || !journal.isStrictChildOf(session)) {
                return failure("transcription_audio_path_invalid")
            }
            if (!data.isFile || !journal.isFile) {
                return partial(manifest, resolved, totalSamples, "transcription_audio_segment_missing")
            }
            val prefix = readCommittedPrefix(data, journal)
            when (prefix) {
                is JournalPrefixResult.Failure -> {
                    if (prefix.code == "transcription_audio_journal_too_large") return failure(prefix.code)
                    return partial(manifest, resolved, totalSamples, prefix.code)
                }
                is JournalPrefixResult.Ready -> {
                    if (prefix.committedBytes == 0L || prefix.committedSamples == 0L) {
                        return partial(manifest, resolved, totalSamples, "transcription_audio_segment_open")
                    }
                    resolved +=
                        AuthoritativeAudioSegment(
                            index = entry.index,
                            file = data,
                            committedBytes = prefix.committedBytes,
                            startSample = totalSamples,
                            committedSamples = prefix.committedSamples,
                        )
                    totalSamples = Math.addExact(totalSamples, prefix.committedSamples)
                    if (data.length() > prefix.committedBytes) {
                        partialCode = partialCode ?: "transcription_audio_uncommitted_tail"
                    }
                }
            }
        }
        if (resolved.isEmpty()) return failure("transcription_audio_empty")
        return partialCode?.let { partial(manifest, resolved, totalSamples, it) }
            ?: AuthoritativeAudioResolution.Ready(
                segments = resolved,
                totalSamples = totalSamples,
                sampleRateHz = manifest.sampleRateHz,
                codecSpecificData = manifest.codecSpecificData.map(ByteArray::copyOf),
            )
    }

    private fun partial(
        manifest: com.loquiris.recording.RecordingSegmentManifest,
        segments: List<AuthoritativeAudioSegment>,
        totalSamples: Long,
        code: String,
    ) =
        AuthoritativeAudioResolution.Partial(
            segments = segments.toList(),
            totalSamples = totalSamples,
            sampleRateHz = manifest.sampleRateHz,
            codecSpecificData = manifest.codecSpecificData.map(ByteArray::copyOf),
            code = code,
        )

    private fun readCommittedPrefix(
        data: File,
        journal: File,
    ): JournalPrefixResult {
        if (journal.length() > MAX_JOURNAL_BYTES) {
            return JournalPrefixResult.Failure("transcription_audio_journal_too_large")
        }
        val journalBytes = journal.readBytes()
        var offset = 0
        val records = mutableListOf<JournalRecord>()
        while (journalBytes.size - offset >= JOURNAL_RECORD_BYTES) {
            val record = decodeRecord(journalBytes, offset) ?: break
            if (!record.follows(records.lastOrNull())) break
            records += record
            offset += JOURNAL_RECORD_BYTES
        }
        val latest = records.lastOrNull()
            ?: return JournalPrefixResult.Failure("transcription_audio_journal_invalid")
        if (latest.committedBytes > MAX_COMMITTED_SEGMENT_BYTES) {
            return JournalPrefixResult.Failure("transcription_audio_segment_too_large")
        }
        val candidateBytes = readPrefix(data, minOf(data.length(), latest.committedBytes))
        val recovered = RecordingCommittedPrefixRecovery.recover(candidateBytes, journalBytes)
        if (recovered.committedBytes <= 0) {
            return JournalPrefixResult.Failure("transcription_audio_segment_corrupt")
        }
        val expectedSamples =
            runCatching {
                Math.multiplyExact(recovered.committedFrames.toLong(), AAC_SAMPLES_PER_FRAME)
            }.getOrNull()
        if (recovered.committedSamples != expectedSamples) {
            return JournalPrefixResult.Failure("transcription_audio_segment_corrupt")
        }
        return JournalPrefixResult.Ready(
            recovered.committedBytes.toLong(),
            recovered.committedSamples,
        )
    }

    private fun decodeRecord(
        bytes: ByteArray,
        offset: Int,
    ): JournalRecord? {
        val frame = ByteBuffer.wrap(bytes, offset, JOURNAL_RECORD_BYTES).order(ByteOrder.BIG_ENDIAN)
        if (frame.int != JOURNAL_MAGIC || frame.int != JOURNAL_VERSION) return null
        val record =
            JournalRecord(
                sequence = frame.long,
                frameEndExclusive = frame.long,
                committedBytes = frame.long,
                committedSamples = frame.long,
                prefixCrc32 = frame.long,
            )
        val recordChecksum = frame.long
        val actualChecksum = CRC32().also { it.update(bytes, offset, JOURNAL_CHECKSUM_OFFSET) }.value
        return record.takeIf { recordChecksum == actualChecksum }
    }

    private fun readPrefix(
        file: File,
        length: Long,
    ): ByteArray {
        if (length > Int.MAX_VALUE) throw IOException("segment prefix is too large")
        val bytes = ByteArray(length.toInt())
        var offset = 0
        FileInputStream(file).use { input ->
            while (offset < bytes.size) {
                val read = input.read(bytes, offset, bytes.size - offset)
                if (read < 0) throw IOException("unexpected EOF")
                offset += read
            }
        }
        return bytes
    }

    private fun failure(code: String) = AuthoritativeAudioResolution.Failure(code)

    companion object {
        const val MAX_JOURNAL_BYTES = 8 * 1024 * 1024
        private const val MAX_MANIFEST_BYTES = 1024 * 1024 + 20L
        private const val TARGET_SAMPLE_RATE_HZ = 16_000
        private const val TARGET_CHANNEL_COUNT = 1
        private const val AAC_SAMPLES_PER_FRAME = 1_024L
        private const val MAX_COMMITTED_SEGMENT_BYTES = 64L * 1024 * 1024
        private const val JOURNAL_MAGIC = 0x4c_51_43_4d
        private const val JOURNAL_VERSION = 1
        private const val JOURNAL_CHECKSUM_OFFSET = 48
        private const val JOURNAL_RECORD_BYTES = 56
    }
}

private data class JournalRecord(
    val sequence: Long,
    val frameEndExclusive: Long,
    val committedBytes: Long,
    val committedSamples: Long,
    val prefixCrc32: Long,
) {
    fun follows(previous: JournalRecord?): Boolean =
        sequence > 0 &&
            frameEndExclusive > 0 &&
            committedBytes > 0 &&
            committedSamples > 0 &&
            (previous == null ||
                sequence == previous.sequence + 1 &&
                frameEndExclusive > previous.frameEndExclusive &&
                committedBytes > previous.committedBytes &&
                committedSamples > previous.committedSamples)
}

private sealed interface JournalPrefixResult {
    data class Ready(
        val committedBytes: Long,
        val committedSamples: Long,
    ) : JournalPrefixResult

    data class Failure(
        val code: String,
    ) : JournalPrefixResult
}

private fun File.isStrictChildOf(parent: File): Boolean = path.startsWith(parent.path + File.separator)
