package com.loquiris.recording

import android.content.Context
import android.os.StatFs
import android.system.Os
import android.system.OsConstants
import java.io.File
import java.io.FileOutputStream
import java.nio.file.Files
import java.nio.file.StandardCopyOption

object AndroidRecordingStorageSpace {
    fun availableBytes(context: Context): Long? =
        try {
            StatFs(context.applicationContext.filesDir.absolutePath).availableBytes
        } catch (_: RuntimeException) {
            null
        }
}

class AppPrivateRecordingStorageFailureSink(
    context: Context,
    sessionId: String,
) : RecordingStorageFailureSink {
    private val delegate =
        AtomicRecordingStorageFailureFileSink(
            target =
                File(
                    File(context.applicationContext.filesDir, "recording-events"),
                    "${sessionId.sha256Hex()}.storage-failure",
                ),
            directorySync = ::syncDirectory,
        )

    override fun writeAndSync(frame: String): Boolean = delegate.writeAndSync(frame)

    private fun syncDirectory(directory: File): Boolean =
        try {
            val descriptor = Os.open(directory.absolutePath, OsConstants.O_RDONLY, 0)
            try {
                Os.fsync(descriptor)
            } finally {
                Os.close(descriptor)
            }
            true
        } catch (_: RuntimeException) {
            false
        }
}

class AtomicRecordingStorageFailureFileSink(
    private val target: File,
    private val directorySync: (File) -> Boolean,
) : RecordingStorageFailureSink {
    override fun writeAndSync(frame: String): Boolean {
        if (RecordingStorageFailureFrame.decode(frame) == null) return false
        val directory = target.parentFile ?: return false
        val parent = directory.parentFile ?: return false
        val temporary = File(directory, "${target.name}.tmp")
        return try {
            val created = !directory.exists()
            if (created && !directory.mkdirs()) return false
            if (!directory.isDirectory) return false
            if (created && !directorySync(parent)) return false
            FileOutputStream(temporary, false).use {
                it.write(frame.toByteArray(Charsets.UTF_8))
                it.write('\n'.code)
                it.fd.sync()
            }
            Files.move(
                temporary.toPath(),
                target.toPath(),
                StandardCopyOption.ATOMIC_MOVE,
                StandardCopyOption.REPLACE_EXISTING,
            )
            directorySync(directory)
        } catch (_: Exception) {
            false
        } finally {
            if (temporary.exists()) temporary.delete()
        }
    }
}
