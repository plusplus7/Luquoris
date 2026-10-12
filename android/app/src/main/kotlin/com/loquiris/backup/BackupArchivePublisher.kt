package com.loquiris.backup

import android.system.Os
import android.system.OsConstants
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.file.Files
import java.nio.file.StandardCopyOption

data class BackupArchiveRequest(
    val operationId: String,
    val schemaVersion: Int,
    val exportedAtUtc: String,
    val snapshotRelativePath: String,
    val audioPlan: List<BackupAudioPlanEntry>,
)

sealed interface BackupArchiveResult {
    data class Success(
        val relativePath: String,
        val sha256: String,
        val bytes: Long,
    ) : BackupArchiveResult

    data class Failure(
        val code: String,
    ) : BackupArchiveResult
}

interface BackupFileOperations {
    fun syncFile(file: File): Boolean

    fun atomicMove(
        source: File,
        target: File,
    ): Boolean

    fun syncDirectory(directory: File): Boolean
}

object AndroidBackupFileOperations : BackupFileOperations {
    override fun syncFile(file: File): Boolean =
        try {
            RandomAccessFile(file, "r").use { it.fd.sync() }
            true
        } catch (_: Exception) {
            false
        }

    override fun atomicMove(
        source: File,
        target: File,
    ): Boolean =
        try {
            Files.move(source.toPath(), target.toPath(), StandardCopyOption.ATOMIC_MOVE)
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

class BackupArchivePublisher(
    private val filesRoot: File,
    private val appVersion: String,
    private val writer: BackupPackageWriter = BackupPackageWriter(),
    private val fileOperations: BackupFileOperations = AndroidBackupFileOperations,
) {
    fun create(request: BackupArchiveRequest): BackupArchiveResult {
        if (!OPERATION_ID.matches(request.operationId)) return failure("backup_request_invalid")
        val snapshot = safeSnapshotForCleanup(request.snapshotRelativePath)
        return try {
            val collected =
                BackupPayloadCollector(filesRoot).collect(
                    snapshotRelativePath = request.snapshotRelativePath,
                    audioPlan = request.audioPlan,
                )
            val sources =
                when (collected) {
                    is BackupPayloadCollectionResult.Success -> collected.sources
                    is BackupPayloadCollectionResult.Failure -> return failure(collected.code)
                }
            val directory = File(filesRoot, BACKUPS_DIRECTORY)
            if (!directory.isDirectory && !directory.mkdirs()) return failure("backup_directory_failed")
            val relativePath = "$BACKUPS_DIRECTORY/loquiris-backup-${request.operationId}.zip"
            val target = File(filesRoot, relativePath)
            if (target.exists()) return failure("backup_target_exists")
            val temporary = File(directory, ".${request.operationId}.zip.tmp")
            temporary.delete()
            val written =
                FileOutputStream(temporary).use { output ->
                    writer.write(
                        BackupPackageRequest(
                            formatVersion = FORMAT_VERSION,
                            schemaVersion = request.schemaVersion,
                            appVersion = appVersion,
                            exportedAtUtc = request.exportedAtUtc,
                            sources = sources,
                        ),
                        output,
                    )
                }
            val success = written as? BackupWriteResult.Success
            if (success == null) {
                temporary.delete()
                return failure((written as BackupWriteResult.Failure).code)
            }
            if (!fileOperations.syncFile(temporary)) {
                temporary.delete()
                return failure("backup_sync_failed")
            }
            if (!fileOperations.atomicMove(temporary, target)) {
                temporary.delete()
                return failure("backup_publish_failed")
            }
            if (!fileOperations.syncDirectory(directory)) {
                target.delete()
                return failure("backup_directory_sync_failed")
            }
            BackupArchiveResult.Success(relativePath, success.sha256, success.bytesWritten)
        } catch (_: Exception) {
            failure("backup_create_failed")
        } finally {
            snapshot?.delete()
        }
    }

    private fun safeSnapshotForCleanup(relativePath: String): File? {
        if (!SNAPSHOT_PATH.matches(relativePath)) return null
        val root = filesRoot.canonicalFile
        val resolved = File(root, relativePath).canonicalFile
        return resolved.takeIf { it.path.startsWith(root.path + File.separator) }
    }

    private fun failure(code: String) = BackupArchiveResult.Failure(code)

    private companion object {
        const val FORMAT_VERSION = 1
        const val BACKUPS_DIRECTORY = "backups"
        val OPERATION_ID = Regex("[A-Za-z0-9_-]{1,128}")
        val SNAPSHOT_PATH = Regex("backup_staging/[A-Za-z0-9_-]{1,128}\\.sqlite")
    }
}
