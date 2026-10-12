package com.loquiris.backup

import com.loquiris.recording.RecordingSegmentManifest
import com.loquiris.recording.RecordingSegmentManifestCodec
import com.loquiris.recording.RecordingSegmentManifestDecodeResult
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest

data class RestoreRecordingTransfer(
    val operationId: String,
    val sourceMeetingId: String,
    val targetMeetingId: String,
    val contentFingerprint: String,
)

sealed interface RestoreRecordingPublishResult {
    data class Success(
        val published: Boolean,
    ) : RestoreRecordingPublishResult

    data class Failure(
        val code: String,
    ) : RestoreRecordingPublishResult
}

class RestoreRecordingPublisher(
    private val filesRoot: File,
    private val fileOperations: RestoreFileOperations = AndroidRestoreFileOperations,
) {
    fun publish(request: RestoreRecordingTransfer): RestoreRecordingPublishResult {
        if (!valid(request)) return failure("restore_recording_request_invalid")
        val recordingsRoot = File(filesRoot.canonicalFile, RECORDINGS_DIRECTORY)
        val sourceKey = sha256(request.sourceMeetingId.toByteArray(Charsets.UTF_8))
        val targetKey = sha256(request.targetMeetingId.toByteArray(Charsets.UTF_8))
        val source =
            File(
                filesRoot,
                "$RESTORE_STAGING_DIRECTORY/${request.operationId}/$RECORDINGS_DIRECTORY/$sourceKey",
            ).canonicalFile
        val target = File(recordingsRoot, targetKey).canonicalFile
        val temporary = File(recordingsRoot, ".restore-${request.operationId}-$targetKey.tmp").canonicalFile
        if (!source.path.startsWith(filesRoot.canonicalPath + File.separator)) {
            return failure("restore_recording_source_invalid")
        }
        temporary.deleteRecursively()
        return try {
            val sourceContent = inspect(source, request.sourceMeetingId)
                ?: throw RestoreRecordingFailure("restore_recording_source_invalid")
            if (sourceContent.fingerprint != request.contentFingerprint) {
                throw RestoreRecordingFailure("restore_recording_fingerprint_mismatch")
            }
            if (target.exists()) {
                val targetContent = inspect(target, request.targetMeetingId)
                    ?: throw RestoreRecordingFailure("restore_recording_target_conflict")
                if (targetContent.fingerprint != request.contentFingerprint) {
                    throw RestoreRecordingFailure("restore_recording_target_conflict")
                }
                val marker = File(target, RESTORE_MARKER_NAME)
                if (marker.exists() && marker.readText() != request.operationId) {
                    throw RestoreRecordingFailure("restore_recording_target_conflict")
                }
                return RestoreRecordingPublishResult.Success(published = marker.isFile)
            }
            if (!recordingsRoot.isDirectory && !recordingsRoot.mkdirs()) {
                throw RestoreRecordingFailure("restore_recording_storage_unavailable")
            }
            if (!temporary.mkdirs()) {
                throw RestoreRecordingFailure("restore_recording_storage_unavailable")
            }
            sourceContent.manifest.segments.forEach { segment ->
                listOf(segment.dataFileName, segment.journalFileName).forEach { name ->
                    val sourceFile = File(source, name)
                    val targetFile = File(temporary, name)
                    FileInputStream(sourceFile).use { input ->
                        FileOutputStream(targetFile).use { output -> input.copyTo(output) }
                    }
                    if (!fileOperations.syncFile(targetFile)) {
                        throw RestoreRecordingFailure("restore_recording_sync_failed")
                    }
                }
            }
            val rewritten = sourceContent.manifest.copy(sessionId = request.targetMeetingId)
            val manifestFile = File(temporary, MANIFEST_FILE_NAME)
            manifestFile.writeBytes(RecordingSegmentManifestCodec.encode(rewritten))
            if (!fileOperations.syncFile(manifestFile) || !fileOperations.syncDirectory(temporary)) {
                throw RestoreRecordingFailure("restore_recording_sync_failed")
            }
            val copied = inspect(temporary, request.targetMeetingId)
                ?: throw RestoreRecordingFailure("restore_recording_copy_invalid")
            if (copied.fingerprint != request.contentFingerprint) {
                throw RestoreRecordingFailure("restore_recording_copy_invalid")
            }
            val marker = File(temporary, RESTORE_MARKER_NAME)
            marker.writeText(request.operationId)
            if (!fileOperations.syncFile(marker) || !fileOperations.syncDirectory(temporary)) {
                throw RestoreRecordingFailure("restore_recording_sync_failed")
            }
            if (!fileOperations.atomicMove(temporary, target)) {
                throw RestoreRecordingFailure("restore_recording_publish_failed")
            }
            if (!fileOperations.syncDirectory(recordingsRoot)) {
                target.deleteRecursively()
                throw RestoreRecordingFailure("restore_recording_sync_failed")
            }
            RestoreRecordingPublishResult.Success(published = true)
        } catch (failure: RestoreRecordingFailure) {
            temporary.deleteRecursively()
            failure(failure.code)
        } catch (_: Exception) {
            temporary.deleteRecursively()
            failure("restore_recording_publish_failed")
        }
    }

    fun fingerprints(meetingIds: List<String>): Map<String, String?>? {
        if (
            meetingIds.size > MAX_MEETINGS || meetingIds.distinct().size != meetingIds.size ||
            meetingIds.any { !validMeetingId(it) }
        ) {
            return null
        }
        val root = File(filesRoot.canonicalFile, RECORDINGS_DIRECTORY)
        return meetingIds.associateWith { meetingId ->
            val key = sha256(meetingId.toByteArray(Charsets.UTF_8))
            inspect(File(root, key), meetingId)?.fingerprint
        }
    }

    fun rollback(
        operationId: String,
        meetingIds: List<String>,
    ): Boolean {
        if (
            !OPERATION_ID.matches(operationId) ||
            meetingIds.size > MAX_MEETINGS || meetingIds.distinct().size != meetingIds.size ||
            meetingIds.any { !validMeetingId(it) }
        ) {
            return false
        }
        val root = File(filesRoot.canonicalFile, RECORDINGS_DIRECTORY)
        var deleted = false
        meetingIds.forEach { meetingId ->
            val key = sha256(meetingId.toByteArray(Charsets.UTF_8))
            val directory = File(root, key)
            val marker = File(directory, RESTORE_MARKER_NAME)
            if (directory.isDirectory && marker.isFile && marker.readText() == operationId) {
                if (!directory.deleteRecursively()) return false
                deleted = true
            }
        }
        return !deleted || fileOperations.syncDirectory(root)
    }

    fun finalize(
        operationId: String,
        meetingIds: List<String>,
    ): Boolean {
        if (
            !OPERATION_ID.matches(operationId) ||
            meetingIds.size > MAX_MEETINGS || meetingIds.distinct().size != meetingIds.size ||
            meetingIds.any { !validMeetingId(it) }
        ) {
            return false
        }
        val root = File(filesRoot.canonicalFile, RECORDINGS_DIRECTORY)
        var changed = false
        meetingIds.forEach { meetingId ->
            val directory = File(root, sha256(meetingId.toByteArray(Charsets.UTF_8)))
            val marker = File(directory, RESTORE_MARKER_NAME)
            if (!marker.isFile || marker.readText() != operationId || !marker.delete()) return false
            if (!fileOperations.syncDirectory(directory)) return false
            changed = true
        }
        return !changed || fileOperations.syncDirectory(root)
    }

    fun discardStaging(operationId: String): Boolean {
        if (!OPERATION_ID.matches(operationId)) return false
        val root = filesRoot.canonicalFile
        val staging = File(root, "$RESTORE_STAGING_DIRECTORY/$operationId").canonicalFile
        if (!staging.path.startsWith(root.path + File.separator)) return false
        if (staging.exists() && !staging.deleteRecursively()) return false
        val parent = File(root, RESTORE_STAGING_DIRECTORY)
        return !parent.isDirectory || fileOperations.syncDirectory(parent)
    }

    private fun inspect(
        directory: File,
        expectedMeetingId: String,
    ): RecordingContent? {
        if (!directory.isDirectory) return null
        val manifestFile = File(directory, MANIFEST_FILE_NAME)
        if (!manifestFile.isFile || manifestFile.length() > MAX_MANIFEST_BYTES) return null
        val manifest =
            when (val decoded = RecordingSegmentManifestCodec.decode(manifestFile.readBytes())) {
                is RecordingSegmentManifestDecodeResult.Success -> decoded.manifest
                is RecordingSegmentManifestDecodeResult.Corrupt -> return null
            }
        if (manifest.sessionId != expectedMeetingId) return null
        val expectedNames =
            manifest.segments.flatMap { segment -> listOf(segment.dataFileName, segment.journalFileName) }
        val actualNames =
            directory
                .listFiles()
                ?.filter(File::isFile)
                ?.map(File::getName)
                ?.filterNot { it == RESTORE_MARKER_NAME }
                ?.sorted() ?: return null
        if (actualNames != (expectedNames + MANIFEST_FILE_NAME).sorted()) return null
        val digests =
            expectedNames.map { name ->
                val file = File(directory, name)
                val digest = digest(file) ?: return null
                RestoreRecordingFileDigest(name, file.length(), digest)
            }
        val fingerprint =
            try {
                restoreRecordingFingerprint(manifest, digests)
            } catch (_: IllegalArgumentException) {
                return null
            }
        return RecordingContent(manifest, fingerprint)
    }

    private fun digest(file: File): String? =
        try {
            val digest = MessageDigest.getInstance(SHA_256)
            FileInputStream(file).use { input ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    if (read > 0) digest.update(buffer, 0, read)
                }
            }
            digest.digest().toHex()
        } catch (_: Exception) {
            null
        }

    private fun valid(request: RestoreRecordingTransfer): Boolean =
        OPERATION_ID.matches(request.operationId) &&
            validMeetingId(request.sourceMeetingId) &&
            validMeetingId(request.targetMeetingId) &&
            SHA256.matches(request.contentFingerprint)

    private fun validMeetingId(value: String): Boolean =
        value.isNotBlank() && value.toByteArray(Charsets.UTF_8).size <= MAX_MEETING_ID_BYTES

    private fun sha256(bytes: ByteArray): String =
        MessageDigest.getInstance(SHA_256).digest(bytes).toHex()

    private fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }

    private fun failure(code: String) = RestoreRecordingPublishResult.Failure(code)

    private data class RecordingContent(
        val manifest: RecordingSegmentManifest,
        val fingerprint: String,
    )

    private class RestoreRecordingFailure(
        val code: String,
    ) : Exception()

    private companion object {
        const val RESTORE_STAGING_DIRECTORY = "restore_staging"
        const val RECORDINGS_DIRECTORY = "recordings"
        const val MANIFEST_FILE_NAME = "segments.manifest"
        const val RESTORE_MARKER_NAME = ".restore-pending"
        const val SHA_256 = "SHA-256"
        const val MAX_MEETING_ID_BYTES = 512
        const val MAX_MANIFEST_BYTES = 1024 * 1024L
        const val MAX_MEETINGS = 10_000
        val OPERATION_ID = Regex("[A-Za-z0-9_-]{1,128}")
        val SHA256 = Regex("[a-f0-9]{64}")
    }
}
