package com.loquiris.backup

import com.loquiris.recording.RecordingSegmentManifest
import com.loquiris.recording.RecordingSegmentManifestCodec
import com.loquiris.recording.RecordingSegmentManifestDecodeResult
import java.io.File
import java.io.FileInputStream
import java.io.FilterInputStream
import java.io.IOException
import java.io.InputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.zip.CRC32

data class BackupAudioPlanEntry(
    val relativePath: String,
    val committedBytes: Long,
)

sealed interface BackupPayloadCollectionResult {
    data class Success(
        val sources: List<BackupPayloadSource>,
    ) : BackupPayloadCollectionResult

    data class Failure(
        val code: String,
    ) : BackupPayloadCollectionResult
}

class BackupPayloadCollector(
    private val filesRoot: File,
) {
    fun collect(
        snapshotRelativePath: String,
        audioPlan: List<BackupAudioPlanEntry>,
    ): BackupPayloadCollectionResult {
        if (!SNAPSHOT_PATH.matches(snapshotRelativePath)) return failure("backup_snapshot_path_invalid")
        if (
            audioPlan.any { it.committedBytes <= 0 || !RECORDING_SOURCE_PATH.matches(it.relativePath) } ||
            audioPlan.map(BackupAudioPlanEntry::relativePath).distinct().size != audioPlan.size
        ) {
            return failure("backup_audio_plan_invalid")
        }
        return try {
            val root = filesRoot.canonicalFile
            val snapshot = resolveFile(root, snapshotRelativePath) ?: return failure("backup_snapshot_path_invalid")
            if (!snapshot.isFile) return failure("backup_snapshot_missing")
            val sources = mutableListOf(BackupPayloadSource(DATABASE_ARCHIVE_PATH) { FileInputStream(snapshot) })
            val manifests = mutableMapOf<File, RecordingSegmentManifest>()
            audioPlan.sortedBy(BackupAudioPlanEntry::relativePath).forEach { entry ->
                val audioFile = resolveFile(root, entry.relativePath) ?: return failure("backup_audio_path_invalid")
                if (!audioFile.isFile || audioFile.length() < entry.committedBytes) {
                    return failure("backup_audio_source_truncated")
                }
                val directory = requireNotNull(audioFile.parentFile).canonicalFile
                val manifest =
                    manifests.getOrPut(directory) {
                        val manifestFile = File(directory, MANIFEST_FILE_NAME)
                        val decoded =
                            if (manifestFile.isFile) {
                                RecordingSegmentManifestCodec.decode(manifestFile.readBytes())
                            } else {
                                RecordingSegmentManifestDecodeResult.Corrupt("recording_manifest_missing")
                            }
                        when (decoded) {
                            is RecordingSegmentManifestDecodeResult.Success -> decoded.manifest
                            is RecordingSegmentManifestDecodeResult.Corrupt -> throw CollectionFailure("backup_manifest_invalid")
                        }
                    }
                val segment =
                    manifest.segments.singleOrNull { it.dataFileName == audioFile.name }
                        ?: return failure("backup_manifest_mismatch")
                val journalFile = File(directory, segment.journalFileName)
                if (!journalFile.isFile) return failure("backup_audio_journal_missing")
                val journalPrefix = validJournalPrefixBytes(journalFile, audioFile, entry.committedBytes)
                    ?: return failure("backup_audio_journal_mismatch")
                val storageKey = directory.name
                sources +=
                    BackupPayloadSource("payload/recordings/$storageKey/${audioFile.name}") {
                        BoundedInputStream(FileInputStream(audioFile), entry.committedBytes)
                    }
                sources +=
                    BackupPayloadSource("payload/recordings/$storageKey/${journalFile.name}") {
                        BoundedInputStream(FileInputStream(journalFile), journalPrefix)
                    }
            }
            manifests.keys.sortedBy(File::getName).forEach { directory ->
                val manifestFile = File(directory, MANIFEST_FILE_NAME)
                sources +=
                    BackupPayloadSource("payload/recordings/${directory.name}/$MANIFEST_FILE_NAME") {
                        FileInputStream(manifestFile)
                    }
            }
            BackupPayloadCollectionResult.Success(sources)
        } catch (failure: CollectionFailure) {
            failure(failure.code)
        } catch (_: IOException) {
            failure("backup_payload_unavailable")
        } catch (_: RuntimeException) {
            failure("backup_payload_invalid")
        }
    }

    private fun resolveFile(
        root: File,
        relativePath: String,
    ): File? {
        val resolved = File(root, relativePath).canonicalFile
        return resolved.takeIf { it.path.startsWith(root.path + File.separator) }
    }

    private fun validJournalPrefixBytes(
        journalFile: File,
        audioFile: File,
        committedBytes: Long,
    ): Long? {
        if (journalFile.length() > MAX_JOURNAL_BYTES) return null
        val bytes = journalFile.readBytes()
        var offset = 0
        var previousSequence = 0L
        var previousFrameEnd = 0L
        var previousByteEnd = 0L
        var previousSampleEnd = 0L
        while (bytes.size - offset >= JOURNAL_RECORD_BYTES) {
            val frame = ByteBuffer.wrap(bytes, offset, JOURNAL_RECORD_BYTES).order(ByteOrder.BIG_ENDIAN)
            if (frame.int != JOURNAL_MAGIC || frame.int != JOURNAL_VERSION) break
            val sequence = frame.long
            val frameEnd = frame.long
            val byteEnd = frame.long
            val sampleEnd = frame.long
            val prefixCrc = frame.long
            val recordCrc = frame.long
            if (
                recordCrc != crc32(bytes, offset, JOURNAL_CHECKSUM_OFFSET) ||
                sequence != previousSequence + 1 || frameEnd <= previousFrameEnd ||
                byteEnd <= previousByteEnd || sampleEnd <= previousSampleEnd
            ) {
                break
            }
            offset += JOURNAL_RECORD_BYTES
            if (byteEnd == committedBytes) {
                if (crc32Prefix(audioFile, committedBytes) != prefixCrc) return null
                return offset.toLong()
            }
            previousSequence = sequence
            previousFrameEnd = frameEnd
            previousByteEnd = byteEnd
            previousSampleEnd = sampleEnd
        }
        return null
    }

    private fun crc32Prefix(
        file: File,
        bytes: Long,
    ): Long {
        var remaining = bytes
        val checksum = CRC32()
        FileInputStream(file).use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (remaining > 0) {
                val read = input.read(buffer, 0, minOf(buffer.size.toLong(), remaining).toInt())
                if (read < 0) throw IOException("truncated")
                if (read == 0) continue
                checksum.update(buffer, 0, read)
                remaining -= read
            }
        }
        return checksum.value
    }

    private fun crc32(
        bytes: ByteArray,
        offset: Int,
        length: Int,
    ): Long = CRC32().apply { update(bytes, offset, length) }.value

    private fun failure(code: String) = BackupPayloadCollectionResult.Failure(code)

    private class CollectionFailure(
        val code: String,
    ) : RuntimeException()

    private class BoundedInputStream(
        input: InputStream,
        private var remaining: Long,
    ) : FilterInputStream(input) {
        override fun read(): Int {
            if (remaining <= 0) return -1
            val value = super.read()
            if (value >= 0) remaining -= 1
            return value
        }

        override fun read(
            buffer: ByteArray,
            offset: Int,
            length: Int,
        ): Int {
            if (remaining <= 0) return -1
            val read = super.read(buffer, offset, minOf(length.toLong(), remaining).toInt())
            if (read > 0) remaining -= read
            return read
        }
    }

    private companion object {
        const val DATABASE_ARCHIVE_PATH = "payload/database/loquiris.sqlite"
        const val MANIFEST_FILE_NAME = "segments.manifest"
        const val JOURNAL_MAGIC = 0x4c_51_43_4d
        const val JOURNAL_VERSION = 1
        const val JOURNAL_CHECKSUM_OFFSET = 48
        const val JOURNAL_RECORD_BYTES = 56
        const val MAX_JOURNAL_BYTES = 16 * 1024 * 1024L
        val SNAPSHOT_PATH = Regex("backup_staging/[A-Za-z0-9_-]{1,128}\\.sqlite")
        val RECORDING_SOURCE_PATH =
            Regex("recordings/[a-f0-9]{64}/segment-[0-9]{5,}\\.adts")
    }
}
