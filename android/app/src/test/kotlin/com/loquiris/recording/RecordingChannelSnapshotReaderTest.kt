package com.loquiris.recording

import org.junit.Assert.assertEquals
import org.junit.Test

class RecordingChannelSnapshotReaderTest {
    @Test
    fun `cold process converts stale active state to recoverable`() {
        val store =
            SnapshotReaderStore(
                NativeRecordingSnapshot(
                    sessionId = "meeting-1",
                    state = NativeRecordingState.recording,
                    elapsedMilliseconds = 3_000,
                    bytesWritten = 24_000,
                    revision = 4,
                ),
            )

        val result = RecordingChannelSnapshotReader(store) { false }.read()

        assertEquals(NativeRecordingState.recoverable, (result as RecordingStateLoadResult.Loaded).snapshot.state)
        assertEquals(5, result.snapshot.revision)
        assertEquals(NativeRecordingState.recoverable, store.snapshot.state)
    }

    @Test
    fun `live service ownership preserves active state`() {
        val store = SnapshotReaderStore(activeSnapshot())

        val result = RecordingChannelSnapshotReader(store) { sessionId -> sessionId == "meeting-1" }.read()

        assertEquals(NativeRecordingState.recording, (result as RecordingStateLoadResult.Loaded).snapshot.state)
        assertEquals(4, result.snapshot.revision)
    }

    @Test
    fun `provisional process liveness protects persisted preparing state during startup`() {
        val store =
            SnapshotReaderStore(
                activeSnapshot().copy(state = NativeRecordingState.preparing),
            )
        RecordingProcessLiveness.claim("meeting-1")

        try {
            val result = RecordingChannelSnapshotReader(store).read()

            assertEquals(
                NativeRecordingState.preparing,
                (result as RecordingStateLoadResult.Loaded).snapshot.state,
            )
            assertEquals(4, result.snapshot.revision)
            assertEquals(NativeRecordingState.preparing, store.snapshot.state)
        } finally {
            RecordingProcessLiveness.release("meeting-1")
        }
    }

    private fun activeSnapshot() =
        NativeRecordingSnapshot(
            sessionId = "meeting-1",
            state = NativeRecordingState.recording,
            elapsedMilliseconds = 3_000,
            bytesWritten = 24_000,
            revision = 4,
        )
}

private class SnapshotReaderStore(
    var snapshot: NativeRecordingSnapshot,
) : RecordingStateStore {
    override fun load(): RecordingStateLoadResult = RecordingStateLoadResult.Loaded(snapshot)

    override fun save(snapshot: NativeRecordingSnapshot): Boolean {
        this.snapshot = snapshot
        return true
    }
}
