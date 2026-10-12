package com.loquiris.recording

import java.io.Closeable
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.zip.CRC32

data class RecordingSegmentationPolicy(
    val commitFrames: Int,
    val commitGroupsPerSegment: Int,
    val samplesPerFrame: Int = 1_024,
    val sampleRateHz: Int = 16_000,
) {
    init {
        require(commitFrames > 0) { "commit frames must be positive" }
        require(commitGroupsPerSegment > 0) { "commit groups must be positive" }
        require(samplesPerFrame > 0) { "samples per frame must be positive" }
        require(sampleRateHz > 0) { "sample rate must be positive" }
        Math.multiplyExact(commitFrames, commitGroupsPerSegment)
    }

    val framesPerSegment: Int = commitFrames * commitGroupsPerSegment
    val commitDurationMilliseconds: Long = commitFrames.toLong() * samplesPerFrame * 1_000L / sampleRateHz
    val segmentDurationMilliseconds: Long = framesPerSegment.toLong() * samplesPerFrame * 1_000L / sampleRateHz

    companion object {
        val production = RecordingSegmentationPolicy(commitFrames = 75, commitGroupsPerSegment = 62)
    }
}

data class RecordingCommitRecord(
    val sequence: Long,
    val frameEndExclusive: Long,
    val byteEndExclusive: Long,
    val sampleEndExclusive: Long,
    val prefixCrc32: Long,
)

data class RecordingCommittedPrefix(
    val committedFrames: Int,
    val committedBytes: Int,
    val committedSamples: Long,
    val uncommittedOrInvalidBytes: Int,
)

private data class RecordingAdtsScan(
    val completeFrames: Int,
    val completeBytes: Int,
    val invalidOffset: Int?,
)

private object RecordingAdtsScanner {
    fun scan(bytes: ByteArray): RecordingAdtsScan {
        var offset = 0
        var frames = 0
        while (offset < bytes.size) {
            val remaining = bytes.size - offset
            if (remaining < HEADER_BYTES) break
            if (unsigned(bytes[offset]) != 0xff || unsigned(bytes[offset + 1]) and 0xf6 != 0xf0) {
                return RecordingAdtsScan(frames, offset, offset)
            }
            val headerBytes = if (unsigned(bytes[offset + 1]) and 1 == 1) HEADER_BYTES else CRC_HEADER_BYTES
            val frameBytes =
                ((unsigned(bytes[offset + 3]) and 0x03) shl 11) or
                    (unsigned(bytes[offset + 4]) shl 3) or
                    ((unsigned(bytes[offset + 5]) and 0xe0) ushr 5)
            if (frameBytes < headerBytes) return RecordingAdtsScan(frames, offset, offset)
            if (frameBytes > remaining) break
            offset += frameBytes
            frames += 1
        }
        return RecordingAdtsScan(frames, offset, null)
    }

    private fun unsigned(value: Byte): Int = value.toInt() and 0xff

    private const val HEADER_BYTES = 7
    private const val CRC_HEADER_BYTES = 9
}

object RecordingAdtsFrameCodec {
    fun wrap(
        accessUnit: ByteArray,
        sampleRateHz: Int,
        channelCount: Int,
    ): ByteArray {
        require(accessUnit.isNotEmpty()) { "AAC access unit must not be empty" }
        val sampleRateIndex = sampleRateIndexes[sampleRateHz] ?: error("unsupported ADTS sample rate")
        require(channelCount in 1..7) { "ADTS channel count must be between 1 and 7" }
        val frameLength = HEADER_BYTES + accessUnit.size
        require(frameLength <= MAX_FRAME_BYTES) { "ADTS frame is too large" }
        return byteArrayOf(
            0xff.toByte(),
            0xf1.toByte(),
            ((AAC_LC_PROFILE shl 6) or (sampleRateIndex shl 2) or (channelCount ushr 2)).toByte(),
            (((channelCount and 3) shl 6) or (frameLength ushr 11)).toByte(),
            ((frameLength ushr 3) and 0xff).toByte(),
            (((frameLength and 7) shl 5) or 0x1f).toByte(),
            0xfc.toByte(),
        ) + accessUnit
    }

