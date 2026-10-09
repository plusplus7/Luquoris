package com.loquiris.transcription

import android.content.Context
import android.system.Os
import android.system.OsConstants
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest

class WhisperModelStore(
    private val modelRoot: File,
    private val spec: ModelArtifactSpec = REVIEWED_BASE_Q5_MODEL,
    private val openAsset: () -> InputStream,
    private val directorySync: (File) -> Boolean = { true },
) : WhisperModelProvider {
    constructor(context: Context) : this(
        modelRoot = File(context.applicationContext.filesDir, "models"),
        openAsset = {
            context.applicationContext.assets.open(
                "flutter_assets/build/generated/model_assets/${REVIEWED_BASE_Q5_MODEL.assetPath}",
            )
        },
        directorySync = ::syncDirectory,
    )

    @Synchronized
    override fun materialize(): ModelMaterializationResult {
        if (!validSpec()) return failure("transcription_model_manifest_invalid")
        val directory = File(modelRoot, spec.id)
        val target = File(directory, File(spec.assetPath).name)
        if (target.isFile && verify(target)) return ModelMaterializationResult.Ready(target)
        if (!directory.isDirectory && !directory.mkdirs()) return failure("transcription_model_directory_failed")
        val temporary = File(directory, "${target.name}.tmp")
        temporary.delete()
        return try {
            val digest = MessageDigest.getInstance("SHA-256")
            var bytes = 0L
            openAsset().use { input ->
                FileOutputStream(temporary, false).use { output ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        output.write(buffer, 0, read)
                        digest.update(buffer, 0, read)
                        bytes = Math.addExact(bytes, read.toLong())
                    }
                    output.fd.sync()
                }
            }
            if (bytes != spec.bytes || digest.digest().toHex() != spec.sha256) {
                temporary.delete()
                return failure("transcription_model_hash_mismatch")
            }
            Files.move(
                temporary.toPath(),
                target.toPath(),
                StandardCopyOption.ATOMIC_MOVE,
                StandardCopyOption.REPLACE_EXISTING,
            )
            if (!directorySync(directory)) return failure("transcription_model_publish_failed")
            if (!verify(target)) return failure("transcription_model_hash_mismatch")
            ModelMaterializationResult.Ready(target)
        } catch (_: Exception) {
            temporary.delete()
            failure("transcription_model_materialization_failed")
        }
    }

    private fun validSpec(): Boolean =
        spec.id.matches(Regex("[a-z0-9][a-z0-9._-]{0,127}")) &&
            spec.assetPath.startsWith("models/") &&
            !spec.assetPath.contains("..") &&
            spec.bytes > 0 &&
            spec.sha256.matches(Regex("[0-9a-f]{64}"))

    private fun verify(file: File): Boolean {
        if (!file.isFile || file.length() != spec.bytes) return false
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().toHex() == spec.sha256
    }

    private fun failure(code: String) = ModelMaterializationResult.Failure(code)

    companion object {
        val REVIEWED_BASE_Q5_MODEL =
            ModelArtifactSpec(
                id = "whisper-base-q5_1",
                assetPath = "models/whisper-base-q5_1/ggml-base-q5_1.bin",
                bytes = 59_707_625L,
                sha256 = "422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898",
            )

        private fun syncDirectory(directory: File): Boolean =
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
}

private fun ByteArray.toHex(): String = joinToString("") { byte -> "%02x".format(byte) }
