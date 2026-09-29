package com.loquiris.spike

import java.io.Closeable
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.zip.CRC32

data class AdtsCommitRecord(
    val sequence: Long,
    val frameEndExclusive: Long,
    val byteEndExclusive: Long,
    val sampleEndExclusive: Long,
    val prefixCrc32: Long,
)

data class AdtsCommittedPrefix(
    val committedFrames: Int,
    val committedBytes: Int,
    val committedSamples: Long,
    val uncommittedOrInvalidBytes: Int,
)

object AdtsCommitJournal {
    fun encode(record: AdtsCommitRecord): ByteArray {
        require(record.sequence > 0) { "sequence must be positive" }
        require(record.frameEndExclusive > 0) { "frameEndExclusive must be positive" }
        require(record.byteEndExclusive > 0) { "byteEndExclusive must be positive" }
        require(record.sampleEndExclusive > 0) { "sampleEndExclusive must be positive" }
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

    fun decodeCompletePrefix(bytes: ByteArray): List<AdtsCommitRecord> {
        val records = mutableListOf<AdtsCommitRecord>()
        var offset = 0
        while (bytes.size - offset >= RECORD_BYTES) {
            val buffer = ByteBuffer.wrap(bytes, offset, RECORD_BYTES).order(ByteOrder.BIG_ENDIAN)
            if (buffer.int != MAGIC || buffer.int != VERSION) break
            val record =
                AdtsCommitRecord(
                    sequence = buffer.long,
                    frameEndExclusive = buffer.long,
                    byteEndExclusive = buffer.long,
                    sampleEndExclusive = buffer.long,
                    prefixCrc32 = buffer.long,
                )
            val storedChecksum = buffer.long
            if (storedChecksum != crc32(bytes, offset, CHECKSUM_OFFSET)) break
            if (!isMonotonicSuccessor(records.lastOrNull(), record)) break
            records += record
            offset += RECORD_BYTES
        }
        return records
    }

    private fun isMonotonicSuccessor(
        previous: AdtsCommitRecord?,
        next: AdtsCommitRecord,
    ): Boolean {
        if (
            next.sequence <= 0 ||
            next.frameEndExclusive <= 0 ||
            next.byteEndExclusive <= 0 ||
            next.sampleEndExclusive <= 0
        ) {
            return false
        }
        return previous == null ||
            next.sequence == previous.sequence + 1L &&
            next.frameEndExclusive > previous.frameEndExclusive &&
            next.byteEndExclusive > previous.byteEndExclusive &&
            next.sampleEndExclusive > previous.sampleEndExclusive
    }

    private const val MAGIC = 0x4C_51_43_4D
    private const val VERSION = 1
    private const val CHECKSUM_OFFSET = 48
    private const val RECORD_BYTES = 56
}

object AdtsCommittedPrefixRecovery {
    fun recover(
        dataBytes: ByteArray,
        journalBytes: ByteArray,
    ): AdtsCommittedPrefix {
        val scanned = AdtsRecoveryScanner.scan(dataBytes)
        val record =
            AdtsCommitJournal.decodeCompletePrefix(journalBytes)
                .asReversed()
                .firstOrNull { candidate -> candidate.matches(dataBytes, scanned) }
        val committedBytes = record?.byteEndExclusive?.toInt() ?: 0
        return AdtsCommittedPrefix(
            committedFrames = record?.frameEndExclusive?.toInt() ?: 0,
            committedBytes = committedBytes,
            committedSamples = record?.sampleEndExclusive ?: 0L,
            uncommittedOrInvalidBytes = dataBytes.size - committedBytes,
        )
    }