    private const val AAC_LC_PROFILE = 1
    private const val HEADER_BYTES = 7
    private const val MAX_FRAME_BYTES = 0x1fff
    private val sampleRateIndexes =
        mapOf(
            96_000 to 0,
            88_200 to 1,
            64_000 to 2,
            48_000 to 3,
            44_100 to 4,
            32_000 to 5,
            24_000 to 6,
            22_050 to 7,
            16_000 to 8,
            12_000 to 9,
            11_025 to 10,
            8_000 to 11,
            7_350 to 12,
        )
}

private object RecordingCommitJournalCodec {
    fun encode(record: RecordingCommitRecord): ByteArray {
        require(record.sequence > 0)
        require(record.frameEndExclusive > 0)
        require(record.byteEndExclusive > 0)
        require(record.sampleEndExclusive > 0)
        val bytes = ByteArray(RECORD_BYTES)
        val buffer = ByteBuffer.wrap(bytes).order(ByteOrder.BIG_ENDIAN)
        buffer.putInt(MAGIC)
        buffer.putInt(VERSION)
        buffer.putLong(record.sequence)
        buffer.putLong(record.frameEndExclusive)
        buffer.putLong(record.byteEndExclusive)
        buffer.putLong(record.sampleEndExclusive)
        buffer.putLong(record.prefixCrc32)
        buffer.putLong(crc32(bytes, 0, CHECKSUM_OFFSET))
        return bytes
    }

    fun decodeCompletePrefix(bytes: ByteArray): List<RecordingCommitRecord> {
        val records = mutableListOf<RecordingCommitRecord>()
        var offset = 0
        while (bytes.size - offset >= RECORD_BYTES) {
            val buffer = ByteBuffer.wrap(bytes, offset, RECORD_BYTES).order(ByteOrder.BIG_ENDIAN)
            if (buffer.int != MAGIC || buffer.int != VERSION) break
            val record =
                RecordingCommitRecord(
                    sequence = buffer.long,
                    frameEndExclusive = buffer.long,
                    byteEndExclusive = buffer.long,
                    sampleEndExclusive = buffer.long,
                    prefixCrc32 = buffer.long,
                )
            val checksum = buffer.long
            if (checksum != crc32(bytes, offset, CHECKSUM_OFFSET)) break
            val previous = records.lastOrNull()
            if (
                record.sequence <= 0 ||
                record.frameEndExclusive <= 0 ||
                record.byteEndExclusive <= 0 ||
                record.sampleEndExclusive <= 0 ||
                previous != null &&
                (record.sequence != previous.sequence + 1 ||
                    record.frameEndExclusive <= previous.frameEndExclusive ||
                    record.byteEndExclusive <= previous.byteEndExclusive ||
                    record.sampleEndExclusive <= previous.sampleEndExclusive)
            ) {
                break
            }
            records += record
            offset += RECORD_BYTES
        }
        return records
    }

    private const val MAGIC = 0x4c_51_43_4d
    private const val VERSION = 1
    private const val CHECKSUM_OFFSET = 48
    private const val RECORD_BYTES = 56
}

object RecordingCommittedPrefixRecovery {
    fun recover(
        dataBytes: ByteArray,
        journalBytes: ByteArray,
    ): RecordingCommittedPrefix {
        val scan = RecordingAdtsScanner.scan(dataBytes)
        val record =
            RecordingCommitJournalCodec
                .decodeCompletePrefix(journalBytes)
                .asReversed()
                .firstOrNull { candidate -> candidate.matches(dataBytes, scan) }
        val committedBytes = record?.byteEndExclusive?.toInt() ?: 0
        return RecordingCommittedPrefix(
            committedFrames = record?.frameEndExclusive?.toInt() ?: 0,
            committedBytes = committedBytes,
            committedSamples = record?.sampleEndExclusive ?: 0,
            uncommittedOrInvalidBytes = dataBytes.size - committedBytes,
        )
    }

