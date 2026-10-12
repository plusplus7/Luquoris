package com.loquiris.recording

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RecordingChannelContractTest {
    @Test
    fun `accepted command exposes its correlation id`() {
        val encoded = RecordingChannelContract.accepted("command-1")

        assertEquals("command-1", encoded["commandId"])
    }

    @Test
    fun `snapshot contract preserves restoration identity and progress`() {
        val encoded =
            RecordingChannelContract.snapshot(
                NativeRecordingSnapshot(
                    sessionId = "meeting-1",
                    state = NativeRecordingState.pausedByInterruption,
                    elapsedMilliseconds = 12_345,
                    bytesWritten = 98_765,
                    revision = 7,
                ),
                AudioInputHealthSnapshot(
                    readCalls = 48,
                    pcmBytes = 196_608,
                    shortReads = 1,
                    zeroReads = 2,
                    errorReads = 0,
                    maximumReadGapNanos = 22_000_000,
                    timestampRegressions = 0,
                ),
            )

        assertEquals(1, encoded["v"])
        assertEquals(true, encoded["ok"])
        val snapshot = encoded["snapshot"] as Map<*, *>
        assertEquals("meeting-1", snapshot["sessionId"])
        assertEquals("pausedByInterruption", snapshot["state"])
        assertEquals(12_345L, snapshot["elapsedMilliseconds"])
        assertEquals(98_765L, snapshot["bytesWritten"])
        assertEquals(7L, snapshot["revision"])
        val health = snapshot["inputHealth"] as Map<*, *>
        assertEquals(48L, health["readCalls"])
        assertEquals(196_608L, health["pcmBytes"])
        assertEquals(1L, health["shortReads"])
        assertEquals(2L, health["zeroReads"])
        assertEquals(0L, health["errorReads"])
        assertEquals(22_000_000L, health["maximumReadGapNanos"])
        assertEquals(0L, health["timestampRegressions"])
    }

    @Test
    fun `idle snapshot carries an explicit null session`() {
        val encoded = RecordingChannelContract.snapshot(NativeRecordingSnapshot.Idle)

        val snapshot = encoded["snapshot"] as Map<*, *>
        assertNull(snapshot["sessionId"])
    }

    @Test
    fun `failure contract retains structured storage quantities`() {
        val encoded =
            RecordingChannelContract.failure(
                code = "recording_storage_preflight_insufficient",
                availableBytes = 10,
                requiredBytes = 20,
            )

        assertEquals(1, encoded["v"])
        assertEquals(false, encoded["ok"])
        val failure = encoded["failure"] as Map<*, *>
        assertEquals("recording_storage_preflight_insufficient", failure["code"])
        assertEquals(10L, failure["availableBytes"])
        assertEquals(20L, failure["requiredBytes"])
    }

    @Test
    fun `startup recovery contract exposes only manifest derived metadata`() {
        val encoded =
            RecordingChannelContract.recoveryInventory(
                RecordingRecoveryInventory(
                    sessions =
                        listOf(
                            RecordingRecoverySessionEvidence(
                                meetingId = "meeting-1",
                                storageKey = "hash",
                                sampleRateHz = 16_000,
                                integrityState = RecordingRecoveryIntegrityState.partial,
                                diagnostics =
                                    listOf(
                                        RecordingRecoveryDiagnostic(
                                            "recording_recovery_timeline_gap",
                                            0,
                                        ),
                                    ),
                                rawExportSegments =
                                    listOf(
                                        RecordingRawSegmentExportEntry(
                                            0,
                                            "recordings/hash/segment-00000.adts",
                                            128,
                                        ),
                                    ),
                                segments =
                                    listOf(
                                        RecordingRecoverySegmentEvidence(
                                            sequence = 0,
                                            relativePath = "recordings/hash/segment-00000.adts",
                                            startSample = 0,
                                            committedSamples = 1_024,
                                            committedBytes = 128,
                                            state = RecordingRecoverySegmentState.committed,
                                        ),
                                    ),
                            ),
                        ),
                    deletedIncompleteDerivedFiles = 2,
                    issueCodes = listOf("recording_manifest_corrupt"),
                    liveMeetingIds = listOf("meeting-live"),
                    invalidStorageKeys = listOf("corrupt-key"),
                ),
            )

        val recovery = encoded["recovery"] as Map<*, *>
        assertEquals(2, recovery["deletedIncompleteDerivedFiles"])
        assertEquals(listOf("recording_manifest_corrupt"), recovery["issueCodes"])
        assertEquals(listOf("meeting-live"), recovery["liveMeetingIds"])
        assertEquals(listOf("corrupt-key"), recovery["invalidStorageKeys"])
        val session = (recovery["sessions"] as List<*>).single() as Map<*, *>
        assertEquals("meeting-1", session["meetingId"])
        assertEquals("hash", session["storageKey"])
        assertEquals("partial", session["integrityState"])
        val diagnostic = (session["diagnostics"] as List<*>).single() as Map<*, *>
        assertEquals("recording_recovery_timeline_gap", diagnostic["code"])
        assertEquals(0, diagnostic["segmentSequence"])
        val rawExport = (session["rawExportSegments"] as List<*>).single() as Map<*, *>
        assertEquals(128L, rawExport["committedBytes"])
        val segment = (session["segments"] as List<*>).single() as Map<*, *>
        assertEquals("committed", segment["state"])
        assertEquals(128L, segment["committedBytes"])
    }
}
