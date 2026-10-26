package com.loquiris.transcription

import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.nio.channels.FileLock
import java.nio.channels.OverlappingFileLockException
import java.nio.file.Files
import java.nio.file.LinkOption.NOFOLLOW_LINKS
import java.util.concurrent.atomic.AtomicBoolean

/** OS ownership survives Activity replacement and is released automatically on process death. */
internal class RefinementSnapshotLease private constructor(
    private val root: File,
    private val handle: RandomAccessFile,
    private val lock: FileLock,
    private val rootKey: String,
) : AutoCloseable {
    private val closed = AtomicBoolean()

    fun cleanAbandoned(shouldStop: () -> Boolean) {
        for (directory in root.listFiles() ?: throw IOException("snapshot unavailable")) {
            if (shouldStop()) throw RefinementSnapshotCancelled()
            if (!directory.name.startsWith("refinement-") || !Files.isDirectory(directory.toPath(), NOFOLLOW_LINKS)) continue
            val marker = File(directory, markerName)
            if (!Files.isRegularFile(marker.toPath(), NOFOLLOW_LINKS) || marker.length() != markerBytes.size.toLong() ||
                !marker.readBytes().contentEquals(markerBytes)
            ) continue
            val entries = directory.listFiles() ?: throw IOException("snapshot unavailable")
            // Unknown or linked entries are not ours to remove, even beside an ownership marker.
            if (entries.any { entry ->
                !Files.isRegularFile(entry.toPath(), NOFOLLOW_LINKS) ||
                    (entry.name != markerName && !entry.name.matches(segmentName))
            }) continue
            val files = entries.filter { it.name != markerName }
            for (file in files) {
                if (shouldStop()) throw RefinementSnapshotCancelled()
                Files.deleteIfExists(file.toPath())
            }
            Files.deleteIfExists(marker.toPath())
            Files.deleteIfExists(directory.toPath())
        }
    }

    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        try {
            try { lock.release() } finally { handle.close() }
        } finally {
            synchronized(activeRoots) { activeRoots.remove(rootKey) }
        }
    }

    companion object {
        const val markerName = ".owner-v1"
        val markerBytes = "loquiris-refinement-snapshot-v1".toByteArray(Charsets.US_ASCII)
        private val segmentName = Regex("segment-[0-9]+\\.adts")
        private val activeRoots = HashSet<String>()

        fun acquire(root: File): RefinementSnapshotLease {
            if (Files.isSymbolicLink(root.toPath()) || (!root.isDirectory && !root.mkdirs())) {
                throw IOException("snapshot unavailable")
            }
            val file = File(root, ".snapshot-owner.lock")
            if (Files.isSymbolicLink(file.toPath())) throw IOException("snapshot unavailable")
            val rootKey = root.canonicalPath
            // POSIX closing any descriptor for this inode can release all of the
            // process's fcntl locks. Reject local contention BEFORE opening it.
            synchronized(activeRoots) {
                if (!activeRoots.add(rootKey)) throw RefinementSnapshotBusy()
            }
            var handle: RandomAccessFile? = null
            try {
                val ownedHandle = RandomAccessFile(file, "rw")
                handle = ownedHandle
                val lock = try { ownedHandle.channel.tryLock() } catch (_: OverlappingFileLockException) { null }
                if (lock == null) throw RefinementSnapshotBusy()
                return RefinementSnapshotLease(root, ownedHandle, lock, rootKey)
            } catch (error: Throwable) {
                try { handle?.close() } finally {
                    synchronized(activeRoots) { activeRoots.remove(rootKey) }
                }
                throw error
            }
        }
    }
}

internal class RefinementSnapshotBusy : IOException()
