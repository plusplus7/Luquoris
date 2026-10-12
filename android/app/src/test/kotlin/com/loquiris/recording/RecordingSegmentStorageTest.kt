package com.loquiris.recording

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class RecordingSegmentStorageTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `manifest round trip preserves codec and contiguous segment identity`() {
        val manifest =
            RecordingSegmentManifest(
                sessionId = "meeting/one",
                sampleRateHz = 16_000,
                channelCount = 1,
                bitRateBitsPerSecond = 64_000,
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
                segments =
                    listOf(
                        RecordingSegmentEntry(0, 0, "segment-00000.adts", "segment-00000.commit"),
                        RecordingSegmentEntry(1, 4_761_600, "segment-00001.adts", "segment-00001.commit"),
                    ),
            )

        val encoded = RecordingSegmentManifestCodec.encode(manifest)
        val decoded = RecordingSegmentManifestCodec.decode(encoded)

        assertTrue(decoded is RecordingSegmentManifestDecodeResult.Success)
        val restored = (decoded as RecordingSegmentManifestDecodeResult.Success).manifest
        assertEquals(manifest.sessionId, restored.sessionId)
        assertEquals(manifest.sampleRateHz, restored.sampleRateHz)
        assertTrue(manifest.codecSpecificData.single().contentEquals(restored.codecSpecificData.single()))
        assertEquals(manifest.segments, restored.segments)
    }

    @Test
    fun `manifest rejects checksum corruption path traversal and noncontiguous indices`() {
        val valid = baseManifest()
        val corrupted = RecordingSegmentManifestCodec.encode(valid).copyOf().also { it[it.lastIndex / 2] = 0x7f }
        assertTrue(RecordingSegmentManifestCodec.decode(corrupted) is RecordingSegmentManifestDecodeResult.Corrupt)

        assertFalse(
            runCatching {
                RecordingSegmentEntry(0, 0, "../escape.adts", "segment-00000.commit")
            }.isSuccess,
        )
        assertFalse(
            runCatching {
                valid.copy(
                    segments =
                        listOf(
                            RecordingSegmentEntry(1, 0, "segment-00001.adts", "segment-00001.commit"),
                        ),
                )
            }.isSuccess,
        )
    }

    @Test
    fun `atomic manifest publication writes temp replaces target then syncs directory`() {
        val operations = RecordingFileOperationsProbe()
        val directory = temporaryFolder.newFolder("meeting")
        val store = AtomicRecordingSegmentManifestStore(directory, operations)

        assertEquals(RecordingManifestWriteResult.Success, store.publish(baseManifest()))
        assertEquals(
            listOf(
                "write-sync:segments.manifest.tmp",
                "replace:segments.manifest.tmp->segments.manifest",
                "sync-dir:meeting",
            ),
            operations.events,
        )
    }

    @Test
    fun `possible manifest publication retains segment files when final directory sync fails`() {
        val directory = temporaryFolder.newFolder("uncertain-publication")
        val operations = FinalDirectorySyncFailureOperations()

        val opened =
            RecordingSegmentCoordinator.open(
                directory = directory,
                sessionId = "uncertain-publication",
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
                fileOperations = operations,
            )

        assertTrue(opened is RecordingSegmentOpenResult.Failure)
        assertTrue(File(directory, "segment-00000.adts").isFile)
        assertTrue(File(directory, "segment-00000.commit").isFile)
        assertTrue(File(directory, AtomicRecordingSegmentManifestStore.MANIFEST_FILE_NAME).isFile)
    }

    @Test
    fun `manifest publication converts file operation exceptions to typed failure`() {
        val directory = temporaryFolder.newFolder("throwing-publication")
        val store = AtomicRecordingSegmentManifestStore(directory, ThrowingDirectorySyncOperations)

        val result = store.publish(baseManifest())

        assertEquals(
            RecordingManifestWriteResult.Failure("recording_manifest_directory_sync_failed"),
            result,
        )
        assertTrue(File(directory, AtomicRecordingSegmentManifestStore.MANIFEST_FILE_NAME).isFile)
    }

    @Test
    fun `new nested session directory syncs each newly created parent entry`() {
        val root = temporaryFolder.newFolder("durable-directory-root")
        val directory = File(File(root, "recordings"), "session")
        val operations = DurableDirectoryCreationOperations()

        val opened =
            RecordingSegmentCoordinator.open(
                directory = directory,
                sessionId = "durable-directory",
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
                fileOperations = operations,
            )

        assertTrue(opened is RecordingSegmentOpenResult.Success)
        assertTrue(operations.syncedDirectories.contains(root.canonicalPath))
        assertTrue(operations.syncedDirectories.contains(File(root, "recordings").canonicalPath))
        (opened as RecordingSegmentOpenResult.Success).coordinator.finish()
    }

    @Test
    fun `input health reports short zero error gap and timestamp regression`() {
        var now = 1_000_000_000L
        val tracker = AudioInputHealthTracker(elapsedRealtimeNanos = { now })

        tracker.recordRead(requestedBytes = 640, result = 640)
        now += 25_000_000L
        tracker.recordRead(requestedBytes = 640, result = 320)
        now += 40_000_000L
        tracker.recordRead(requestedBytes = 640, result = 0)
        tracker.recordRead(requestedBytes = 640, result = -3)
        tracker.recordTimestamp(framePosition = 10_000)
        tracker.recordTimestamp(framePosition = 9_000)

        val metrics = tracker.snapshot()
        assertEquals(4L, metrics.readCalls)
        assertEquals(960L, metrics.pcmBytes)
        assertEquals(1L, metrics.shortReads)
        assertEquals(1L, metrics.zeroReads)
        assertEquals(1L, metrics.errorReads)
        assertEquals(40_000_000L, metrics.maximumReadGapNanos)
        assertEquals(1L, metrics.timestampRegressions)
    }

    @Test
    fun `segment is published before audio and rollover preserves ordered committed prefixes`() {
        val directory = temporaryFolder.newFolder("rollover")
        val policy = RecordingSegmentationPolicy(commitFrames = 3, commitGroupsPerSegment = 2)
        val opened =
            RecordingSegmentCoordinator.open(
                directory = directory,
                sessionId = "rollover-meeting",
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
                policy = policy,
                fileOperations = JvmRecordingFileOperations,
            )
        assertTrue("open result was $opened", opened is RecordingSegmentOpenResult.Success)
        val coordinator = (opened as RecordingSegmentOpenResult.Success).coordinator

        val initialManifest =
            AtomicRecordingSegmentManifestStore(directory).load()
                as RecordingSegmentManifestDecodeResult.Success
        assertEquals(listOf(0), initialManifest.manifest.segments.map(RecordingSegmentEntry::index))
        assertEquals(0L, File(directory, "segment-00000.adts").length())

        repeat(7) { marker ->
            assertTrue(
                coordinator.appendAccessUnit(ByteArray(12) { marker.toByte() }) is
                    RecordingSegmentCommandResult.Success,
            )
        }
        assertTrue(coordinator.finish() is RecordingSegmentCommandResult.Success)

        val manifest =
            (AtomicRecordingSegmentManifestStore(directory).load() as RecordingSegmentManifestDecodeResult.Success)
                .manifest
        assertEquals(listOf(0, 1), manifest.segments.map(RecordingSegmentEntry::index))
        assertEquals(listOf(0L, 6L * 1_024L), manifest.segments.map(RecordingSegmentEntry::startSample))
        val recovered =
            manifest.segments.map { segment ->
                RecordingCommittedPrefixRecovery.recover(
                    File(directory, segment.dataFileName).readBytes(),
                    File(directory, segment.journalFileName).readBytes(),
                )
            }
        assertEquals(listOf(6, 1), recovered.map(RecordingCommittedPrefix::committedFrames))
        assertEquals(listOf(6_144L, 1_024L), recovered.map(RecordingCommittedPrefix::committedSamples))
        assertTrue(coordinator.snapshot().bytesWritten > 0L)
    }

    @Test
    fun `explicit continuation preserves published bytes and adds a new manifest segment`() {
        val directory = temporaryFolder.newFolder("continuation")
        val policy = RecordingSegmentationPolicy(commitFrames = 2, commitGroupsPerSegment = 2)
        val original =
            RecordingSegmentCoordinator.open(
                directory = directory,
                sessionId = "continued-meeting",
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
                policy = policy,
                fileOperations = JvmRecordingFileOperations,
            ) as RecordingSegmentOpenResult.Success
        repeat(3) { original.coordinator.appendAccessUnit(ByteArray(12) { it.toByte() }) }
        original.coordinator.finish()
        val originalData = File(directory, "segment-00000.adts").readBytes()
        val originalJournal = File(directory, "segment-00000.commit").readBytes()

        val continued =
            RecordingSegmentCoordinator.continueFromManifest(
                directory = directory,
                sessionId = "continued-meeting",
                policy = policy,
                fileOperations = JvmRecordingFileOperations,
            ) as RecordingSegmentOpenResult.Success

        assertTrue(originalData.contentEquals(File(directory, "segment-00000.adts").readBytes()))
        assertTrue(originalJournal.contentEquals(File(directory, "segment-00000.commit").readBytes()))
        val manifest =
            (AtomicRecordingSegmentManifestStore(directory).load() as RecordingSegmentManifestDecodeResult.Success)
                .manifest
        assertEquals(listOf(0, 1), manifest.segments.map(RecordingSegmentEntry::index))
        assertEquals(3_072L, manifest.segments.last().startSample)
        assertEquals(3_072L, continued.coordinator.snapshot().totalSamples)
        continued.coordinator.finish()
    }

    @Test
    fun `explicit continuation can retry an empty published continuation segment`() {
        val directory = temporaryFolder.newFolder("continuation-retry")
        val policy = RecordingSegmentationPolicy(commitFrames = 2, commitGroupsPerSegment = 2)
        val original =
            RecordingSegmentCoordinator.open(
                directory = directory,
                sessionId = "retried-meeting",
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
                policy = policy,
                fileOperations = JvmRecordingFileOperations,
            ) as RecordingSegmentOpenResult.Success
        repeat(3) { original.coordinator.appendAccessUnit(ByteArray(12) { it.toByte() }) }
        original.coordinator.finish()
        val originalData = File(directory, "segment-00000.adts").readBytes()
        val originalJournal = File(directory, "segment-00000.commit").readBytes()

        val firstContinuation =
            RecordingSegmentCoordinator.continueFromManifest(
                directory = directory,
                sessionId = "retried-meeting",
                policy = policy,
                fileOperations = JvmRecordingFileOperations,
            ) as RecordingSegmentOpenResult.Success
        firstContinuation.coordinator.finish()

        val retry =
            RecordingSegmentCoordinator.continueFromManifest(
                directory = directory,
                sessionId = "retried-meeting",
                policy = policy,
                fileOperations = JvmRecordingFileOperations,
            )

        assertTrue("retry result was $retry", retry is RecordingSegmentOpenResult.Success)
        assertTrue(originalData.contentEquals(File(directory, "segment-00000.adts").readBytes()))
        assertTrue(originalJournal.contentEquals(File(directory, "segment-00000.commit").readBytes()))
        val manifest =
            (AtomicRecordingSegmentManifestStore(directory).load() as RecordingSegmentManifestDecodeResult.Success)
                .manifest
        assertEquals(listOf(0, 1), manifest.segments.map(RecordingSegmentEntry::index))
        assertEquals(listOf(0L, 3_072L), manifest.segments.map(RecordingSegmentEntry::startSample))
        (retry as RecordingSegmentOpenResult.Success).coordinator.finish()
    }

    @Test
    fun `explicit continuation discards an uncommitted published tail before retry`() {
        val directory = temporaryFolder.newFolder("continuation-uncommitted-retry")
        val policy = RecordingSegmentationPolicy(commitFrames = 2, commitGroupsPerSegment = 2)
        val original =
            RecordingSegmentCoordinator.open(
                directory = directory,
                sessionId = "uncommitted-retry-meeting",
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
                policy = policy,
                fileOperations = JvmRecordingFileOperations,
            ) as RecordingSegmentOpenResult.Success
        repeat(3) { original.coordinator.appendAccessUnit(ByteArray(12) { it.toByte() }) }
        original.coordinator.finish()
        val originalData = File(directory, "segment-00000.adts").readBytes()
        val originalJournal = File(directory, "segment-00000.commit").readBytes()

        val firstContinuation =
            RecordingSegmentCoordinator.continueFromManifest(
                directory = directory,
                sessionId = "uncommitted-retry-meeting",
                policy = policy,
                fileOperations = JvmRecordingFileOperations,
            ) as RecordingSegmentOpenResult.Success
        firstContinuation.coordinator.finish()
        File(directory, "segment-00001.adts").writeBytes(
            RecordingAdtsFrameCodec.wrap(ByteArray(12), policy.sampleRateHz, 1),
        )

        val retry =
            RecordingSegmentCoordinator.continueFromManifest(
                directory = directory,
                sessionId = "uncommitted-retry-meeting",
                policy = policy,
                fileOperations = JvmRecordingFileOperations,
            )

        assertTrue("retry result was $retry", retry is RecordingSegmentOpenResult.Success)
        assertTrue(originalData.contentEquals(File(directory, "segment-00000.adts").readBytes()))
        assertTrue(originalJournal.contentEquals(File(directory, "segment-00000.commit").readBytes()))
        assertEquals(0L, File(directory, "segment-00001.adts").length())
        assertEquals(0L, File(directory, "segment-00001.commit").length())
        val manifest =
            (AtomicRecordingSegmentManifestStore(directory).load() as RecordingSegmentManifestDecodeResult.Success)
                .manifest
        assertEquals(listOf(0, 1), manifest.segments.map(RecordingSegmentEntry::index))
        (retry as RecordingSegmentOpenResult.Success).coordinator.finish()
    }

    @Test
    fun `production segmentation constants stay below five seconds and near five minutes`() {
        val policy = RecordingSegmentationPolicy.production

        assertEquals(75, policy.commitFrames)
        assertEquals(62, policy.commitGroupsPerSegment)
        assertEquals(4_800L, policy.commitDurationMilliseconds)
        assertEquals(297_600L, policy.segmentDurationMilliseconds)
    }

    private fun baseManifest() =
        RecordingSegmentManifest(
            sessionId = "meeting-one",
            sampleRateHz = 16_000,
            channelCount = 1,
            bitRateBitsPerSecond = 64_000,
            codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
            segments =
                listOf(
                    RecordingSegmentEntry(0, 0, "segment-00000.adts", "segment-00000.commit"),
                ),
        )
}

