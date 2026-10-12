package com.loquiris.backup

import com.loquiris.recording.RecordingSegmentManifestCodec
import com.loquiris.recording.RecordingSegmentManifestDecodeResult
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.security.MessageDigest
import java.time.Instant
import java.util.zip.ZipEntry
import java.util.zip.ZipFile

data class BackupVerificationRequest(
    val operationId: String,
    val archiveRelativePath: String,
    val currentSchemaVersion: Int,
)

sealed interface BackupVerificationResult {
    data class Success(
        val formatVersion: Int,
        val schemaVersion: Int,
        val exportedAtUtc: String,
        val databaseRelativePath: String,
        val checksumIndexRelativePath: String,
        val stagingRelativePath: String,
        val recordings: List<VerifiedRestoreRecording>,
    ) : BackupVerificationResult

    data class Failure(
        val code: String,
    ) : BackupVerificationResult
}

data class VerifiedRestoreRecording(
    val sourceMeetingId: String,
    val storageKey: String,
    val contentFingerprint: String,
    val segments: List<VerifiedRestoreSegment>,
)

data class VerifiedRestoreSegment(
    val fileName: String,
    val committedBytes: Long,
)

interface RestoreFileOperations {
    fun syncFile(file: File): Boolean

    fun atomicMove(
        source: File,
        target: File,
    ): Boolean

    fun syncDirectory(directory: File): Boolean
}

object AndroidRestoreFileOperations : RestoreFileOperations {
    override fun syncFile(file: File): Boolean = AndroidBackupFileOperations.syncFile(file)

    override fun atomicMove(
        source: File,
        target: File,
    ): Boolean = AndroidBackupFileOperations.atomicMove(source, target)

    override fun syncDirectory(directory: File): Boolean = AndroidBackupFileOperations.syncDirectory(directory)
}

