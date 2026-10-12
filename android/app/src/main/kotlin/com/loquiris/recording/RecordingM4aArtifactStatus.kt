package com.loquiris.recording

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap

enum class RecordingM4aArtifactState {
    building,
    ready,
    failed,
}

data class RecordingM4aArtifactStatus(
    val state: RecordingM4aArtifactState,
    val generation: String? = null,
    val fileName: String? = null,
    val accessUnitCount: Int = 0,
    val mediaSamples: Long = 0,
    val bytesWritten: Long = 0,
    val failureCode: String? = null,
)

sealed interface RecordingM4aArtifactStatusLoadResult {
    data class Loaded(
        val status: RecordingM4aArtifactStatus,
    ) : RecordingM4aArtifactStatusLoadResult

    data class Unavailable(
        val code: String,
    ) : RecordingM4aArtifactStatusLoadResult
}

class RecordingM4aArtifactStatusStore(
    private val directory: File,
    private val fileOperations: RecordingFileOperations = AndroidRecordingFileOperations,
) {
    fun publish(status: RecordingM4aArtifactStatus): Boolean {
        RecordingM4aArtifactAvailabilityGuard.quarantine(directory)
        val temporary = File(directory, "$STATUS_FILE_NAME.tmp")
        val target = File(directory, STATUS_FILE_NAME)
        val encoded = encode(status)
        if (!runCatching { fileOperations.writeAndSync(temporary, encoded) }.getOrDefault(false)) return false
        if (!runCatching { fileOperations.atomicReplace(temporary, target) }.getOrDefault(false)) {
            temporary.delete()
            return false
        }
        val directorySynced = runCatching { fileOperations.syncDirectory(directory) }.getOrDefault(false)
        if (directorySynced && status.state == RecordingM4aArtifactState.ready) {
            RecordingM4aArtifactAvailabilityGuard.allow(directory)
        }
        return directorySynced
    }

    fun load(): RecordingM4aArtifactStatusLoadResult {
        val file = File(directory, STATUS_FILE_NAME)
        if (!file.isFile) return RecordingM4aArtifactStatusLoadResult.Unavailable("recording_m4a_status_missing")
        return try {
            decode(file.readBytes())?.let(RecordingM4aArtifactStatusLoadResult::Loaded)
                ?: RecordingM4aArtifactStatusLoadResult.Unavailable("recording_m4a_status_corrupt")
        } catch (_: Exception) {
            RecordingM4aArtifactStatusLoadResult.Unavailable("recording_m4a_status_read_failed")
        }
    }

    private fun encode(status: RecordingM4aArtifactStatus): ByteArray =
        ByteArrayOutputStream().use { bytes ->
            DataOutputStream(bytes).use { output ->
                output.writeInt(MAGIC)
                output.writeInt(VERSION)
                output.writeUTF(status.state.name)
                output.writeUTF(status.generation.orEmpty())
                output.writeUTF(status.fileName.orEmpty())
                output.writeInt(status.accessUnitCount)
                output.writeLong(status.mediaSamples)
                output.writeLong(status.bytesWritten)
                output.writeUTF(status.failureCode.orEmpty())
            }
            bytes.toByteArray()
        }

    private fun decode(bytes: ByteArray): RecordingM4aArtifactStatus? =
        DataInputStream(ByteArrayInputStream(bytes)).use { input ->
            if (input.readInt() != MAGIC || input.readInt() != VERSION) return null
            val state = runCatching { RecordingM4aArtifactState.valueOf(input.readUTF()) }.getOrNull() ?: return null
            val generation = input.readUTF().ifEmpty { null }
            val fileName = input.readUTF().ifEmpty { null }
            val accessUnitCount = input.readInt()
            val mediaSamples = input.readLong()
            val bytesWritten = input.readLong()
            val failureCode = input.readUTF().ifEmpty { null }
            if (input.available() != 0 || accessUnitCount < 0 || mediaSamples < 0 || bytesWritten < 0) return null
            RecordingM4aArtifactStatus(
                state = state,
                generation = generation,
                fileName = fileName,
                accessUnitCount = accessUnitCount,
                mediaSamples = mediaSamples,
                bytesWritten = bytesWritten,
                failureCode = failureCode,
            )
        }

    companion object {
        const val STATUS_FILE_NAME = "playback.status"
        private const val MAGIC = 0x4c_51_50_53
        private const val VERSION = 1
    }
}

/** Prevents a visible but not durably published ready status being consumed in this process. */
object RecordingM4aArtifactAvailabilityGuard {
    private val quarantinedDirectories = ConcurrentHashMap.newKeySet<String>()

    fun quarantine(directory: File) {
        quarantinedDirectories += directory.absoluteFile.normalize().path
    }

    fun allow(directory: File) {
        quarantinedDirectories -= directory.absoluteFile.normalize().path
    }

    fun isQuarantined(directory: File): Boolean =
        directory.absoluteFile.normalize().path in quarantinedDirectories
}

