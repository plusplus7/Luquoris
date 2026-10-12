package com.loquiris.recording

import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class RecordingM4aRebuilderTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `rebuild muxes journal-authorized frames on one continuous media timeline`() {
        val directory = recordedDirectory("continuous")
        val authoritativeBefore = authoritativeBytes(directory)
        val muxer = FakeRecordingM4aMuxer(File(directory, "playback.m4a.tmp"))

        val result =
            RecordingM4aRebuilder(
                muxerFactory = RecordingM4aMuxerFactory { muxer },
                fileOperations = RebuildJvmFileOperations,
            ).rebuild(directory)

        assertTrue("rebuild result was $result", result is RecordingM4aRebuildResult.Success)
        result as RecordingM4aRebuildResult.Success
        assertEquals(5, result.accessUnitCount)
        assertEquals(5_120L, result.mediaSamples)
        assertEquals(listOf(0L, 64_000L, 128_000L, 192_000L, 256_000L), muxer.timestamps)
        assertEquals(listOf(12, 12, 12, 12, 12), muxer.payloads.map(ByteArray::size))
        assertTrue(File(directory, "playback.m4a").isFile)
        assertFalse(File(directory, "playback.m4a.tmp").exists())
        assertTrue(
            RecordingM4aArtifactResolver(RebuildJvmFileOperations).resolve(directory) is
                RecordingM4aArtifactResolveResult.Ready,
        )
        assertEquals(authoritativeBefore, authoritativeBytes(directory))
    }

    @Test
    fun `failed rebuild removes temporary output and preserves authoritative files`() {
        val directory = recordedDirectory("failure")
        val authoritativeBefore = authoritativeBytes(directory)

        val result =
            RecordingM4aRebuilder(
                muxerFactory = RecordingM4aMuxerFactory { output ->
                    FakeRecordingM4aMuxer(output, failAtSample = 2)
                },
                fileOperations = RebuildJvmFileOperations,
            ).rebuild(directory)

        assertEquals(
            RecordingM4aRebuildResult.Failure("recording_m4a_mux_failed"),
            result,
        )
        assertFalse(File(directory, "playback.m4a.tmp").exists())
        assertFalse(File(directory, "playback.m4a").exists())
        val status =
            (RecordingM4aArtifactStatusStore(directory, RebuildJvmFileOperations).load() as
                RecordingM4aArtifactStatusLoadResult.Loaded).status
        assertEquals(RecordingM4aArtifactState.failed, status.state)
        assertEquals("recording_m4a_mux_failed", status.failureCode)
        assertEquals(authoritativeBefore, authoritativeBytes(directory))
    }

    @Test
    fun `rebuild ignores complete AAC frames beyond the journal-authorized prefix`() {
        val directory = recordedDirectory("uncommitted-tail")
        val manifest =
            (AtomicRecordingSegmentManifestStore(directory, RebuildJvmFileOperations).load() as
                RecordingSegmentManifestDecodeResult.Success).manifest
        val lastSegment = manifest.segments.last()
        File(directory, lastSegment.dataFileName).appendBytes(
            RecordingAdtsFrameCodec.wrap(ByteArray(12) { 9 }, manifest.sampleRateHz, manifest.channelCount),
        )
        val muxer = FakeRecordingM4aMuxer(File(directory, "playback.m4a.tmp"))

        val result =
            RecordingM4aRebuilder(
                muxerFactory = RecordingM4aMuxerFactory { muxer },
                fileOperations = RebuildJvmFileOperations,
            ).rebuild(directory)

        assertTrue(result is RecordingM4aRebuildResult.Success)
        assertEquals(5, (result as RecordingM4aRebuildResult.Success).accessUnitCount)
        assertEquals(5, muxer.payloads.size)
    }

    @Test
    fun `published playback becomes stale when authoritative continuation changes`() {
        val directory = recordedDirectory("stale-continuation")
        val rebuilt =
            RecordingM4aRebuilder(
                muxerFactory = RecordingM4aMuxerFactory { output -> FakeRecordingM4aMuxer(output) },
                fileOperations = RebuildJvmFileOperations,
            ).rebuild(directory)
        assertTrue(rebuilt is RecordingM4aRebuildResult.Success)
        val continued =
            RecordingSegmentCoordinator.continueFromManifest(
                directory = directory,
                sessionId = "meeting-stale-continuation",
                policy = RecordingSegmentationPolicy(commitFrames = 2, commitGroupsPerSegment = 2),
                fileOperations = RebuildJvmFileOperations,
            ) as RecordingSegmentOpenResult.Success
        continued.coordinator.appendAccessUnit(ByteArray(12) { 7 })
        continued.coordinator.finish()

        val resolved = RecordingM4aArtifactResolver(RebuildJvmFileOperations).resolve(directory)

        assertEquals(
            RecordingM4aArtifactResolveResult.Unavailable("recording_m4a_artifact_stale"),
            resolved,
        )
    }

    @Test
    fun `ready status remains unavailable when its directory sync fails`() {
        val directory = recordedDirectory("ready-sync-failure")
        val operations = FailReadyStatusDirectorySyncOperations(directory)

        val result =
            RecordingM4aRebuilder(
                muxerFactory = RecordingM4aMuxerFactory { output -> FakeRecordingM4aMuxer(output) },
                fileOperations = operations,
            ).rebuild(directory)

        assertEquals(
            RecordingM4aRebuildResult.Failure("recording_m4a_status_publish_failed"),
            result,
        )
        assertEquals(
            RecordingM4aArtifactResolveResult.Unavailable("recording_m4a_artifact_quarantined"),
            RecordingM4aArtifactResolver(operations).resolve(directory),
        )
    }

    private fun recordedDirectory(name: String): File {
        val directory = temporaryFolder.newFolder(name)
        val opened =
            RecordingSegmentCoordinator.open(
                directory = directory,
                sessionId = "meeting-$name",
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
                policy = RecordingSegmentationPolicy(commitFrames = 2, commitGroupsPerSegment = 2),
                fileOperations = RebuildJvmFileOperations,
            ) as RecordingSegmentOpenResult.Success
        repeat(5) { marker ->
            assertTrue(
                opened.coordinator.appendAccessUnit(ByteArray(12) { marker.toByte() }) is
                    RecordingSegmentCommandResult.Success,
            )
        }
        assertTrue(opened.coordinator.finish() is RecordingSegmentCommandResult.Success)
        return directory
    }

    private fun authoritativeBytes(directory: File): Map<String, List<Byte>> =
        directory
            .listFiles()
            .orEmpty()
            .filter {
                it.name !in
                    setOf(
                        "playback.m4a",
                        "playback.m4a.tmp",
                        "playback.status",
                        "playback.status.tmp",
                    )
            }
            .associate { it.name to it.readBytes().toList() }
}