private class RecordingFileOperationsProbe : RecordingFileOperations {
    val events = mutableListOf<String>()

    override fun writeAndSync(file: File, bytes: ByteArray): Boolean {
        events += "write-sync:${file.name}"
        return true
    }

    override fun atomicReplace(source: File, target: File): Boolean {
        events += "replace:${source.name}->${target.name}"
        return true
    }

    override fun syncDirectory(directory: File): Boolean {
        events += "sync-dir:${directory.name}"
        return true
    }
}

private object JvmRecordingFileOperations : RecordingFileOperations {
    override fun writeAndSync(file: File, bytes: ByteArray): Boolean =
        runCatching {
            java.io.RandomAccessFile(file, "rw").use { output ->
                output.setLength(0)
                output.write(bytes)
                output.fd.sync()
            }
        }.isSuccess

    override fun atomicReplace(source: File, target: File): Boolean =
        runCatching {
            java.nio.file.Files.move(
                source.toPath(),
                target.toPath(),
                java.nio.file.StandardCopyOption.ATOMIC_MOVE,
                java.nio.file.StandardCopyOption.REPLACE_EXISTING,
            )
        }.isSuccess

    override fun syncDirectory(directory: File): Boolean = directory.isDirectory
}

private class FinalDirectorySyncFailureOperations : RecordingFileOperations {
    private var directorySyncCalls = 0

