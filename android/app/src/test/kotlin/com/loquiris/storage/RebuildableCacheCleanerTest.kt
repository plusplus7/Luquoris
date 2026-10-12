package com.loquiris.storage

import java.nio.file.Files
import java.nio.file.Path
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RebuildableCacheCleanerTest {
    @Test
    fun `deletes only allowlisted rebuildable cache directories`() {
        val root = Files.createTempDirectory("loquiris-cache-test")
        try {
            write(root, "pcm/chunk.pcm", byteArrayOf(1, 2, 3))
            write(root, "waveforms/meeting.bin", byteArrayOf(4, 5, 6, 7))
            write(root, "unknown/keep.bin", byteArrayOf(8, 9))
            val result = RebuildableCacheCleaner(root.toFile()).clear()

            val receipt = (result as RebuildableCacheCleanupResult.Success).receipt
            assertEquals(2, receipt.filesDeleted)
            assertEquals(7L, receipt.bytesDeleted)
            assertFalse(Files.exists(root.resolve("pcm")))
            assertFalse(Files.exists(root.resolve("waveforms")))
            assertTrue(Files.exists(root.resolve("unknown/keep.bin")))
        } finally {
            root.toFile().deleteRecursively()
        }
    }

    @Test
    fun `clears every approved category and treats absent roots as success`() {
        val root = Files.createTempDirectory("loquiris-cache-test")
        try {
            for (directory in listOf("pcm", "waveforms", "search_indexes", "failed_jobs")) {
                write(root, "$directory/artifact.tmp", byteArrayOf(1))
            }

            val first = RebuildableCacheCleaner(root.toFile()).clear()
            val second = RebuildableCacheCleaner(root.toFile()).clear()

            assertEquals(4, (first as RebuildableCacheCleanupResult.Success).receipt.filesDeleted)
            assertEquals(0, (second as RebuildableCacheCleanupResult.Success).receipt.filesDeleted)
        } finally {
            root.toFile().deleteRecursively()
        }
    }

    @Test
    fun `deletes a cache symlink without following it outside the root`() {
        val root = Files.createTempDirectory("loquiris-cache-test")
        val outside = Files.createTempDirectory("loquiris-authoritative-test")
        try {
            write(outside, "authoritative.aac", byteArrayOf(1, 2, 3, 4))
            Files.createDirectories(root.resolve("pcm"))
            Files.createSymbolicLink(root.resolve("pcm/escape"), outside)

            val result = RebuildableCacheCleaner(root.toFile()).clear()

            assertTrue(result is RebuildableCacheCleanupResult.Success)
            assertTrue(Files.exists(outside.resolve("authoritative.aac")))
            assertFalse(Files.exists(root.resolve("pcm")))
        } finally {
            root.toFile().deleteRecursively()
            outside.toFile().deleteRecursively()
        }
    }
}

private fun write(
    root: Path,
    relativePath: String,
    bytes: ByteArray,
) {
    val target = root.resolve(relativePath)
    Files.createDirectories(target.parent)
    Files.write(target, bytes)
}
