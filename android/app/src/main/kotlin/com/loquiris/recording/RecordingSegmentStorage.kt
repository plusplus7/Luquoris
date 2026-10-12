package com.loquiris.recording

import android.system.Os
import android.system.OsConstants
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.zip.CRC32
import kotlin.math.max

data class RecordingSegmentEntry(
    val index: Int,
    val startSample: Long,
    val dataFileName: String,
    val journalFileName: String,
) {
    init {
        require(index >= 0) { "segment index must be non-negative" }
        require(startSample >= 0) { "segment start sample must be non-negative" }
        require(isSafeFileName(dataFileName)) { "unsafe segment data file name" }
        require(isSafeFileName(journalFileName)) { "unsafe segment journal file name" }
        require(dataFileName != journalFileName) { "segment files must be distinct" }
    }
}

data class RecordingSegmentManifest(
    val sessionId: String,
    val sampleRateHz: Int,
    val channelCount: Int,
    val bitRateBitsPerSecond: Int,
    val codecSpecificData: List<ByteArray>,
    val segments: List<RecordingSegmentEntry>,
) {
    init {
        require(sessionId.isNotBlank() && sessionId.toByteArray().size <= MAX_SESSION_ID_BYTES) {
            "sessionId must be non-blank and bounded"
        }
        require(sampleRateHz in 8_000..192_000) { "sample rate is unsupported" }
        require(channelCount in 1..8) { "channel count is unsupported" }
        require(bitRateBitsPerSecond > 0) { "bit rate must be positive" }
        require(codecSpecificData.isNotEmpty()) { "codec-specific data is required" }
        require(codecSpecificData.all { it.isNotEmpty() && it.size <= MAX_CODEC_CONFIG_BYTES }) {
            "codec-specific data is invalid"
        }
        require(segments.size <= MAX_SEGMENTS) { "too many segments" }
        require(segments.map(RecordingSegmentEntry::index) == segments.indices.toList()) {
            "segment indices must be contiguous"
        }
        require(segments.isEmpty() || segments.first().startSample == 0L) {
            "first segment must start at sample zero"
        }
        require(segments.zipWithNext().all { (first, second) -> first.startSample < second.startSample }) {
            "segment sample offsets must strictly increase"
        }
        val names = segments.flatMap { listOf(it.dataFileName, it.journalFileName) }
        require(names.distinct().size == names.size) { "segment file names must be unique" }
    }

    private companion object {
        const val MAX_SESSION_ID_BYTES = 512
        const val MAX_CODEC_CONFIG_BYTES = 64 * 1_024
        const val MAX_SEGMENTS = 10_000
    }
}

sealed interface RecordingSegmentManifestDecodeResult {
    data class Success(
        val manifest: RecordingSegmentManifest,
    ) : RecordingSegmentManifestDecodeResult

    data class Corrupt(
        val code: String,
    ) : RecordingSegmentManifestDecodeResult
}

object RecordingSegmentManifestCodec {
    fun encode(manifest: RecordingSegmentManifest): ByteArray {
        val payload =
            ByteArrayOutputStream().use { bytes ->
                DataOutputStream(bytes).use { output ->
                    output.writeUTF(manifest.sessionId)
                    output.writeInt(manifest.sampleRateHz)
                    output.writeInt(manifest.channelCount)
                    output.writeInt(manifest.bitRateBitsPerSecond)
                    output.writeInt(manifest.codecSpecificData.size)
                    manifest.codecSpecificData.forEach { config ->
                        output.writeInt(config.size)
                        output.write(config)
                    }
                    output.writeInt(manifest.segments.size)
                    manifest.segments.forEach { segment ->
                        output.writeInt(segment.index)
                        output.writeLong(segment.startSample)
                        output.writeUTF(segment.dataFileName)
                        output.writeUTF(segment.journalFileName)
                    }
                }
                bytes.toByteArray()
            }
        require(payload.size <= MAX_PAYLOAD_BYTES) { "manifest payload is too large" }
        val checksum = CRC32().apply { update(payload) }.value
        return ByteBuffer
            .allocate(HEADER_BYTES + payload.size)
            .order(ByteOrder.BIG_ENDIAN)
            .putInt(MAGIC)
            .putInt(VERSION)
            .putInt(payload.size)
            .putLong(checksum)
            .put(payload)
            .array()
    }