    private fun RecordingCommitRecord.matches(
        dataBytes: ByteArray,
        scan: RecordingAdtsScan,
    ): Boolean {
        if (byteEndExclusive > Int.MAX_VALUE || frameEndExclusive > Int.MAX_VALUE) return false
        val byteEnd = byteEndExclusive.toInt()
        return byteEnd <= scan.completeBytes &&
            frameEndExclusive.toInt() <= scan.completeFrames &&
            crc32(dataBytes, 0, byteEnd) == prefixCrc32
    }
}

private class RecordingDurableCommitStore private constructor(
    private val data: RandomAccessFile,
    private val journal: RandomAccessFile,
) : Closeable {
    private val prefixChecksum = CRC32()
    private var frameCount = 0L
    private var sampleCount = 0L
    private var sequence = 0L
    private var committedFrames = 0L

    fun appendFrame(
        frame: ByteArray,
        mediaSamples: Int,
    ) {
        require(mediaSamples > 0)
        val scan = RecordingAdtsScanner.scan(frame)
        require(scan.completeFrames == 1 && scan.completeBytes == frame.size && scan.invalidOffset == null)
        data.write(frame)
        prefixChecksum.update(frame)
        frameCount = Math.addExact(frameCount, 1)
        sampleCount = Math.addExact(sampleCount, mediaSamples.toLong())
    }

    fun hasUncommittedFrames(): Boolean = frameCount > committedFrames

    fun commit(): RecordingCommitRecord {
        check(hasUncommittedFrames()) { "commit requires new frames" }
        data.fd.sync()
        val record =
            RecordingCommitRecord(
                sequence = sequence + 1,
                frameEndExclusive = frameCount,
                byteEndExclusive = data.length(),
                sampleEndExclusive = sampleCount,
                prefixCrc32 = prefixChecksum.value,
            )
        journal.write(RecordingCommitJournalCodec.encode(record))
        journal.fd.sync()
        sequence = record.sequence
        committedFrames = frameCount
        return record
    }

    fun bytesWritten(): Long = data.length() + journal.length()

    override fun close() {
        var primary: Throwable? = null
        try {
            data.fd.sync()
        } catch (failure: Throwable) {
            primary = failure
        }
        try {
            data.close()
        } catch (failure: Throwable) {
            primary = primary.append(failure)
        }
        try {
            journal.close()
        } catch (failure: Throwable) {
            primary = primary.append(failure)
        }
        if (primary != null) throw primary
    }

    companion object {
        fun open(
            dataFile: File,
            journalFile: File,
        ): RecordingDurableCommitStore {
            require(!dataFile.exists() || dataFile.length() == 0L) { "data file must be empty" }
            require(!journalFile.exists() || journalFile.length() == 0L) { "journal file must be empty" }
            var data: RandomAccessFile? = null
            var journal: RandomAccessFile? = null
            try {
                data = RandomAccessFile(dataFile, "rw")
                journal = RandomAccessFile(journalFile, "rw")
                data.fd.sync()
                journal.fd.sync()
                return RecordingDurableCommitStore(data, journal)
            } catch (failure: Throwable) {
                runCatching { journal?.close() }.exceptionOrNull()?.let(failure::addSuppressed)
                runCatching { data?.close() }.exceptionOrNull()?.let(failure::addSuppressed)
                throw failure
            }
        }

        fun resetUncommitted(
            dataFile: File,
            journalFile: File,
        ): RecordingDurableCommitStore {
            var data: RandomAccessFile? = null
            var journal: RandomAccessFile? = null
            try {
                data = RandomAccessFile(dataFile, "rw")
                journal = RandomAccessFile(journalFile, "rw")
                data.setLength(0)
                data.fd.sync()
                journal.setLength(0)
                journal.fd.sync()
                return RecordingDurableCommitStore(data, journal)
            } catch (failure: Throwable) {
                runCatching { journal?.close() }.exceptionOrNull()?.let(failure::addSuppressed)
                runCatching { data?.close() }.exceptionOrNull()?.let(failure::addSuppressed)
                throw failure
            }
        }
    }
}

