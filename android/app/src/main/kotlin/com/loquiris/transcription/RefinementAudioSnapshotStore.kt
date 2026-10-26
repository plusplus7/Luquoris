package com.loquiris.transcription

import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.file.Files
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicBoolean

/** A disposable private copy of exactly the journal-authorized compressed input. */
class RefinementAudioSnapshotStore(private val root: File) {
    fun create(audio: AuthoritativeAudioResolution.Ready, shouldStop: () -> Boolean): OwnedRefinementAudio {
        if (shouldStop()) throw RefinementSnapshotCancelled()
        val lease = RefinementSnapshotLease.acquire(root)
        var directory: File? = null
        val files = mutableListOf<File>()
        try {
            lease.cleanAbandoned(shouldStop)
            val ownedDirectory = Files.createTempDirectory(root.toPath(), "refinement-").toFile()
            directory = ownedDirectory
            File(ownedDirectory, RefinementSnapshotLease.markerName).writeBytes(RefinementSnapshotLease.markerBytes)
            val buffer = ByteArray(64 * 1024)
            val segments = audio.segments.map { segment ->
                if (shouldStop()) throw RefinementSnapshotCancelled()
                val expected = segment.verifiedSha256 ?: throw RefinementSnapshotInputChanged()
                val target = File(ownedDirectory, "segment-${segment.index}.adts")
                files += target
                val digest = MessageDigest.getInstance("SHA-256")
                var bytes = 0L
                segment.file.inputStream().use { input ->
                    FileOutputStream(target).use { output ->
                        while (true) {
                            if (shouldStop()) throw RefinementSnapshotCancelled()
                            val length = input.read(buffer)
                            if (length < 0) break
                            bytes = Math.addExact(bytes, length.toLong())
                            if (bytes > segment.committedBytes) throw RefinementSnapshotInputChanged()
                            digest.update(buffer, 0, length)
                            output.write(buffer, 0, length)
                        }
                    }
                }
                val actual = digest.digest().joinToString("") { "%02x".format(it) }
                if (bytes != segment.committedBytes || actual != expected) throw RefinementSnapshotInputChanged()
                if (!target.setReadOnly()) throw IOException("snapshot unavailable")
                segment.copy(file = target)
            }
            if (shouldStop()) throw RefinementSnapshotCancelled()
            return OwnedRefinementAudio(audio.copy(segments = segments), files.toList(), ownedDirectory, lease)
        } catch (error: Throwable) {
            // Only entries created in this unique private directory belong to this operation.
            try {
                if (directory != null) removeSnapshot(directory, files)
            } finally { lease.close() }
            throw error
        }
    }
}

/** Its owner closes after native decoding has released all file descriptors. */
class OwnedRefinementAudio internal constructor(
    val audio: AuthoritativeAudioResolution.Ready,
    private val files: List<File>,
    private val directory: File,
    private val lease: RefinementSnapshotLease,
) : AutoCloseable {
    private val closed = AtomicBoolean()
    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        try { removeSnapshot(directory, files) } finally { lease.close() }
    }
}

private fun removeSnapshot(directory: File, files: List<File>) {
    if (Files.isSymbolicLink(directory.toPath())) throw IOException("snapshot cleanup failed")
    var failed = false
    files.forEach { file ->
        try { Files.deleteIfExists(file.toPath()) } catch (_: IOException) { failed = true }
    }
    // Keep the marker if a file could not be removed, so a later owner can retry.
    if (failed) throw IOException("snapshot cleanup failed")
    Files.deleteIfExists(File(directory, RefinementSnapshotLease.markerName).toPath())
    Files.deleteIfExists(directory.toPath())
}

internal class RefinementSnapshotInputChanged : IOException()
internal class RefinementSnapshotCancelled : RuntimeException()