    fun decode(bytes: ByteArray): RecordingSegmentManifestDecodeResult {
        if (bytes.size < HEADER_BYTES || bytes.size > HEADER_BYTES + MAX_PAYLOAD_BYTES) return corrupt()
        return try {
            val frame = ByteBuffer.wrap(bytes).order(ByteOrder.BIG_ENDIAN)
            if (frame.int != MAGIC || frame.int != VERSION) return corrupt()
            val payloadLength = frame.int
            val expectedChecksum = frame.long
            if (payloadLength < 0 || payloadLength != frame.remaining()) return corrupt()
            val payload = ByteArray(payloadLength).also(frame::get)
            if (CRC32().apply { update(payload) }.value != expectedChecksum) return corrupt()
            val manifest = decodePayload(payload) ?: return corrupt()
            RecordingSegmentManifestDecodeResult.Success(manifest)
        } catch (_: RuntimeException) {
            corrupt()
        }
    }

    private fun decodePayload(payload: ByteArray): RecordingSegmentManifest? =
        DataInputStream(ByteArrayInputStream(payload)).use { input ->
            val sessionId = input.readUTF()
            val sampleRateHz = input.readInt()
            val channelCount = input.readInt()
            val bitRate = input.readInt()
            val configCount = input.readBoundedCount(MAX_CODEC_CONFIG_COUNT) ?: return null
            val configs =
                List(configCount) {
                    val length = input.readBoundedCount(MAX_CODEC_CONFIG_BYTES) ?: return null
                    ByteArray(length).also(input::readFully)
                }
            val segmentCount = input.readBoundedCount(MAX_SEGMENTS) ?: return null
            val segments =
                List(segmentCount) {
                    RecordingSegmentEntry(
                        index = input.readInt(),
                        startSample = input.readLong(),
                        dataFileName = input.readUTF(),
                        journalFileName = input.readUTF(),
                    )
                }
            if (input.available() != 0) return null
            RecordingSegmentManifest(
                sessionId = sessionId,
                sampleRateHz = sampleRateHz,
                channelCount = channelCount,
                bitRateBitsPerSecond = bitRate,
                codecSpecificData = configs,
                segments = segments,
            )
        }

    private fun DataInputStream.readBoundedCount(maximum: Int): Int? = readInt().takeIf { it in 0..maximum }

    private fun corrupt() = RecordingSegmentManifestDecodeResult.Corrupt("recording_manifest_corrupt")

    private const val MAGIC = 0x4C_51_53_4D
    private const val VERSION = 1
    private const val HEADER_BYTES = Int.SIZE_BYTES * 3 + Long.SIZE_BYTES
    private const val MAX_PAYLOAD_BYTES = 1024 * 1024
    private const val MAX_CODEC_CONFIG_COUNT = 16
    private const val MAX_CODEC_CONFIG_BYTES = 64 * 1_024
    private const val MAX_SEGMENTS = 10_000
}

interface RecordingFileOperations {
    fun writeAndSync(file: File, bytes: ByteArray): Boolean

    fun atomicReplace(source: File, target: File): Boolean

    fun syncDirectory(directory: File): Boolean
}

object AndroidRecordingFileOperations : RecordingFileOperations {
    override fun writeAndSync(file: File, bytes: ByteArray): Boolean =
        try {
            RandomAccessFile(file, "rw").use { output ->
                output.setLength(0)
                output.write(bytes)
                output.fd.sync()
            }
            true
        } catch (_: Exception) {
            false
        }

    override fun atomicReplace(source: File, target: File): Boolean =
        try {
            Files.move(
                source.toPath(),
                target.toPath(),
                StandardCopyOption.ATOMIC_MOVE,
                StandardCopyOption.REPLACE_EXISTING,
            )
            true
        } catch (_: Exception) {
            false
        }

    override fun syncDirectory(directory: File): Boolean =
        try {
            val descriptor = Os.open(directory.absolutePath, OsConstants.O_RDONLY, 0)
            try {
                Os.fsync(descriptor)
            } finally {
                Os.close(descriptor)
            }
            true
        } catch (_: Exception) {
            false
        }
}

sealed interface RecordingManifestWriteResult {
    data object Success : RecordingManifestWriteResult

    data class Failure(
        val code: String,
    ) : RecordingManifestWriteResult
}