    override fun writeAndSync(file: File, bytes: ByteArray): Boolean =
        JvmRecordingFileOperations.writeAndSync(file, bytes)

    override fun atomicReplace(source: File, target: File): Boolean =
        JvmRecordingFileOperations.atomicReplace(source, target)

    override fun syncDirectory(directory: File): Boolean {
        directorySyncCalls += 1
        return directorySyncCalls == 1
    }
}

private object ThrowingDirectorySyncOperations : RecordingFileOperations {
    override fun writeAndSync(file: File, bytes: ByteArray): Boolean =
        JvmRecordingFileOperations.writeAndSync(file, bytes)

    override fun atomicReplace(source: File, target: File): Boolean =
        JvmRecordingFileOperations.atomicReplace(source, target)

    override fun syncDirectory(directory: File): Boolean = throw java.io.IOException("injected sync failure")
}

private class DurableDirectoryCreationOperations : RecordingFileOperations {
    val syncedDirectories = mutableListOf<String>()

    override fun writeAndSync(file: File, bytes: ByteArray): Boolean =
        JvmRecordingFileOperations.writeAndSync(file, bytes)

    override fun atomicReplace(source: File, target: File): Boolean =
        JvmRecordingFileOperations.atomicReplace(source, target)

    override fun syncDirectory(directory: File): Boolean {
        syncedDirectories += directory.canonicalPath
        return directory.isDirectory
    }
}
