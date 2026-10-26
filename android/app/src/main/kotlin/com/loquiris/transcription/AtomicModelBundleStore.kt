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
import java.util.Collections

/** Individually verified file; paths and roles match the manifest-v2 inventory. */
data class BundleArtifactSpec(val path: String, val role: String, val bytes: Long, val sha256: String)

/** Content-addressed bundle identity, independent of any recognizer allocation. */
data class ModelBundleSpec(val id: String, val sha256: String, val artifacts: List<BundleArtifactSpec>)

sealed interface BundleMaterializationResult {
    data class Ready(val files: Map<String, File>) : BundleMaterializationResult
    data class Failure(val code: String) : BundleMaterializationResult
}

/** Publishes one verified directory, never a partial encoder/tokenizer set. */
class AtomicModelBundleStore(
    private val modelRoot: File,
    spec: ModelBundleSpec,
    private val openAsset: (String) -> InputStream,
    private val directorySync: (File) -> Boolean = ::syncDirectory,
    private val publish: (File, File) -> Unit = { from, to ->
        Files.move(from.toPath(), to.toPath(), StandardCopyOption.ATOMIC_MOVE)
    },
) {
    constructor(context: Context, spec: ModelBundleSpec) : this(
        File(context.applicationContext.filesDir, "model_bundles"), spec,
        openAsset = { path -> context.applicationContext.assets.open("flutter_assets/build/generated/model_assets/$path") },
    )
    private val spec = spec.copy(artifacts = spec.artifacts.toList().sortedBy { it.path })

    @Synchronized
    fun materialize(): BundleMaterializationResult {
        if (!validSpec()) return failure("model_bundle_manifest_invalid")
        var staging: File? = null
        var published = false
        val target = File(modelRoot, "${spec.id}-${spec.sha256}")
        return try {
            if (Files.isSymbolicLink(modelRoot.toPath())) return failure("model_bundle_directory_invalid")
            if (!modelRoot.isDirectory && !modelRoot.mkdirs()) return failure("model_bundle_directory_failed")
            if (target.exists()) {
                return if (verifyDirectory(target)) ready(target) else failure("model_bundle_hash_mismatch")
            }
            val stageDirectory = Files.createTempDirectory(modelRoot.toPath(), ".staging-").toFile()
            staging = stageDirectory
            for (artifact in spec.artifacts) {
                val file = fileIn(stageDirectory, artifact)
                val parent = requireNotNull(file.parentFile)
                if (!parent.isDirectory && !parent.mkdirs()) throw IllegalStateException()
                openAsset(artifact.path).use { input ->
                    FileOutputStream(file).use { output ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        var bytes = 0L
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            bytes = Math.addExact(bytes, count.toLong())
                            if (bytes > artifact.bytes) throw IllegalStateException()
                            output.write(buffer, 0, count)
                        }
                        output.fd.sync()
                    }
                }
                if (!verifyFile(file, artifact)) return failure("model_bundle_hash_mismatch")
            }
            // Flush nested directory entries before the same-filesystem atomic rename.
            if (stageDirectory.walkBottomUp().filter { it.isDirectory }.any { !directorySync(it) }) {
                return failure("model_bundle_publish_failed")
            }
            publish(stageDirectory, target)
            published = true
            if (!directorySync(modelRoot) || !verifyDirectory(target)) {
                throw IllegalStateException()
            }
            ready(target)
        } catch (_: Exception) {
            if (published) {
                target.deleteRecursively()
                directorySync(modelRoot)
            }
            failure("model_bundle_materialization_failed")
        } finally {
            staging?.takeIf { it.exists() }?.deleteRecursively()
        }
    }

    private fun validSpec(): Boolean {
        if (!spec.id.matches(Regex("[a-z0-9][a-z0-9._-]{0,127}")) ||
            !spec.sha256.matches(Regex("[0-9a-f]{64}")) || spec.artifacts.isEmpty() || spec.artifacts.size > 6) return false
        if (spec.artifacts.map { it.path }.toSet().size != spec.artifacts.size ||
            spec.artifacts.map { it.role }.toSet().size != spec.artifacts.size) return false
        var bytes = 0L
        for (artifact in spec.artifacts) {
            if (!safePath(artifact.path) || !artifact.path.startsWith("models/${spec.id}/") ||
                artifact.role !in setOf("model", "encoder", "decoder", "joiner", "tokenizer", "configuration") ||
                artifact.bytes <= 0 || artifact.bytes > MAX_BYTES ||
                !artifact.sha256.matches(Regex("[0-9a-f]{64}")) || bytes > MAX_BYTES - artifact.bytes) return false
            bytes += artifact.bytes
        }
        val inventory = spec.artifacts.joinToString(",", "[", "]") {
            "{\"path\":${quote(it.path)},\"role\":${quote(it.role)},\"bytes\":${it.bytes},\"sha256\":${quote(it.sha256)}}"
        }
        return hash(inventory.toByteArray(Charsets.UTF_8)) == spec.sha256
    }

    private fun safePath(path: String): Boolean =
        !path.contains('\\') && !path.contains('\u0000') &&
            path.split('/').all { it.isNotEmpty() && it != "." && it != ".." }

    private fun fileIn(directory: File, artifact: BundleArtifactSpec): File =
        File(directory, artifact.path.removePrefix("models/${spec.id}/"))

    private fun verifyDirectory(directory: File): Boolean {
        if (!directory.isDirectory || Files.isSymbolicLink(directory.toPath())) return false
        return spec.artifacts.all { artifact ->
            val file = fileIn(directory, artifact)
            var parent = requireNotNull(file.parentFile)
            while (parent != directory) {
                if (Files.isSymbolicLink(parent.toPath())) return false
                parent = requireNotNull(parent.parentFile)
            }
            verifyFile(file, artifact)
        }
    }

    private fun verifyFile(file: File, artifact: BundleArtifactSpec): Boolean {
        if (!file.isFile || Files.isSymbolicLink(file.toPath()) || file.length() != artifact.bytes) return false
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        return digest.digest().hex() == artifact.sha256
    }

    private fun ready(directory: File) = BundleMaterializationResult.Ready(
        Collections.unmodifiableMap(spec.artifacts.associate { it.path to fileIn(directory, it) }),
    )

    private fun failure(code: String) = BundleMaterializationResult.Failure(code)

    companion object {
        private const val MAX_BYTES = 9_007_199_254_740_991L

        private fun syncDirectory(directory: File): Boolean = try {
            val descriptor = Os.open(directory.absolutePath, OsConstants.O_RDONLY, 0)
            try { Os.fsync(descriptor) } finally { Os.close(descriptor) }
            true
        } catch (_: Exception) { false }

        private fun hash(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256").digest(bytes).hex()

        private fun quote(value: String): String = buildString {
            append('"')
            for (char in value) {
                when (char) {
                    '"' -> append("\\\"")
                    '\\' -> append("\\\\")
                    '\b' -> append("\\b")
                    '\u000C' -> append("\\f")
                    '\n' -> append("\\n")
                    '\r' -> append("\\r")
                    '\t' -> append("\\t")
                    else -> if (char.code < 32) append("\\u%04x".format(char.code)) else append(char)
                }
            }
            append('"')
        }
    }
}

private fun ByteArray.hex(): String = joinToString("") { "%02x".format(it) }
