package com.loquiris.recording

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingStoragePolicyTest {
    @Test
    fun `four hour preflight includes encoded estimate and 512 MiB safety reserve`() {
        val decision = RecordingStoragePolicy.preflight(RecordingStoragePolicy.startRequiredBytes)

        assertEquals(120_960_000L, RecordingStoragePolicy.fourHourEstimatedBytes)
        assertEquals(536_870_912L, RecordingStoragePolicy.startSafetyReserveBytes)
        assertEquals(657_830_912L, RecordingStoragePolicy.startRequiredBytes)
        assertTrue(decision is RecordingStoragePreflightDecision.Allowed)
    }

    @Test
    fun `preflight rejects one byte below the four hour requirement with structured values`() {
        val available = RecordingStoragePolicy.startRequiredBytes - 1L

        assertEquals(
            RecordingStoragePreflightDecision.Denied(
                code = "recording_storage_preflight_insufficient",
                availableBytes = available,
                requiredBytes = RecordingStoragePolicy.startRequiredBytes,
            ),
            RecordingStoragePolicy.preflight(available),
        )
    }

    @Test
    fun `active policy warns below thirty minute estimate plus 256 MiB`() {
        val available = RecordingStoragePolicy.warningThresholdBytes - 1L

        assertEquals(
            RecordingActiveStorageDecision.Warning(
                availableBytes = available,
                warningThresholdBytes = RecordingStoragePolicy.warningThresholdBytes,
            ),
            RecordingStoragePolicy.active(available),
        )
        assertEquals(283_555_456L, RecordingStoragePolicy.warningThresholdBytes)
    }

    @Test
    fun `active policy requires safe stop before the next logical segment cannot fit`() {
        val available = RecordingStoragePolicy.criticalThresholdBytes - 1L

        assertEquals(
            RecordingActiveStorageDecision.Critical(
                code = "recording_storage_critically_low",
                availableBytes = available,
                requiredBytes = RecordingStoragePolicy.criticalThresholdBytes,
            ),
            RecordingStoragePolicy.active(available),
        )
        assertEquals(3_548_416L, RecordingStoragePolicy.criticalThresholdBytes)
    }

    @Test
    fun `unavailable space is a structured denial before start and critical while active`() {
        assertEquals(
            RecordingStoragePreflightDecision.Denied(
                code = "recording_storage_unavailable",
                availableBytes = null,
                requiredBytes = RecordingStoragePolicy.startRequiredBytes,
            ),
            RecordingStoragePolicy.preflight(null),
        )
        assertEquals(
            RecordingActiveStorageDecision.Critical(
                code = "recording_storage_unavailable",
                availableBytes = null,
                requiredBytes = RecordingStoragePolicy.criticalThresholdBytes,
            ),
            RecordingStoragePolicy.active(null),
        )
    }

    @Test
    fun `low storage terminal reason is checksummed and persisted with exact capacity`() {
        val sink = MemoryStorageFailureSink()
        val event =
            RecordingStorageFailureEvent(
                sessionId = "meeting-1",
                code = "recording_storage_critically_low",
                availableBytes = 3_000_000L,
                requiredBytes = RecordingStoragePolicy.criticalThresholdBytes,
                mediaElapsedMilliseconds = 42_000L,
                wallClockEpochMilliseconds = 90_000L,
            )

        assertTrue(RecordingStorageFailureJournal(sink).persist(event))
        assertEquals(event, RecordingStorageFailureFrame.decode(sink.frame!!))
    }

    @Test
    fun `failed pipeline plus critical space recovers with a storage reason`() {
        assertEquals(
            RecordingStorageServiceAction.recoverWithStorageReason,
            RecordingStorageServicePolicy.action(
                pipelineFailed = true,
                storage = RecordingStoragePolicy.active(0L),
            ),
        )
    }

    @Test
    fun `healthy pipeline plus critical space uses safe finalization`() {
        assertEquals(
            RecordingStorageServiceAction.safeFinalize,
            RecordingStorageServicePolicy.action(
                pipelineFailed = false,
                storage = RecordingStoragePolicy.active(0L),
            ),
        )
    }
}

private class MemoryStorageFailureSink : RecordingStorageFailureSink {
    var frame: String? = null

    override fun writeAndSync(frame: String): Boolean {
        this.frame = frame
        return true
    }
}
