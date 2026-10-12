package com.loquiris.recording

import java.util.UUID

class RecordingChannelSnapshotReader(
    private val store: RecordingStateStore,
    private val isLive: (String?) -> Boolean = RecordingProcessLiveness::owns,
) {
    fun read(): RecordingStateLoadResult {
        val loaded =
            try {
                store.load()
            } catch (_: RuntimeException) {
                return RecordingStateLoadResult.Unavailable("recording_state_load_failed")
            }
        if (loaded !is RecordingStateLoadResult.Loaded) return loaded
        val snapshot = loaded.snapshot
        if (snapshot.state !in PersistedRecordingStateMachine.activeStates || isLive(snapshot.sessionId)) {
            return loaded
        }
        return when (val initialized = PersistedRecordingStateMachine.create(store)) {
            is RecordingStateMachineInitialization.Success ->
                RecordingStateLoadResult.Loaded(initialized.machine.snapshot())
            is RecordingStateMachineInitialization.Failure ->
                RecordingStateLoadResult.Unavailable(initialized.code)
        }
    }
}

object RecordingProcessLiveness {
    val processId: String = UUID.randomUUID().toString()

    @Volatile
    private var liveSessionId: String? = null

    fun claim(sessionId: String) {
        require(sessionId.isNotBlank())
        liveSessionId = sessionId
    }

    fun release(sessionId: String) {
        if (liveSessionId == sessionId) liveSessionId = null
    }

    fun owns(sessionId: String?): Boolean = sessionId != null && liveSessionId == sessionId
}
