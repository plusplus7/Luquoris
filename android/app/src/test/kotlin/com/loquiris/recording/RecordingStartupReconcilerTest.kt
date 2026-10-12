package com.loquiris.recording

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class RecordingStartupReconcilerTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `scan trusts manifest journal prefixes and ignores unpublished files`() {
        val recordings = temporaryFolder.newFolder("recordings")
        val sessionDirectory = File(recordings, "opaque-session")
        val opened =
            RecordingSegmentCoordinator.open(
                directory = sessionDirectory,
                sessionId = "meeting-1",
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
                policy = RecordingSegmentationPolicy(commitFrames = 2, commitGroupsPerSegment = 2),
                fileOperations = StartupJvmRecordingFileOperations,
            ) as RecordingSegmentOpenResult.Success
        repeat(3) { opened.coordinator.appendAccessUnit(ByteArray(12) { it.toByte() }) }
        opened.coordinator.finish()
        File(sessionDirectory, "segment-99999.adts").writeBytes(byteArrayOf(1, 2, 3))
        File(sessionDirectory, "segment-99999.commit").writeBytes(byteArrayOf(4, 5, 6))

        val inventory = RecordingStartupReconciler(recordings).scan()

        assertEquals(1, inventory.sessions.size)
        val session = inventory.sessions.single()
        assertEquals("meeting-1", session.meetingId)
        assertEquals(1, session.segments.size)
        assertEquals("recordings/opaque-session/segment-00000.adts", session.segments.single().relativePath)
        assertEquals(3_072L, session.segments.single().committedSamples)
        assertTrue(session.segments.single().committedBytes > 0)
        assertEquals(RecordingRecoverySegmentState.committed, session.segments.single().state)
        assertTrue(inventory.issueCodes.isEmpty())
    }

    @Test
    fun `scan marks a timeline gap partial and plans exact committed prefixes`() {
        val recordings = temporaryFolder.newFolder("timeline-gap")
        val sessionDirectory = File(recordings, "opaque-session")
        val opened =
            RecordingSegmentCoordinator.open(
                directory = sessionDirectory,
                sessionId = "meeting-gap",
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
                policy = RecordingSegmentationPolicy(commitFrames = 1, commitGroupsPerSegment = 1),
                fileOperations = StartupJvmRecordingFileOperations,
            ) as RecordingSegmentOpenResult.Success
        repeat(2) { opened.coordinator.appendAccessUnit(ByteArray(12) { it.toByte() }) }
        opened.coordinator.finish()
        val store = AtomicRecordingSegmentManifestStore(sessionDirectory, StartupJvmRecordingFileOperations)
        val manifest = (store.load() as RecordingSegmentManifestDecodeResult.Success).manifest
        assertTrue(manifest.segments.size >= 2)
        val second = manifest.segments[1]
        store.publish(
            manifest.copy(
                segments = manifest.segments.toMutableList().also {
                    it[1] = second.copy(startSample = second.startSample + 1_024)
                },
            ),
        )

        val session = RecordingStartupReconciler(recordings).scan().sessions.single()

        assertEquals(RecordingRecoveryIntegrityState.partial, session.integrityState)
        assertTrue(
            session.diagnostics.contains(
                RecordingRecoveryDiagnostic("recording_recovery_timeline_gap", 1),
            ),
        )
        assertTrue(session.rawExportSegments.isNotEmpty())
        assertTrue(session.rawExportSegments.all { it.committedBytes > 0 })
        assertEquals(
            session.segments.filter { it.state == RecordingRecoverySegmentState.committed }.map { it.sequence },
            session.rawExportSegments.map { it.sequence },
        )
    }

    @Test
    fun `scan excludes a corrupt journal segment from raw export fallback`() {
        val recordings = temporaryFolder.newFolder("corrupt-journal")
        val sessionDirectory = File(recordings, "opaque-session")
        val opened =
            RecordingSegmentCoordinator.open(
                directory = sessionDirectory,
                sessionId = "meeting-corrupt",
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
                policy = RecordingSegmentationPolicy(commitFrames = 1, commitGroupsPerSegment = 2),
                fileOperations = StartupJvmRecordingFileOperations,
            ) as RecordingSegmentOpenResult.Success
        opened.coordinator.appendAccessUnit(ByteArray(12))
        opened.coordinator.finish()
        val manifest =
            (AtomicRecordingSegmentManifestStore(sessionDirectory, StartupJvmRecordingFileOperations).load() as
                RecordingSegmentManifestDecodeResult.Success).manifest
        val journal = File(sessionDirectory, manifest.segments.single().journalFileName)
        journal.writeBytes(journal.readBytes().also { it[it.lastIndex] = (it.last() + 1).toByte() })

        val session = RecordingStartupReconciler(recordings).scan().sessions.single()

        assertEquals(RecordingRecoveryIntegrityState.partial, session.integrityState)
        assertEquals(RecordingRecoverySegmentState.corrupt, session.segments.single().state)
        assertTrue(session.rawExportSegments.isEmpty())
        assertTrue(
            session.diagnostics.contains(
                RecordingRecoveryDiagnostic("recording_recovery_segment_corrupt", 0),
            ),
        )
    }

    @Test
    fun `scan discloses and excludes bytes after the latest valid commit`() {
        val recordings = temporaryFolder.newFolder("uncommitted-tail")
        val sessionDirectory = File(recordings, "opaque-session")
        val opened =
            RecordingSegmentCoordinator.open(
                directory = sessionDirectory,
                sessionId = "meeting-tail",
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
                policy = RecordingSegmentationPolicy(commitFrames = 1, commitGroupsPerSegment = 2),
                fileOperations = StartupJvmRecordingFileOperations,
            ) as RecordingSegmentOpenResult.Success
        opened.coordinator.appendAccessUnit(ByteArray(12))
        opened.coordinator.finish()
        val manifest =
            (AtomicRecordingSegmentManifestStore(sessionDirectory, StartupJvmRecordingFileOperations).load() as
                RecordingSegmentManifestDecodeResult.Success).manifest
        val dataFile = File(sessionDirectory, manifest.segments.single().dataFileName)
        dataFile.appendBytes(RecordingAdtsFrameCodec.wrap(ByteArray(12), 16_000, 1))

        val session = RecordingStartupReconciler(recordings).scan().sessions.single()

        assertEquals(RecordingRecoveryIntegrityState.partial, session.integrityState)
        assertTrue(
            session.diagnostics.contains(
                RecordingRecoveryDiagnostic("recording_recovery_tail_discarded", 0),
            ),
        )
        assertTrue(session.rawExportSegments.single().committedBytes < dataFile.length())
    }

    @Test
    fun `scan removes only whitelisted incomplete derived files`() {
        val recordings = temporaryFolder.newFolder("derived")
        val sessionDirectory = File(recordings, "opaque-session").apply { mkdir() }
        AtomicRecordingSegmentManifestStore(sessionDirectory, StartupJvmRecordingFileOperations).publish(
            RecordingSegmentManifest(
                sessionId = "meeting-2",
                sampleRateHz = 16_000,
                channelCount = 1,
                bitRateBitsPerSecond = 64_000,
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
                segments = emptyList(),
            ),
        )
        val mergeTemp = File(sessionDirectory, "continuous.m4a.tmp").apply { writeText("partial") }
        val playbackTemp = File(sessionDirectory, "playback.m4a.tmp").apply { writeText("partial") }
        val playbackStatusTemp = File(sessionDirectory, "playback.status.tmp").apply { writeText("partial") }
        val waveformTemp = File(sessionDirectory, "waveform.bin.tmp").apply { writeText("partial") }
        val unknownTemp = File(sessionDirectory, "user-data.tmp").apply { writeText("keep") }

        val inventory = RecordingStartupReconciler(recordings).scan()

        assertEquals(4, inventory.deletedIncompleteDerivedFiles)
        assertFalse(mergeTemp.exists())
        assertFalse(playbackTemp.exists())
        assertFalse(playbackStatusTemp.exists())
        assertFalse(waveformTemp.exists())
        assertTrue(unknownTemp.exists())
    }

    @Test
    fun `scan leaves a process-owned live recording untouched`() {
        val recordings = temporaryFolder.newFolder("live-recording")
        val sessionDirectory = File(recordings, "opaque-session")
        val opened =
            RecordingSegmentCoordinator.open(
                directory = sessionDirectory,
                sessionId = "meeting-live",
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
                policy = RecordingSegmentationPolicy(commitFrames = 1, commitGroupsPerSegment = 2),
                fileOperations = StartupJvmRecordingFileOperations,
            ) as RecordingSegmentOpenResult.Success
        opened.coordinator.appendAccessUnit(ByteArray(12))
        val derivedTemp = File(sessionDirectory, "waveform.bin.tmp").apply { writeText("active") }

        val inventory =
            RecordingStartupReconciler(
                recordingsDirectory = recordings,
                isSessionLive = { it == "meeting-live" },
            ).scan()

        assertTrue(inventory.sessions.isEmpty())
        assertEquals(listOf("meeting-live"), inventory.liveMeetingIds)
        assertEquals(0, inventory.deletedIncompleteDerivedFiles)
        assertTrue(derivedTemp.exists())
        assertTrue(File(sessionDirectory, "segment-00000.adts").exists())
        opened.coordinator.finish()
    }

    @Test
    fun `scan retries a playback rebuild interrupted while status was building`() {
        val recordings = temporaryFolder.newFolder("interrupted-playback")
        val sessionDirectory = File(recordings, "opaque-session")
        val opened =
            RecordingSegmentCoordinator.open(
                directory = sessionDirectory,
                sessionId = "meeting-interrupted",
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
                policy = RecordingSegmentationPolicy(commitFrames = 1, commitGroupsPerSegment = 2),
                fileOperations = StartupJvmRecordingFileOperations,
            ) as RecordingSegmentOpenResult.Success
        opened.coordinator.appendAccessUnit(ByteArray(12))
        opened.coordinator.finish()
        RecordingM4aArtifactStatusStore(sessionDirectory, StartupJvmRecordingFileOperations).publish(
            RecordingM4aArtifactStatus(RecordingM4aArtifactState.building),
        )
        val rebuilt = mutableListOf<File>()

        val inventory =
            RecordingStartupReconciler(
                recordingsDirectory = recordings,
                rebuildInterruptedPlayback = {
                    rebuilt += it
                    RecordingM4aRebuildResult.Success("playback.m4a", 1, 1_024, 128)
                },
            ).scan()

        assertEquals(listOf(sessionDirectory), rebuilt)
        assertFalse(inventory.issueCodes.contains("recording_m4a_startup_rebuild_failed"))
    }

    @Test
    fun `scan reports corrupt manifest storage keys without trusting files`() {
        val recordings = temporaryFolder.newFolder("corrupt-manifest")
        val sessionDirectory = File(recordings, "opaque-corrupt").apply { mkdir() }
        File(sessionDirectory, AtomicRecordingSegmentManifestStore.MANIFEST_FILE_NAME).writeBytes(
            byteArrayOf(1, 2, 3),
        )

        val inventory = RecordingStartupReconciler(recordings).scan()

        assertTrue(inventory.sessions.isEmpty())
        assertEquals(listOf("opaque-corrupt"), inventory.invalidStorageKeys)
        assertTrue(inventory.issueCodes.contains("recording_manifest_corrupt"))
    }

    @Test
    fun `scan fails closed when recording directories cannot be enumerated`() {
        val recordings = temporaryFolder.newFolder("unavailable-listing")
        val reconciler =
            RecordingStartupReconciler(
                recordingsDirectory = recordings,
                listSessionDirectories = { null },
            )

        val failure = runCatching { reconciler.scan() }.exceptionOrNull()

        assertTrue(failure is RecordingRecoveryScanException)
        assertEquals(
            "recording_recovery_directory_unavailable",
            (failure as RecordingRecoveryScanException).code,
        )
    }

    @Test
    fun `transient segment read failure aborts reconciliation instead of declaring corruption`() {
        val recordings = temporaryFolder.newFolder("read-failure")
        val sessionDirectory = File(recordings, "opaque-session")
        val opened =
            RecordingSegmentCoordinator.open(
                directory = sessionDirectory,
                sessionId = "meeting-read-failure",
                codecSpecificData = listOf(byteArrayOf(0x14, 0x08)),
                policy = RecordingSegmentationPolicy(commitFrames = 1, commitGroupsPerSegment = 2),
                fileOperations = StartupJvmRecordingFileOperations,
            ) as RecordingSegmentOpenResult.Success
        opened.coordinator.appendAccessUnit(ByteArray(12))
        opened.coordinator.finish()
        val reconciler =
            RecordingStartupReconciler(
                recordingsDirectory = recordings,
                readBytes = { throw java.io.IOException("injected transient read failure") },
            )

        val failure = runCatching { reconciler.scan() }.exceptionOrNull()

        assertTrue(failure is RecordingRecoveryScanException)
        assertEquals("recording_segment_read_failed", (failure as RecordingRecoveryScanException).code)
    }
}

private object StartupJvmRecordingFileOperations : RecordingFileOperations {
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