data class RecordingSegmentSnapshot(
    val segmentCount: Int,
    val totalFrames: Long,
    val totalSamples: Long,
    val bytesWritten: Long,
    val failureCode: String?,
)

sealed interface RecordingSegmentOpenResult {
    data class Success(
        val coordinator: RecordingSegmentCoordinator,
    ) : RecordingSegmentOpenResult

    data class Failure(
        val code: String,
    ) : RecordingSegmentOpenResult
}

sealed interface RecordingSegmentCommandResult {
    data class Success(
        val snapshot: RecordingSegmentSnapshot,
    ) : RecordingSegmentCommandResult

    data class Failure(
        val code: String,
        val snapshot: RecordingSegmentSnapshot,
    ) : RecordingSegmentCommandResult
}

class RecordingSegmentCoordinator private constructor(
    private val directory: File,
    private val sessionId: String,
    private val codecSpecificData: List<ByteArray>,
    private val policy: RecordingSegmentationPolicy,
    private val manifestStore: AtomicRecordingSegmentManifestStore,
    private val fileOperations: RecordingFileOperations,
) : Closeable {
    private val segments = mutableListOf<RecordingSegmentEntry>()
    private var currentStore: RecordingDurableCommitStore? = null
    private var currentSegmentFrames = 0
    private var totalFrames = 0L
    private var failureCode: String? = null
    private var finished = false

    @Synchronized
    fun appendAccessUnit(accessUnit: ByteArray): RecordingSegmentCommandResult {
        failureCode?.let { return failure(it) }
        if (finished) return failure("recording_segments_closed")
        return try {
            if (currentSegmentFrames == policy.framesPerSegment) rotate()
            val frame = RecordingAdtsFrameCodec.wrap(accessUnit, policy.sampleRateHz, CHANNEL_COUNT)
            checkNotNull(currentStore).appendFrame(frame, policy.samplesPerFrame)
            currentSegmentFrames += 1
            totalFrames = Math.addExact(totalFrames, 1)
            if (currentSegmentFrames % policy.commitFrames == 0) checkNotNull(currentStore).commit()
            success()
        } catch (_: Exception) {
            fail("recording_segment_write_failed")
        }
    }

    @Synchronized
    fun finish(): RecordingSegmentCommandResult {
        val existingFailure = failureCode
        if (finished) return existingFailure?.let(::failure) ?: success()
        if (existingFailure != null) {
            runCatching { currentStore?.close() }
            currentStore = null
            finished = true
            return failure(existingFailure)
        }
        return try {
            val store = checkNotNull(currentStore)
            if (store.hasUncommittedFrames()) store.commit()
            store.close()
            currentStore = null
            finished = true
            success()
        } catch (_: Exception) {
            fail("recording_segment_finalize_failed")
        }
    }

    @Synchronized
    fun snapshot(): RecordingSegmentSnapshot {
        val fileBytes =
            directory.listFiles()?.sumOf(File::length) ?: 0L
        return RecordingSegmentSnapshot(
            segmentCount = segments.size,
            totalFrames = totalFrames,
            totalSamples = totalFrames * policy.samplesPerFrame,
            bytesWritten = fileBytes,
            failureCode = failureCode,
        )
    }

    override fun close() {
        finish()
    }

    private fun rotate() {
        check(currentSegmentFrames == policy.framesPerSegment)
        checkNotNull(currentStore).close()
        currentStore = null
        openAndPublishSegment(segments.size)
        currentSegmentFrames = 0
    }

    private fun openAndPublishSegment(index: Int) {
        val entry =
            RecordingSegmentEntry(
                index = index,
                startSample = totalFrames * policy.samplesPerFrame,
                dataFileName = "segment-${index.toString().padStart(5, '0')}.adts",
                journalFileName = "segment-${index.toString().padStart(5, '0')}.commit",
            )
        val dataFile = File(directory, entry.dataFileName)
        val journalFile = File(directory, entry.journalFileName)
        val store = RecordingDurableCommitStore.open(dataFile, journalFile)
        if (!fileOperations.syncDirectory(directory)) {
            store.close()
            dataFile.delete()
            journalFile.delete()
            error("segment directory sync failed")
        }
        val candidateSegments = segments + entry
        val manifest = manifest(candidateSegments)
        if (manifestStore.publish(manifest) !is RecordingManifestWriteResult.Success) {
            store.close()
            error("segment manifest publication failed")
        }
        segments += entry
        currentStore = store
    }

    private fun manifest(entries: List<RecordingSegmentEntry>) =
        RecordingSegmentManifest(
            sessionId = sessionId,
            sampleRateHz = policy.sampleRateHz,
            channelCount = CHANNEL_COUNT,
            bitRateBitsPerSecond = BIT_RATE_BITS_PER_SECOND,
            codecSpecificData = codecSpecificData,
            segments = entries,
        )

    private fun success() = RecordingSegmentCommandResult.Success(snapshot())

    private fun failure(code: String) = RecordingSegmentCommandResult.Failure(code, snapshot())

    private fun fail(code: String): RecordingSegmentCommandResult.Failure {
        failureCode = code
        return failure(code)
    }

    companion object {
        fun open(
            directory: File,
            sessionId: String,
            codecSpecificData: List<ByteArray>,
            policy: RecordingSegmentationPolicy = RecordingSegmentationPolicy.production,
            fileOperations: RecordingFileOperations = AndroidRecordingFileOperations,
        ): RecordingSegmentOpenResult {
            if (directory.exists() && directory.list()?.isNotEmpty() == true) {
                return RecordingSegmentOpenResult.Failure("recording_segment_directory_not_empty")
            }
            if (!ensureDirectoryDurable(directory, fileOperations)) {
                return RecordingSegmentOpenResult.Failure("recording_segment_directory_failed")
            }
            val coordinator =
                RecordingSegmentCoordinator(
                    directory = directory,
                    sessionId = sessionId,
                    codecSpecificData = codecSpecificData.map(ByteArray::copyOf),
                    policy = policy,
                    manifestStore = AtomicRecordingSegmentManifestStore(directory, fileOperations),
                    fileOperations = fileOperations,
                )
            return try {
                coordinator.openAndPublishSegment(0)
                RecordingSegmentOpenResult.Success(coordinator)
            } catch (_: Exception) {
                RecordingSegmentOpenResult.Failure("recording_segment_initialize_failed")
            }
        }

        fun continueFromManifest(
            directory: File,
            sessionId: String,
            policy: RecordingSegmentationPolicy = RecordingSegmentationPolicy.production,
            fileOperations: RecordingFileOperations = AndroidRecordingFileOperations,
        ): RecordingSegmentOpenResult {
            if (!directory.isDirectory || sessionId.isBlank()) {
                return RecordingSegmentOpenResult.Failure("recording_continuation_invalid")
            }
            val manifest =
                when (val loaded = AtomicRecordingSegmentManifestStore(directory, fileOperations).load()) {
                    is RecordingSegmentManifestDecodeResult.Success -> loaded.manifest
                    is RecordingSegmentManifestDecodeResult.Corrupt -> {
                        return RecordingSegmentOpenResult.Failure(loaded.code)
                    }
                }
            if (
                manifest.sessionId != sessionId ||
                manifest.sampleRateHz != policy.sampleRateHz ||
                manifest.channelCount != CHANNEL_COUNT ||
                manifest.bitRateBitsPerSecond != BIT_RATE_BITS_PER_SECOND
            ) {
                return RecordingSegmentOpenResult.Failure("recording_continuation_manifest_mismatch")
            }
            val recovered =
                try {
                    manifest.segments.map { entry ->
                        val dataFile = File(directory, entry.dataFileName)
                        val journalFile = File(directory, entry.journalFileName)
                        if (!dataFile.isFile || !journalFile.isFile) {
                            return RecordingSegmentOpenResult.Failure("recording_continuation_segment_missing")
                        }
                        RecordingCommittedPrefixRecovery.recover(
                            dataFile.readBytes(),
                            journalFile.readBytes(),
                        )
                    }
                } catch (_: Exception) {
                    return RecordingSegmentOpenResult.Failure("recording_continuation_segment_invalid")
                }
            var expectedStartSample = 0L
            manifest.segments.zip(recovered).forEach { (entry, prefix) ->
                if (entry.startSample != expectedStartSample) {
                    return RecordingSegmentOpenResult.Failure("recording_continuation_timeline_invalid")
                }
                expectedStartSample = Math.addExact(expectedStartSample, prefix.committedSamples)
            }
            if (expectedStartSample % policy.samplesPerFrame != 0L) {
                return RecordingSegmentOpenResult.Failure("recording_continuation_timeline_invalid")
            }
            val coordinator =
                RecordingSegmentCoordinator(
                    directory = directory,
                    sessionId = sessionId,
                    codecSpecificData = manifest.codecSpecificData.map(ByteArray::copyOf),
                    policy = policy,
                    manifestStore = AtomicRecordingSegmentManifestStore(directory, fileOperations),
                    fileOperations = fileOperations,
                )
            return try {
                coordinator.segments += manifest.segments
                coordinator.totalFrames = expectedStartSample / policy.samplesPerFrame
                val trailingEntry = manifest.segments.last()
                val trailingPrefix = recovered.last()
                if (trailingPrefix.committedSamples == 0L) {
                    val dataFile = File(directory, trailingEntry.dataFileName)
                    val journalFile = File(directory, trailingEntry.journalFileName)
                    coordinator.currentStore =
                        RecordingDurableCommitStore.resetUncommitted(dataFile, journalFile)
                } else {
                    coordinator.openAndPublishSegment(manifest.segments.size)
                }
                RecordingSegmentOpenResult.Success(coordinator)
            } catch (_: Exception) {
                RecordingSegmentOpenResult.Failure("recording_continuation_initialize_failed")
            }
        }

        private const val CHANNEL_COUNT = 1
        private const val BIT_RATE_BITS_PER_SECOND = 64_000

        private fun ensureDirectoryDurable(
            directory: File,
            fileOperations: RecordingFileOperations,
        ): Boolean {
            if (directory.exists()) return directory.isDirectory
            val missing = mutableListOf<File>()
            var existingAncestor: File? = directory
            while (existingAncestor != null && !existingAncestor.exists()) {
                missing += existingAncestor
                existingAncestor = existingAncestor.parentFile
            }
            if (existingAncestor?.isDirectory != true) return false
            return try {
                missing.asReversed().all { child ->
                    val parent = child.parentFile ?: return@all false
                    child.mkdir() && fileOperations.syncDirectory(parent)
                }
            } catch (_: Exception) {
                false
            }
        }
    }
}

private fun Throwable?.append(additional: Throwable): Throwable =
    if (this == null) additional else apply { addSuppressed(additional) }

private fun crc32(
    bytes: ByteArray,
    offset: Int,
    length: Int,
): Long = CRC32().also { it.update(bytes, offset, length) }.value
