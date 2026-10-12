package com.loquiris.recording

import java.io.File
import java.io.IOException

enum class RecordingRecoverySegmentState {
    open,
    committed,
    corrupt,
    missing,
}

data class RecordingRecoverySegmentEvidence(
    val sequence: Int,
    val relativePath: String,
    val startSample: Long,
    val committedSamples: Long,
    val committedBytes: Long,
    val state: RecordingRecoverySegmentState,
)

enum class RecordingRecoveryIntegrityState {
    complete,
    partial,
}

data class RecordingRecoveryDiagnostic(
    val code: String,
    val segmentSequence: Int? = null,
)

data class RecordingRawSegmentExportEntry(
    val sequence: Int,
    val relativePath: String,
    val committedBytes: Long,
)

data class RecordingRecoverySessionEvidence(
    val meetingId: String,
    val storageKey: String,
    val sampleRateHz: Int,
    val segments: List<RecordingRecoverySegmentEvidence>,
    val integrityState: RecordingRecoveryIntegrityState = RecordingRecoveryIntegrityState.complete,
    val diagnostics: List<RecordingRecoveryDiagnostic> = emptyList(),
    val rawExportSegments: List<RecordingRawSegmentExportEntry> = emptyList(),
)

data class RecordingRecoveryInventory(
    val sessions: List<RecordingRecoverySessionEvidence>,
    val deletedIncompleteDerivedFiles: Int,
    val issueCodes: List<String>,
    val liveMeetingIds: List<String> = emptyList(),
    val invalidStorageKeys: List<String> = emptyList(),
)

class RecordingRecoveryScanException(
    val code: String,
) : RuntimeException(code)

