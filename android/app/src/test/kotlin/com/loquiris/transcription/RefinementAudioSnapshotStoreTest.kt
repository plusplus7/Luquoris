package com.loquiris.transcription

import java.security.MessageDigest
import java.io.File
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class RefinementAudioSnapshotStoreTest {
    @get:Rule val temporary = TemporaryFolder()

    @Test fun `cancellation during copy removes its partial files and preserves originals`() {
        val source = temporary.newFile("original.adts").apply { writeBytes(ByteArray(70000) { 1 }) }
        val root = temporary.newFolder("snapshots")
        val hash = MessageDigest.getInstance("SHA-256").digest(source.readBytes()).joinToString("") { "%02x".format(it) }
        val audio = AuthoritativeAudioResolution.Ready(
            listOf(AuthoritativeAudioSegment(0, source, 70000, 0, 1024, hash)), 1024, 16000, listOf(byteArrayOf(1)),
        )
        var observations = 0
        assertThrows(RefinementSnapshotCancelled::class.java) {
            RefinementAudioSnapshotStore(root).create(audio) { ++observations == 4 }
        }
        assertTrue(root.listFiles()!!.none { it.isDirectory })
        assertTrue(root.listFiles()!!.all { it.length() == 0L })
        assertEquals(70000L, source.length())
        assertTrue(source.readBytes().all { it == 1.toByte() })
    }

    @Test fun `snapshot closure is idempotent and never deletes its original input`() {
        val source = temporary.newFile("original.adts").apply { writeBytes(byteArrayOf(1)) }
        val root = temporary.newFolder("snapshots")
        val audio = AuthoritativeAudioResolution.Ready(
            listOf(AuthoritativeAudioSegment(0, source, 1, 0, 1024, "4bf5122f344554c53bde2ebb8cd2b7e3d1600ad631c385a5d7cce23c7785459a")),
            1024, 16000, listOf(byteArrayOf(1)),
        )
        val owned = RefinementAudioSnapshotStore(root).create(audio) { false }
        assertNotEquals(source, owned.audio.segments.single().file)
        assertArrayEquals(byteArrayOf(1), owned.audio.segments.single().file.readBytes())
        owned.close()
        owned.close()
        assertTrue(root.listFiles()!!.none { it.isDirectory })
        assertTrue(root.listFiles()!!.all { it.length() == 0L })
        assertArrayEquals(byteArrayOf(1), source.readBytes())
    }

    @Test fun `a killed owner releases its lease and next work removes only abandoned copies`() {
        val source = temporary.newFile("crash-original.adts").apply { writeBytes(byteArrayOf(1)) }
        val root = temporary.newFolder("crash-snapshots")
        val unrelated = File(root, "foreign-data").apply { mkdir(); File(this, "keep.txt").writeText("keep") }
        val classpath = listOf(SnapshotCrashFixture::class.java, RefinementAudioSnapshotStore::class.java, Unit::class.java)
            .map { File(it.protectionDomain.codeSource.location.toURI()).absolutePath }.distinct().joinToString(File.pathSeparator)
        val process = ProcessBuilder(File(System.getProperty("java.home"), "bin/java").absolutePath,
            "-cp", classpath, SnapshotCrashFixture::class.java.name, root.absolutePath, source.absolutePath)
            .redirectErrorStream(true).start()
        try {
            val line = CompletableFuture.supplyAsync { process.inputStream.bufferedReader().readLine() }.get(10, TimeUnit.SECONDS)
            assertTrue(line, line.startsWith("READY:"))
            val abandoned = File(line.removePrefix("READY:"))
            assertTrue(abandoned.isFile)
            process.destroyForcibly()
            assertTrue(process.waitFor(10, TimeUnit.SECONDS))
            val replacement = RefinementAudioSnapshotStore(root).create(snapshotTestAudio(source)) { false }
            try {
                assertFalse(abandoned.exists())
                assertArrayEquals(byteArrayOf(1), replacement.audio.segments.single().file.readBytes())
                assertEquals("keep", File(unrelated, "keep.txt").readText())
                assertArrayEquals(byteArrayOf(1), source.readBytes())
            } finally { replacement.close() }
        } finally {
            process.destroyForcibly()
            process.waitFor(10, TimeUnit.SECONDS)
        }
    }

    @Test fun `a second store cannot reclaim files still owned by an active worker`() {
        val source = temporary.newFile("busy-original.adts").apply { writeBytes(byteArrayOf(1)) }
        val root = temporary.newFolder("busy-snapshots")
        val first = RefinementAudioSnapshotStore(root).create(snapshotTestAudio(source)) { false }
        try {
            assertThrows(java.io.IOException::class.java) {
                RefinementAudioSnapshotStore(root).create(snapshotTestAudio(source)) { false }
            }
            assertArrayEquals(byteArrayOf(1), first.audio.segments.single().file.readBytes())
        } finally { first.close() }
        RefinementAudioSnapshotStore(root).create(snapshotTestAudio(source)) { false }.close()
    }

    @Test fun `rejected same process acquisition cannot release the existing cross process lock`() {
        val source = temporary.newFile("cross-process-original.adts").apply { writeBytes(byteArrayOf(1)) }
        val root = temporary.newFolder("cross-process-snapshots")
        val first = RefinementAudioSnapshotStore(root).create(snapshotTestAudio(source)) { false }
        var process: Process? = null
        try {
            assertThrows(RefinementSnapshotBusy::class.java) {
                RefinementAudioSnapshotStore(root).create(snapshotTestAudio(source)) { false }
            }
            val classpath = listOf(SnapshotCrashFixture::class.java, RefinementAudioSnapshotStore::class.java, Unit::class.java)
                .map { File(it.protectionDomain.codeSource.location.toURI()).absolutePath }.distinct().joinToString(File.pathSeparator)
            val child = ProcessBuilder(File(System.getProperty("java.home"), "bin/java").absolutePath,
                "-cp", classpath, SnapshotCrashFixture::class.java.name, root.absolutePath, source.absolutePath)
                .redirectErrorStream(true).start()
            process = child
            val line = CompletableFuture.supplyAsync { child.inputStream.bufferedReader().readLine() }.get(10, TimeUnit.SECONDS)
            assertEquals("BUSY", line)
            assertArrayEquals(byteArrayOf(1), first.audio.segments.single().file.readBytes())
        } finally {
            process?.destroyForcibly()
            process?.waitFor(10, TimeUnit.SECONDS)
            first.close()
        }
    }

    @Test fun `an ownership marker never authorizes deletion of unknown entries`() {
        val source = temporary.newFile("foreign-original.adts").apply { writeBytes(byteArrayOf(1)) }
        val root = temporary.newFolder("foreign-snapshots")
        val foreign = File(root, "refinement-foreign").apply { mkdir() }
        File(foreign, ".owner-v1").writeText("loquiris-refinement-snapshot-v1")
        val retained = File(foreign, "segment-0.adts").apply { writeBytes(byteArrayOf(7)) }
        val unknown = File(foreign, "unknown.txt").apply { writeText("keep") }
        RefinementAudioSnapshotStore(root).create(snapshotTestAudio(source)) { false }.close()
        assertArrayEquals(byteArrayOf(7), retained.readBytes())
        assertEquals("keep", unknown.readText())
        assertTrue(File(foreign, ".owner-v1").exists())
    }

    @Test fun `cleanup never follows directory or segment links outside its private root`() {
        val source = temporary.newFile("linked-original.adts").apply { writeBytes(byteArrayOf(1)) }
        val root = temporary.newFolder("linked-snapshots")
        val outside = temporary.newFolder("outside")
        File(outside, ".owner-v1").writeText("loquiris-refinement-snapshot-v1")
        val original = File(outside, "segment-0.adts").apply { writeBytes(byteArrayOf(9)) }
        val directoryLink = File(root, "refinement-linked-directory")
        java.nio.file.Files.createSymbolicLink(directoryLink.toPath(), outside.toPath())
        val leaf = File(root, "refinement-linked-file").apply { mkdir() }
        File(leaf, ".owner-v1").writeText("loquiris-refinement-snapshot-v1")
        val fileLink = File(leaf, "segment-0.adts")
        java.nio.file.Files.createSymbolicLink(fileLink.toPath(), original.toPath())
        RefinementAudioSnapshotStore(root).create(snapshotTestAudio(source)) { false }.close()
        assertArrayEquals(byteArrayOf(9), original.readBytes())
        assertTrue(java.nio.file.Files.isSymbolicLink(directoryLink.toPath()))
        assertTrue(java.nio.file.Files.isSymbolicLink(fileLink.toPath()))
    }
}

private fun snapshotTestAudio(source: File) = AuthoritativeAudioResolution.Ready(
    listOf(AuthoritativeAudioSegment(0, source, 1, 0, 1024, "4bf5122f344554c53bde2ebb8cd2b7e3d1600ad631c385a5d7cce23c7785459a")),
    1024, 16000, listOf(byteArrayOf(1)),
)

/** Separate JVM deliberately dies without invoking snapshot cleanup. */
object SnapshotCrashFixture {
    @JvmStatic fun main(arguments: Array<String>) {
        val owned = try {
            RefinementAudioSnapshotStore(File(arguments[0])).create(snapshotTestAudio(File(arguments[1]))) { false }
        } catch (_: RefinementSnapshotBusy) {
            println("BUSY")
            return
        }
        println("READY:" + owned.audio.segments.single().file.absolutePath)
        System.out.flush()
        java.util.concurrent.CountDownLatch(1).await()
    }
}