sealed interface RecordingM4aSourceGenerationResult {
    data class Success(
        val value: String,
    ) : RecordingM4aSourceGenerationResult

    data class Failure(
        val code: String,
    ) : RecordingM4aSourceGenerationResult
}

object RecordingM4aSourceGeneration {
    fun compute(
        directory: File,
        fileOperations: RecordingFileOperations = AndroidRecordingFileOperations,
    ): RecordingM4aSourceGenerationResult {
        val manifest =
            when (val loaded = AtomicRecordingSegmentManifestStore(directory, fileOperations).load()) {
                is RecordingSegmentManifestDecodeResult.Success -> loaded.manifest
                is RecordingSegmentManifestDecodeResult.Corrupt ->
                    return RecordingM4aSourceGenerationResult.Failure(loaded.code)
            }
        return try {
            val digest = MessageDigest.getInstance("SHA-256")
            digest.update(RecordingSegmentManifestCodec.encode(manifest))
            var expectedStartSample = 0L
            manifest.segments.forEach { entry ->
                val dataFile = File(directory, entry.dataFileName)
                val journalFile = File(directory, entry.journalFileName)
                if (!dataFile.isFile || !journalFile.isFile) {
                    return RecordingM4aSourceGenerationResult.Failure("recording_m4a_segment_missing")
                }
                val dataBytes = dataFile.readBytes()
                val journalBytes = journalFile.readBytes()
                val recovered = RecordingCommittedPrefixRecovery.recover(dataBytes, journalBytes)
                if (
                    entry.startSample != expectedStartSample ||
                    recovered.committedSamples != recovered.committedFrames.toLong() * AAC_SAMPLES_PER_ACCESS_UNIT
                ) {
                    return RecordingM4aSourceGenerationResult.Failure("recording_m4a_timeline_invalid")
                }
                digest.update(journalBytes)
                digest.update(dataBytes, 0, recovered.committedBytes)
                digest.update(
                    ByteBuffer.allocate(Int.SIZE_BYTES + Long.SIZE_BYTES * 2)
                        .putInt(recovered.committedFrames)
                        .putLong(recovered.committedSamples)
                        .putLong(recovered.committedBytes.toLong())
                        .array(),
                )
                expectedStartSample = Math.addExact(expectedStartSample, recovered.committedSamples)
            }
            RecordingM4aSourceGenerationResult.Success(
                digest.digest().joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) },
            )
        } catch (_: Exception) {
            RecordingM4aSourceGenerationResult.Failure("recording_m4a_generation_failed")
        }
    }

    private const val AAC_SAMPLES_PER_ACCESS_UNIT = 1_024L
}

sealed interface RecordingM4aArtifactResolveResult {
    data class Ready(
        val file: File,
        val status: RecordingM4aArtifactStatus,
    ) : RecordingM4aArtifactResolveResult

    data class Unavailable(
        val code: String,
    ) : RecordingM4aArtifactResolveResult
}

class RecordingM4aArtifactResolver(
    private val fileOperations: RecordingFileOperations = AndroidRecordingFileOperations,
) {
    fun resolve(directory: File): RecordingM4aArtifactResolveResult {
        val status =
            when (val loaded = RecordingM4aArtifactStatusStore(directory, fileOperations).load()) {
                is RecordingM4aArtifactStatusLoadResult.Loaded -> loaded.status
                is RecordingM4aArtifactStatusLoadResult.Unavailable ->
                    return RecordingM4aArtifactResolveResult.Unavailable(loaded.code)
            }
        if (status.state != RecordingM4aArtifactState.ready) {
            return RecordingM4aArtifactResolveResult.Unavailable(
                status.failureCode ?: "recording_m4a_artifact_not_ready",
            )
        }
        if (RecordingM4aArtifactAvailabilityGuard.isQuarantined(directory)) {
            return RecordingM4aArtifactResolveResult.Unavailable("recording_m4a_artifact_quarantined")
        }
        val currentGeneration = RecordingM4aSourceGeneration.compute(directory, fileOperations)
        if (
            currentGeneration !is RecordingM4aSourceGenerationResult.Success ||
            currentGeneration.value != status.generation
        ) {
            return RecordingM4aArtifactResolveResult.Unavailable("recording_m4a_artifact_stale")
        }
        val fileName = status.fileName ?: return RecordingM4aArtifactResolveResult.Unavailable(
            "recording_m4a_artifact_invalid",
        )
        if (fileName != RecordingM4aRebuilder.OUTPUT_FILE_NAME) {
            return RecordingM4aArtifactResolveResult.Unavailable("recording_m4a_artifact_invalid")
        }
        val output = File(directory, fileName)
        if (!output.isFile || output.length() != status.bytesWritten) {
            return RecordingM4aArtifactResolveResult.Unavailable("recording_m4a_artifact_missing")
        }
        return RecordingM4aArtifactResolveResult.Ready(output, status)
    }
}