class RecordingStartupReconciler(
    private val recordingsDirectory: File,
    private val isSessionLive: (String) -> Boolean = { RecordingProcessLiveness.owns(it) },
    private val listSessionDirectories: (File) -> Array<File>? = File::listFiles,
    private val rebuildInterruptedPlayback: (File) -> RecordingM4aRebuildResult = {
        RecordingM4aRebuilder().rebuild(it)
    },
    private val readBytes: (File) -> ByteArray = File::readBytes,
) {
    fun scan(): RecordingRecoveryInventory {
        if (!recordingsDirectory.exists()) {
            return RecordingRecoveryInventory(emptyList(), 0, emptyList())
        }
        if (!recordingsDirectory.isDirectory) {
            return RecordingRecoveryInventory(
                emptyList(),
                0,
                listOf("recording_recovery_directory_invalid"),
            )
        }

        val sessions = mutableListOf<RecordingRecoverySessionEvidence>()
        val issues = mutableListOf<String>()
        val liveMeetingIds = mutableListOf<String>()
        val invalidStorageKeys = mutableListOf<String>()
        var deletedDerivedFiles = 0
        val sessionDirectories =
            listSessionDirectories(recordingsDirectory)
                ?: throw RecordingRecoveryScanException("recording_recovery_directory_unavailable")
        sessionDirectories
            .filter(File::isDirectory)
            .sortedBy(File::getName)
            .forEach { sessionDirectory ->
                val loaded = AtomicRecordingSegmentManifestStore(sessionDirectory).load()
                if (loaded is RecordingSegmentManifestDecodeResult.Success && isSessionLive(loaded.manifest.sessionId)) {
                    liveMeetingIds += loaded.manifest.sessionId
                    return@forEach
                }
                INCOMPLETE_DERIVED_FILE_NAMES.forEach { fileName ->
                    val file = File(sessionDirectory, fileName)
                    if (file.exists()) {
                        if (file.isFile && file.delete()) {
                            deletedDerivedFiles += 1
                        } else {
                            issues += "recording_derived_cleanup_failed"
                        }
                    }
                }
                val playbackStatus = RecordingM4aArtifactStatusStore(sessionDirectory).load()
                if (
                    playbackStatus is RecordingM4aArtifactStatusLoadResult.Loaded &&
                    playbackStatus.status.state == RecordingM4aArtifactState.building
                ) {
                    val rebuilt = rebuildInterruptedPlayback(sessionDirectory)
                    if (rebuilt is RecordingM4aRebuildResult.Failure) {
                        issues += "recording_m4a_startup_rebuild_failed"
                        issues += rebuilt.code
                    }
                }
                when (loaded) {
                    is RecordingSegmentManifestDecodeResult.Corrupt -> {
                        issues += loaded.code
                        invalidStorageKeys += sessionDirectory.name
                    }
                    is RecordingSegmentManifestDecodeResult.Success ->
                        sessions += recoverSession(sessionDirectory, loaded.manifest, issues)
                }
            }
        return RecordingRecoveryInventory(
            sessions = sessions,
            deletedIncompleteDerivedFiles = deletedDerivedFiles,
            issueCodes = issues.distinct(),
            liveMeetingIds = liveMeetingIds.distinct(),
            invalidStorageKeys = invalidStorageKeys.distinct(),
        )
    }

    private fun recoverSession(
        directory: File,
        manifest: RecordingSegmentManifest,
        issues: MutableList<String>,
    ): RecordingRecoverySessionEvidence {
        val relativeDirectory = "recordings/${directory.name}"
        val diagnostics = mutableListOf<RecordingRecoveryDiagnostic>()
        var expectedStartSample = 0L
        val segments =
            manifest.segments.map { entry ->
                if (entry.startSample != expectedStartSample) {
                    diagnostics +=
                        RecordingRecoveryDiagnostic(
                            code = "recording_recovery_timeline_gap",
                            segmentSequence = entry.index,
                        )
                }
                val dataFile = File(directory, entry.dataFileName)
                val journalFile = File(directory, entry.journalFileName)
                if (!dataFile.isFile || !journalFile.isFile) {
                    diagnostics +=
                        RecordingRecoveryDiagnostic(
                            code = "recording_recovery_segment_missing",
                            segmentSequence = entry.index,
                        )
                    expectedStartSample = entry.startSample
                    return@map RecordingRecoverySegmentEvidence(
                        sequence = entry.index,
                        relativePath = "$relativeDirectory/${entry.dataFileName}",
                        startSample = entry.startSample,
                        committedSamples = 0,
                        committedBytes = 0,
                        state = RecordingRecoverySegmentState.missing,
                    )
                }
                try {
                    val dataBytes = readBytes(dataFile)
                    val journalBytes = readBytes(journalFile)
                    val prefix = RecordingCommittedPrefixRecovery.recover(dataBytes, journalBytes)
                    val corrupt = journalBytes.isNotEmpty() && prefix.committedBytes == 0
                    if (corrupt) {
                        diagnostics +=
                            RecordingRecoveryDiagnostic(
                                code = "recording_recovery_segment_corrupt",
                                segmentSequence = entry.index,
                            )
                    }
                    if (prefix.uncommittedOrInvalidBytes > 0) {
                        diagnostics +=
                            RecordingRecoveryDiagnostic(
                                code = "recording_recovery_tail_discarded",
                                segmentSequence = entry.index,
                            )
                    }
                    expectedStartSample =
                        runCatching { Math.addExact(entry.startSample, prefix.committedSamples) }
                            .getOrElse {
                                diagnostics +=
                                    RecordingRecoveryDiagnostic(
                                        code = "recording_recovery_timeline_gap",
                                        segmentSequence = entry.index,
                                    )
                                entry.startSample
                            }
                    RecordingRecoverySegmentEvidence(
                        sequence = entry.index,
                        relativePath = "$relativeDirectory/${entry.dataFileName}",
                        startSample = entry.startSample,
                        committedSamples = prefix.committedSamples,
                        committedBytes = prefix.committedBytes.toLong(),
                        state =
                            if (corrupt) {
                                RecordingRecoverySegmentState.corrupt
                            } else if (prefix.committedBytes > 0) {
                                RecordingRecoverySegmentState.committed
                            } else {
                                RecordingRecoverySegmentState.open
                            },
                    )
                } catch (_: IOException) {
                    throw RecordingRecoveryScanException("recording_segment_read_failed")
                }
            }
        return RecordingRecoverySessionEvidence(
            meetingId = manifest.sessionId,
            storageKey = directory.name,
            sampleRateHz = manifest.sampleRateHz,
            segments = segments,
            integrityState =
                if (diagnostics.isEmpty()) {
                    RecordingRecoveryIntegrityState.complete
                } else {
                    RecordingRecoveryIntegrityState.partial
                },
            diagnostics = diagnostics.distinct(),
            rawExportSegments =
                segments.mapNotNull { segment ->
                    if (segment.state != RecordingRecoverySegmentState.committed || segment.committedBytes <= 0) {
                        null
                    } else {
                        RecordingRawSegmentExportEntry(
                            sequence = segment.sequence,
                            relativePath = segment.relativePath,
                            committedBytes = segment.committedBytes,
                        )
                    }
                },
        )
    }

    private companion object {
        val INCOMPLETE_DERIVED_FILE_NAMES =
            setOf(
                "continuous.m4a.tmp",
                "${RecordingM4aRebuilder.OUTPUT_FILE_NAME}.tmp",
                "${RecordingM4aArtifactStatusStore.STATUS_FILE_NAME}.tmp",
                "waveform.bin.tmp",
            )
    }
}