class BackupPackageReader(
    private val filesRoot: File,
    private val fileOperations: RestoreFileOperations = AndroidRestoreFileOperations,
    private val availableBytes: (File) -> Long = { it.usableSpace },
) {
    fun verifyAndStage(request: BackupVerificationRequest): BackupVerificationResult {
        if (
            !OPERATION_ID.matches(request.operationId) || request.currentSchemaVersion <= 0 ||
            !ARCHIVE_PATH.matches(request.archiveRelativePath)
        ) {
            return failure("restore_request_invalid")
        }
        val root = filesRoot.canonicalFile
        val archive = resolveBelow(root, request.archiveRelativePath) ?: return failure("restore_archive_path_invalid")
        if (!archive.isFile) return failure("restore_archive_missing")
        val stagingRoot = File(root, RESTORE_STAGING_DIRECTORY)
        val temporary = File(stagingRoot, ".${request.operationId}.tmp")
        val target = File(stagingRoot, request.operationId)
        if (target.exists()) return failure("restore_staging_exists")
        temporary.deleteRecursively()
        return try {
            ZipFile(archive).use { zip ->
                val entries = zip.entries().asSequence().toList()
                if (entries.size !in 3..MAX_ENTRIES || entries.map(ZipEntry::getName).distinct().size != entries.size) {
                    throw RestoreFailure("restore_entry_set_invalid")
                }
                if (entries[0].name != MANIFEST_PATH || entries[1].name != CHECKSUM_PATH) {
                    throw RestoreFailure("restore_entry_order_invalid")
                }
                val manifestBytes = zip.getInputStream(entries[0]).use { it.readBounded(MAX_MANIFEST_BYTES) }
                val checksumBytes = zip.getInputStream(entries[1]).use { it.readBounded(MAX_CHECKSUM_BYTES) }
                val manifest = parseManifest(manifestBytes, request.currentSchemaVersion)
                if (sha256(checksumBytes) != manifest.checksumSha256) {
                    throw RestoreFailure("restore_checksum_index_mismatch")
                }
                val checksums = parseChecksums(checksumBytes)
                val expectedNames = listOf(MANIFEST_PATH, CHECKSUM_PATH) + checksums.map(ChecksumEntry::path)
                if (entries.map(ZipEntry::getName) != expectedNames) {
                    throw RestoreFailure("restore_entry_set_invalid")
                }
                val totalBytes = checksums.fold(0L) { total, entry -> Math.addExact(total, entry.bytes) }
                val stagingCapacity = (availableBytes(root) - MIN_FREE_BYTES).coerceAtLeast(0L)
                if (totalBytes > MAX_TOTAL_BYTES || totalBytes > stagingCapacity) {
                    throw RestoreFailure("restore_insufficient_storage")
                }
                if (!temporary.mkdirs()) throw RestoreFailure("restore_staging_unavailable")
                val checksumTarget = File(temporary, CHECKSUM_STAGING_NAME)
                checksumTarget.writeBytes(checksumBytes)
                if (!fileOperations.syncFile(checksumTarget)) throw RestoreFailure("restore_staging_sync_failed")
                checksums.forEachIndexed { index, expected ->
                    val sourceEntry = entries[index + 2]
                    val relativeTarget = expected.path.removePrefix(PAYLOAD_PREFIX)
                    val output = File(temporary, relativeTarget)
                    val canonicalOutput = output.canonicalFile
                    if (!canonicalOutput.path.startsWith(temporary.canonicalPath + File.separator)) {
                        throw RestoreFailure("restore_payload_path_invalid")
                    }
                    val parent = requireNotNull(canonicalOutput.parentFile)
                    if (!parent.isDirectory && !parent.mkdirs()) {
                        throw RestoreFailure("restore_staging_unavailable")
                    }
                    val actual =
                        FileOutputStream(canonicalOutput).use { destination ->
                            zip.getInputStream(sourceEntry).use { source ->
                                source.copyAndHash(destination, expected.bytes)
                            }
                        }
                    if (actual.bytes != expected.bytes || actual.sha256 != expected.sha256) {
                        throw RestoreFailure("restore_payload_checksum_mismatch")
                    }
                    if (!fileOperations.syncFile(canonicalOutput)) {
                        throw RestoreFailure("restore_staging_sync_failed")
                    }
                }
                val recordings = verifyStagedRecordings(temporary, checksums)
                temporary.walkBottomUp().filter(File::isDirectory).forEach { directory ->
                    if (!fileOperations.syncDirectory(directory)) {
                        throw RestoreFailure("restore_staging_sync_failed")
                    }
                }
                if (!stagingRoot.isDirectory && !stagingRoot.mkdirs()) {
                    throw RestoreFailure("restore_staging_unavailable")
                }
                if (!fileOperations.atomicMove(temporary, target)) {
                    throw RestoreFailure("restore_staging_publish_failed")
                }
                if (!fileOperations.syncDirectory(stagingRoot)) {
                    target.deleteRecursively()
                    throw RestoreFailure("restore_staging_sync_failed")
                }
                BackupVerificationResult.Success(
                    formatVersion = manifest.formatVersion,
                    schemaVersion = manifest.schemaVersion,
                    exportedAtUtc = manifest.exportedAtUtc,
                    databaseRelativePath = "$RESTORE_STAGING_DIRECTORY/${request.operationId}/database/loquiris.sqlite",
                    checksumIndexRelativePath = "$RESTORE_STAGING_DIRECTORY/${request.operationId}/$CHECKSUM_STAGING_NAME",
                    stagingRelativePath = "$RESTORE_STAGING_DIRECTORY/${request.operationId}",
                    recordings = recordings,
                )
            }
        } catch (failure: RestoreFailure) {
            temporary.deleteRecursively()
            failure(failure.code)
        } catch (_: Exception) {
            temporary.deleteRecursively()
            failure("restore_archive_invalid")
        }
    }

    private fun verifyStagedRecordings(
        temporary: File,
        checksums: List<ChecksumEntry>,
    ): List<VerifiedRestoreRecording> {
        val recordingEntries = checksums.filter { it.path.startsWith(RECORDING_PREFIX) }
        return recordingEntries
            .groupBy { it.path.substringAfter(RECORDING_PREFIX).substringBefore('/') }
            .toSortedMap()
            .map { (storageKey, entries) ->
                val manifestEntry =
                    entries.singleOrNull { it.path.endsWith("/segments.manifest") }
                        ?: throw RestoreFailure("restore_recording_manifest_invalid")
                val manifestFile =
                    File(
                        temporary,
                        manifestEntry.path.removePrefix(PAYLOAD_PREFIX),
                    )
                val manifest =
                    when (val decoded = RecordingSegmentManifestCodec.decode(manifestFile.readBytes())) {
                        is RecordingSegmentManifestDecodeResult.Success -> decoded.manifest
                        is RecordingSegmentManifestDecodeResult.Corrupt ->
                            throw RestoreFailure("restore_recording_manifest_invalid")
                    }
                if (sha256(manifest.sessionId.toByteArray(Charsets.UTF_8)) != storageKey) {
                    throw RestoreFailure("restore_recording_identity_mismatch")
                }
                val fileDigests =
                    entries
                        .filterNot { it === manifestEntry }
                        .map { entry ->
                            RestoreRecordingFileDigest(
                                name = entry.path.substringAfterLast('/'),
                                bytes = entry.bytes,
                                sha256 = entry.sha256,
                            )
                        }
                val fingerprint =
                    try {
                        restoreRecordingFingerprint(manifest, fileDigests)
                    } catch (_: IllegalArgumentException) {
                        throw RestoreFailure("restore_recording_entry_set_invalid")
                    }
                VerifiedRestoreRecording(
                    sourceMeetingId = manifest.sessionId,
                    storageKey = storageKey,
                    contentFingerprint = fingerprint,
                    segments =
                        manifest.segments.map { segment ->
                            val data = requireNotNull(fileDigests.singleOrNull { it.name == segment.dataFileName })
                            VerifiedRestoreSegment(
                                fileName = segment.dataFileName,
                                committedBytes = data.bytes,
                            )
                        },
                )
            }
    }

    private fun parseManifest(
        bytes: ByteArray,
        currentSchemaVersion: Int,
    ): ParsedManifest {
        val values = StrictBackupJson.parse(bytes) as? Map<*, *> ?: throw RestoreFailure("restore_manifest_invalid")
        if (values.keys != MANIFEST_KEYS) throw RestoreFailure("restore_manifest_invalid")
        val formatVersion = values["formatVersion"].positiveInt() ?: throw RestoreFailure("restore_manifest_invalid")
        val schemaVersion = values["schemaVersion"].positiveInt() ?: throw RestoreFailure("restore_manifest_invalid")
        val appVersion = values["appVersion"] as? String ?: throw RestoreFailure("restore_manifest_invalid")
        val exportedAtUtc = values["exportedAtUtc"] as? String ?: throw RestoreFailure("restore_manifest_invalid")
        val encrypted = values["encrypted"] as? Boolean ?: throw RestoreFailure("restore_manifest_invalid")
        val checksums = values["checksums"] as? Map<*, *> ?: throw RestoreFailure("restore_manifest_invalid")
        val checksumPath = checksums["path"] as? String
        val checksumSha256 = checksums["sha256"] as? String
        if (
            formatVersion != SUPPORTED_FORMAT_VERSION || schemaVersion > currentSchemaVersion ||
            schemaVersion <= 0 || appVersion.isBlank() || appVersion.length > 128 ||
            runCatching { Instant.parse(exportedAtUtc) }.isFailure || encrypted ||
            checksums.keys != CHECKSUM_REFERENCE_KEYS || checksumPath != CHECKSUM_PATH ||
            checksumSha256 == null || !SHA256.matches(checksumSha256)
        ) {
            throw RestoreFailure(
                if (schemaVersion > currentSchemaVersion) "restore_schema_unsupported" else "restore_manifest_invalid",
            )
        }
        return ParsedManifest(formatVersion, schemaVersion, exportedAtUtc, checksumSha256)
    }

    private fun parseChecksums(bytes: ByteArray): List<ChecksumEntry> {
        val values = StrictBackupJson.parse(bytes) as? Map<*, *> ?: throw RestoreFailure("restore_checksums_invalid")
        if (values.keys != CHECKSUM_INDEX_KEYS || values["schemaVersion"].positiveInt() != 1) {
            throw RestoreFailure("restore_checksums_invalid")
        }
        val rawEntries = values["entries"] as? List<*> ?: throw RestoreFailure("restore_checksums_invalid")
        if (rawEntries.size !in 1..MAX_ENTRIES - 2) throw RestoreFailure("restore_checksums_invalid")
        val parsed =
            rawEntries.map { rawEntry ->
                val entry = rawEntry as? Map<*, *> ?: throw RestoreFailure("restore_checksums_invalid")
                val path = entry["path"] as? String ?: throw RestoreFailure("restore_checksums_invalid")
                val count = entry["bytes"] as? Long ?: throw RestoreFailure("restore_checksums_invalid")
                val digest = entry["sha256"] as? String ?: throw RestoreFailure("restore_checksums_invalid")
                if (
                    entry.keys != CHECKSUM_ENTRY_KEYS || !isAllowedPayloadPath(path) ||
                    count < 0 || !SHA256.matches(digest)
                ) {
                    throw RestoreFailure("restore_checksums_invalid")
                }
                ChecksumEntry(path, count, digest)
            }
        if (
            parsed.map(ChecksumEntry::path).distinct().size != parsed.size ||
            parsed.map(ChecksumEntry::path) != parsed.map(ChecksumEntry::path).sorted() ||
            parsed.count { it.path == DATABASE_PATH } != 1
        ) {
            throw RestoreFailure("restore_checksums_invalid")
        }
        return parsed
    }

    private fun InputStream.readBounded(maximumBytes: Int): ByteArray {
        val output = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        while (true) {
            val read = read(buffer)
            if (read < 0) return output.toByteArray()
            if (read == 0) continue
            if (output.size() > maximumBytes - read) throw RestoreFailure("restore_metadata_too_large")
            output.write(buffer, 0, read)
        }
    }

    private fun InputStream.copyAndHash(
        output: FileOutputStream,
        expectedBytes: Long,
    ): PayloadDigest {
        val digest = MessageDigest.getInstance(SHA_256)
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        var count = 0L
        while (true) {
            val read = read(buffer)
            if (read < 0) break
            if (read == 0) continue
            count = Math.addExact(count, read.toLong())
            if (count > expectedBytes) throw RestoreFailure("restore_payload_checksum_mismatch")
            digest.update(buffer, 0, read)
            output.write(buffer, 0, read)
        }
        return PayloadDigest(count, digest.digest().toHex())
    }

    private fun resolveBelow(
        root: File,
        relativePath: String,
    ): File? {
        val resolved = File(root, relativePath).canonicalFile
        return resolved.takeIf { it.path.startsWith(root.path + File.separator) }
    }

    private fun isAllowedPayloadPath(path: String): Boolean =
        path == DATABASE_PATH || RECORDING_PATH.matches(path)

    private fun sha256(bytes: ByteArray): String =
        MessageDigest.getInstance(SHA_256).digest(bytes).toHex()

    private fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }

    private fun Any?.positiveInt(): Int? =
        (this as? Long)?.takeIf { it in 1..Int.MAX_VALUE }?.toInt()

    private fun failure(code: String) = BackupVerificationResult.Failure(code)

    private data class ParsedManifest(
        val formatVersion: Int,
        val schemaVersion: Int,
        val exportedAtUtc: String,
        val checksumSha256: String,
    )

    private data class ChecksumEntry(
        val path: String,
        val bytes: Long,
        val sha256: String,
    )

    private data class PayloadDigest(
        val bytes: Long,
        val sha256: String,
    )

    private class RestoreFailure(
        val code: String,
    ) : IOException()

    private companion object {
        const val SUPPORTED_FORMAT_VERSION = 1
        const val RESTORE_STAGING_DIRECTORY = "restore_staging"
        const val CHECKSUM_STAGING_NAME = "checksums.json"
        const val MANIFEST_PATH = "manifest.json"
        const val CHECKSUM_PATH = "payload/checksums.json"
        const val PAYLOAD_PREFIX = "payload/"
        const val RECORDING_PREFIX = "payload/recordings/"
        const val DATABASE_PATH = "payload/database/loquiris.sqlite"
        const val SHA_256 = "SHA-256"
        const val MAX_ENTRIES = 20_000
        const val MAX_MANIFEST_BYTES = 1024 * 1024
        const val MAX_CHECKSUM_BYTES = 16 * 1024 * 1024
        const val MAX_TOTAL_BYTES = 64L * 1024 * 1024 * 1024
        const val MIN_FREE_BYTES = 32L * 1024 * 1024
        val OPERATION_ID = Regex("[A-Za-z0-9_-]{1,128}")
        val ARCHIVE_PATH = Regex("(?:backups|restore_imports)/[A-Za-z0-9_.-]{1,192}\\.zip")
        val SHA256 = Regex("[a-f0-9]{64}")
        val RECORDING_PATH =
            Regex("payload/recordings/[a-f0-9]{64}/(?:segments\\.manifest|segment-[0-9]{5,}\\.(?:adts|commit))")
        val MANIFEST_KEYS =
            setOf("formatVersion", "schemaVersion", "appVersion", "exportedAtUtc", "encrypted", "checksums")
        val CHECKSUM_REFERENCE_KEYS = setOf("path", "sha256")
        val CHECKSUM_INDEX_KEYS = setOf("schemaVersion", "entries")
        val CHECKSUM_ENTRY_KEYS = setOf("path", "bytes", "sha256")
    }
}