    private fun AdtsCommitRecord.matches(
        dataBytes: ByteArray,
        scanned: AdtsRecoveryResult,
    ): Boolean {
        if (byteEndExclusive > Int.MAX_VALUE || frameEndExclusive > Int.MAX_VALUE) return false
        val byteEnd = byteEndExclusive.toInt()
        val frameEnd = frameEndExclusive.toInt()
        return byteEnd <= scanned.completeBytes &&
            frameEnd <= scanned.completeFrames &&
            crc32(dataBytes, 0, byteEnd) == prefixCrc32
    }
}

class AdtsDurableCommitStore private constructor(
    private val data: RandomAccessFile,
    private val journal: RandomAccessFile,
) : Closeable {
    private val prefixChecksum = CRC32()
    private var frameCount = 0L
    private var sampleCount = 0L
    private var commitSequence = 0L
    private var lastCommittedFrameCount = 0L

    fun appendFrame(
        frame: ByteArray,
        mediaSamples: Int,
    ) {
        require(mediaSamples > 0) { "mediaSamples must be positive" }
        val scan = AdtsRecoveryScanner.scan(frame)
        require(
            scan.completeFrames == 1 &&
                scan.completeBytes == frame.size &&
                scan.invalidOffset == null,
        ) { "frame must contain exactly one complete ADTS frame" }
        val nextSampleCount = Math.addExact(sampleCount, mediaSamples.toLong())
        data.write(frame)
        prefixChecksum.update(frame)
        frameCount += 1L
        sampleCount = nextSampleCount
    }

    fun commit(): AdtsCommitRecord {
        check(frameCount > lastCommittedFrameCount) { "commit requires new frames" }
        data.fd.sync()
        val record =
            AdtsCommitRecord(
                sequence = commitSequence + 1L,
                frameEndExclusive = frameCount,
                byteEndExclusive = data.length(),
                sampleEndExclusive = sampleCount,
                prefixCrc32 = prefixChecksum.value,
            )
        journal.write(AdtsCommitJournal.encode(record))
        journal.fd.sync()
        commitSequence = record.sequence
        lastCommittedFrameCount = frameCount
        return record
    }

    override fun close() {
        var failure: Throwable? = null
        try {
            data.fd.sync()
        } catch (caught: Throwable) {
            failure = caught
        }
        try {
            data.close()
        } catch (caught: Throwable) {
            failure = appendFailure(failure, caught)
        }
        try {
            journal.close()
        } catch (caught: Throwable) {
            failure = appendFailure(failure, caught)
        }
        if (failure != null) throw failure
    }

    companion object {
        fun open(
            dataFile: File,
            journalFile: File,
        ): AdtsDurableCommitStore = open(dataFile, journalFile) { file -> RandomAccessFile(file, "rw") }

        internal fun open(
            dataFile: File,
            journalFile: File,
            opener: (File) -> RandomAccessFile,
        ): AdtsDurableCommitStore {
            require(dataFile.length() == 0L) { "data file must be empty" }
            require(journalFile.length() == 0L) { "journal file must be empty" }
            var data: RandomAccessFile? = null
            var journal: RandomAccessFile? = null
            try {
                data = opener(dataFile)
                journal = opener(journalFile)
                require(data.length() == 0L) { "data file must be empty" }
                require(journal.length() == 0L) { "journal file must be empty" }
                return AdtsDurableCommitStore(data, journal)
            } catch (failure: Throwable) {
                closeAfterOpenFailure(journal, failure)
                closeAfterOpenFailure(data, failure)
                throw failure
            }
        }

        private fun closeAfterOpenFailure(
            file: RandomAccessFile?,
            primary: Throwable,
        ) {
            try {
                file?.close()
            } catch (closeFailure: Throwable) {
                primary.addSuppressed(closeFailure)
            }
        }
    }
}

private fun appendFailure(
    primary: Throwable?,
    additional: Throwable,
): Throwable =
    if (primary == null) {
        additional
    } else {
        primary.apply { addSuppressed(additional) }
    }

private fun crc32(
    bytes: ByteArray,
    offset: Int,
    length: Int,
): Long = CRC32().also { it.update(bytes, offset, length) }.value