private class FakeRecordingM4aMuxer(
    private val output: File,
    private val failAtSample: Int? = null,
) : RecordingM4aMuxer {
    val timestamps = mutableListOf<Long>()
    val payloads = mutableListOf<ByteArray>()

    override fun start(format: RecordingM4aFormat) = Unit

    override fun writeSample(
        accessUnit: ByteArray,
        presentationTimeMicroseconds: Long,
    ) {
        if (payloads.size == failAtSample) error("injected mux failure")
        payloads += accessUnit.copyOf()
        timestamps += presentationTimeMicroseconds
    }

    override fun finish() {
        output.writeBytes(byteArrayOf(1, 2, 3, 4))
    }

    override fun close() = Unit
}

private object RebuildJvmFileOperations : RecordingFileOperations {
    override fun writeAndSync(file: File, bytes: ByteArray): Boolean {
        file.writeBytes(bytes)
        return true
    }

    override fun atomicReplace(source: File, target: File): Boolean {
        Files.move(
            source.toPath(),
            target.toPath(),
            StandardCopyOption.REPLACE_EXISTING,
        )
        return true
    }

    override fun syncDirectory(directory: File): Boolean = directory.isDirectory
}

private class FailReadyStatusDirectorySyncOperations(
    private val sessionDirectory: File,
) : RecordingFileOperations {
    private var statusReplaceCount = 0
    private var readyDirectorySyncFailed = false

    override fun writeAndSync(file: File, bytes: ByteArray): Boolean =
        RebuildJvmFileOperations.writeAndSync(file, bytes)

    override fun atomicReplace(source: File, target: File): Boolean {
        if (
            target.name == RecordingM4aArtifactStatusStore.STATUS_FILE_NAME &&
            readyDirectorySyncFailed
        ) {
            return false
        }
        val replaced = RebuildJvmFileOperations.atomicReplace(source, target)
        if (target.name == RecordingM4aArtifactStatusStore.STATUS_FILE_NAME) statusReplaceCount += 1
        return replaced
    }

    override fun syncDirectory(directory: File): Boolean {
        if (directory == sessionDirectory && statusReplaceCount >= 2) {
            readyDirectorySyncFailed = true
            return false
        }
        return RebuildJvmFileOperations.syncDirectory(directory)
    }
}