class AtomicRecordingSegmentManifestStore(
    private val directory: File,
    private val operations: RecordingFileOperations = AndroidRecordingFileOperations,
) {
    fun publish(manifest: RecordingSegmentManifest): RecordingManifestWriteResult {
        if (!directory.isDirectory && !directory.mkdirs()) {
            return RecordingManifestWriteResult.Failure("recording_manifest_directory_failed")
        }
        val target = File(directory, MANIFEST_FILE_NAME)
        val temporary = File(directory, "$MANIFEST_FILE_NAME.tmp")
        val encoded = RecordingSegmentManifestCodec.encode(manifest)
        val wrote = tryOperation { operations.writeAndSync(temporary, encoded) }
        if (!wrote) return failureAndDelete(temporary, "write_failed")
        val replaced = tryOperation { operations.atomicReplace(temporary, target) }
        if (!replaced) return failureAndDelete(temporary, "replace_failed")
        val directorySynced = tryOperation { operations.syncDirectory(directory) }
        if (!directorySynced) {
            return RecordingManifestWriteResult.Failure("recording_manifest_directory_sync_failed")
        }
        return RecordingManifestWriteResult.Success
    }

    fun load(): RecordingSegmentManifestDecodeResult {
        val manifest = File(directory, MANIFEST_FILE_NAME)
        if (!manifest.isFile) {
            return RecordingSegmentManifestDecodeResult.Corrupt("recording_manifest_missing")
        }
        return try {
            RecordingSegmentManifestCodec.decode(manifest.readBytes())
        } catch (_: java.io.IOException) {
            RecordingSegmentManifestDecodeResult.Corrupt("recording_manifest_read_failed")
        }
    }

    private fun failureAndDelete(
        temporary: File,
        suffix: String,
    ): RecordingManifestWriteResult.Failure {
        temporary.delete()
        return RecordingManifestWriteResult.Failure("recording_manifest_$suffix")
    }

    private fun tryOperation(operation: () -> Boolean): Boolean =
        try {
            operation()
        } catch (_: Exception) {
            false
        }

    companion object {
        const val MANIFEST_FILE_NAME = "segments.manifest"
    }
}

data class AudioInputHealthSnapshot(
    val readCalls: Long,
    val pcmBytes: Long,
    val shortReads: Long,
    val zeroReads: Long,
    val errorReads: Long,
    val maximumReadGapNanos: Long,
    val timestampRegressions: Long,
)

class AudioInputHealthTracker(
    private val elapsedRealtimeNanos: () -> Long,
) {
    private var readCalls = 0L
    private var pcmBytes = 0L
    private var shortReads = 0L
    private var zeroReads = 0L
    private var errorReads = 0L
    private var maximumReadGapNanos = 0L
    private var lastReadAtNanos: Long? = null
    private var timestampRegressions = 0L
    private var lastFramePosition: Long? = null

    @Synchronized
    fun recordRead(
        requestedBytes: Int,
        result: Int,
    ) {
        require(requestedBytes > 0) { "requested bytes must be positive" }
        val now = elapsedRealtimeNanos()
        lastReadAtNanos?.let { previous -> maximumReadGapNanos = max(maximumReadGapNanos, max(0, now - previous)) }
        lastReadAtNanos = now
        readCalls += 1
        when {
            result < 0 -> errorReads += 1
            result == 0 -> zeroReads += 1
            else -> {
                pcmBytes = Math.addExact(pcmBytes, result.toLong())
                if (result < requestedBytes) shortReads += 1
            }
        }
    }

    @Synchronized
    fun recordTimestamp(framePosition: Long) {
        require(framePosition >= 0) { "frame position must be non-negative" }
        val previous = lastFramePosition
        if (previous != null && framePosition < previous) timestampRegressions += 1
        lastFramePosition = framePosition
    }

    @Synchronized
    fun snapshot(): AudioInputHealthSnapshot =
        AudioInputHealthSnapshot(
            readCalls = readCalls,
            pcmBytes = pcmBytes,
            shortReads = shortReads,
            zeroReads = zeroReads,
            errorReads = errorReads,
            maximumReadGapNanos = maximumReadGapNanos,
            timestampRegressions = timestampRegressions,
        )
}

private fun isSafeFileName(value: String): Boolean =
    value.isNotBlank() &&
        value.length <= 128 &&
        value != "." &&
        value != ".." &&
        value.all { character -> character.isLetterOrDigit() || character in setOf('.', '_', '-') }
