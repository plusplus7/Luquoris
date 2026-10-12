package com.loquiris.recording

enum class NativeRecordingState {
    idle,
    preparing,
    recording,
    pausedByUser,
    pausedByInterruption,
    stopping,
    finalized,
    recoverable,
    failedFinalization,
}

data class NativeRecordingSnapshot(
    val sessionId: String?,
    val state: NativeRecordingState,
    val elapsedMilliseconds: Long,
    val bytesWritten: Long,
    val revision: Long,
) {
    init {
        require(sessionId == null || sessionId.isNotBlank()) { "sessionId must be null or non-blank" }
        require(elapsedMilliseconds >= 0) { "elapsedMilliseconds must be non-negative" }
        require(bytesWritten >= 0) { "bytesWritten must be non-negative" }
        require(revision >= 0) { "revision must be non-negative" }
        require((state == NativeRecordingState.idle) == (sessionId == null)) {
            "only idle snapshots omit the sessionId"
        }
    }

    companion object {
        val Idle =
            NativeRecordingSnapshot(
                sessionId = null,
                state = NativeRecordingState.idle,
                elapsedMilliseconds = 0,
                bytesWritten = 0,
                revision = 0,
            )
    }
}

sealed interface RecordingCommandResult {
    data class Success(
        val snapshot: NativeRecordingSnapshot,
        val changed: Boolean,
    ) : RecordingCommandResult

    data class Failure(
        val code: String,
        val snapshot: NativeRecordingSnapshot,
    ) : RecordingCommandResult
}

sealed interface RecordingStateLoadResult {
    data object Absent : RecordingStateLoadResult

    data class Loaded(
        val snapshot: NativeRecordingSnapshot,
    ) : RecordingStateLoadResult

    data class Corrupt(
        val code: String,
    ) : RecordingStateLoadResult

    data class Unavailable(
        val code: String,
    ) : RecordingStateLoadResult
}

sealed interface RecordingStateMachineInitialization {
    data class Success(
        val machine: PersistedRecordingStateMachine,
    ) : RecordingStateMachineInitialization

    data class Failure(
        val code: String,
    ) : RecordingStateMachineInitialization
}

interface RecordingStateStore {
    fun load(): RecordingStateLoadResult

    fun save(snapshot: NativeRecordingSnapshot): Boolean
}

class PersistedRecordingStateMachine private constructor(
    private val store: RecordingStateStore,
    initial: NativeRecordingSnapshot,
) {
    private var current = initial

    @Synchronized
    fun snapshot(): NativeRecordingSnapshot = current

    @Synchronized
    fun start(sessionId: String): RecordingCommandResult {
        if (sessionId.isBlank()) return failure("recording_session_invalid")
        if (current.sessionId == sessionId) return unchanged()
        if (current.state !in setOf(NativeRecordingState.idle, NativeRecordingState.finalized)) {
            return failure("recording_session_conflict")
        }
        val revision = nextRevision() ?: return failure("recording_state_revision_exhausted")
        return transition(
            NativeRecordingSnapshot(
                sessionId = sessionId,
                state = NativeRecordingState.preparing,
                elapsedMilliseconds = 0,
                bytesWritten = 0,
                revision = revision,
            ),
        )
    }

    @Synchronized
    fun markRecording(): RecordingCommandResult =
        when (current.state) {
            NativeRecordingState.preparing -> transitionState(NativeRecordingState.recording)
            NativeRecordingState.recording -> unchanged()
            else -> failure("recording_transition_invalid")
        }

    @Synchronized
    fun pause(): RecordingCommandResult =
        when (current.state) {
            NativeRecordingState.recording -> transitionState(NativeRecordingState.pausedByUser)
            NativeRecordingState.pausedByUser -> unchanged()
            else -> failure("recording_transition_invalid")
        }

    @Synchronized
    fun pauseForInterruption(): RecordingCommandResult =
        when (current.state) {
            NativeRecordingState.recording -> transitionState(NativeRecordingState.pausedByInterruption)
            NativeRecordingState.pausedByInterruption -> unchanged()
            else -> failure("recording_transition_invalid")
        }

    @Synchronized
    fun resume(): RecordingCommandResult =
        when (current.state) {
            NativeRecordingState.pausedByUser,
            NativeRecordingState.pausedByInterruption,
            -> transitionState(NativeRecordingState.recording)
            NativeRecordingState.recording -> unchanged()
            else -> failure("recording_transition_invalid")
        }

    @Synchronized
    fun resumeFromInterruption(): RecordingCommandResult =
        when (current.state) {
            NativeRecordingState.pausedByInterruption -> transitionState(NativeRecordingState.recording)
            NativeRecordingState.recording -> unchanged()
            else -> failure("recording_transition_invalid")
        }

    @Synchronized
    fun stop(): RecordingCommandResult =
        when (current.state) {
            NativeRecordingState.preparing,
            NativeRecordingState.recording,
            NativeRecordingState.pausedByUser,
            NativeRecordingState.pausedByInterruption,
            -> transitionState(NativeRecordingState.stopping)
            NativeRecordingState.stopping,
            NativeRecordingState.finalized,
            -> unchanged()
            else -> failure("recording_transition_invalid")
        }

    @Synchronized
    fun markFinalized(): RecordingCommandResult =
        when (current.state) {
            NativeRecordingState.stopping -> transitionState(NativeRecordingState.finalized)
            NativeRecordingState.finalized -> unchanged()
            else -> failure("recording_transition_invalid")
        }

    @Synchronized
    fun markRecoverable(): RecordingCommandResult =
        when (current.state) {
            NativeRecordingState.preparing,
            NativeRecordingState.recording,
            NativeRecordingState.pausedByUser,
            NativeRecordingState.pausedByInterruption,
            NativeRecordingState.stopping,
            NativeRecordingState.failedFinalization,
            -> transitionState(NativeRecordingState.recoverable)
            NativeRecordingState.recoverable -> unchanged()
            else -> failure("recording_transition_invalid")
        }

    @Synchronized
    fun finalizeRecovered(sessionId: String): RecordingCommandResult {
        if (sessionId.isBlank()) return failure("recording_session_invalid")
        if (current.sessionId != sessionId) {
            return if (current.state in activeStates) {
                failure("recording_session_conflict")
            } else {
                unchanged()
            }
        }
        return when (current.state) {
            NativeRecordingState.recoverable -> transitionState(NativeRecordingState.finalized)
            NativeRecordingState.finalized -> unchanged()
            else -> failure("recording_transition_invalid")
        }
    }

    @Synchronized
    fun continueRecovered(
        sessionId: String,
        elapsedMilliseconds: Long,
        bytesWritten: Long,
    ): RecordingCommandResult {
        if (sessionId.isBlank() || elapsedMilliseconds < 0L || bytesWritten < 0L) {
            return failure("recording_recovery_evidence_invalid")
        }
        if (current.state in activeStates) return failure("recording_session_conflict")
        if (current.sessionId == sessionId && current.state !in setOf(
                NativeRecordingState.recoverable,
                NativeRecordingState.finalized,
            )
        ) {
            return failure("recording_transition_invalid")
        }
        val revision = nextRevision() ?: return failure("recording_state_revision_exhausted")
        return transition(
            NativeRecordingSnapshot(
                sessionId = sessionId,
                state = NativeRecordingState.preparing,
                elapsedMilliseconds = elapsedMilliseconds,
                bytesWritten = bytesWritten,
                revision = revision,
            ),
        )
    }

    @Synchronized
    fun updateProgress(
        elapsedMilliseconds: Long,
        bytesWritten: Long,
    ): RecordingCommandResult {
        if (current.state !in activeStates) return failure("recording_transition_invalid")
        if (elapsedMilliseconds < current.elapsedMilliseconds || bytesWritten < current.bytesWritten) {
            return failure("recording_progress_regressed")
        }
        if (elapsedMilliseconds == current.elapsedMilliseconds && bytesWritten == current.bytesWritten) {
            return unchanged()
        }
        val revision = nextRevision() ?: return failure("recording_state_revision_exhausted")
        return transition(
            current.copy(
                elapsedMilliseconds = elapsedMilliseconds,
                bytesWritten = bytesWritten,
                revision = revision,
            ),
        )
    }

    private fun transition(candidate: NativeRecordingSnapshot): RecordingCommandResult {
        val persisted = try {
            store.save(candidate)
        } catch (_: RuntimeException) {
            false
        }
        if (!persisted) return failure("recording_state_persist_failed")
        current = candidate
        return RecordingCommandResult.Success(current, changed = true)
    }

    private fun unchanged(): RecordingCommandResult = RecordingCommandResult.Success(current, changed = false)

    private fun failure(code: String): RecordingCommandResult.Failure = RecordingCommandResult.Failure(code, current)

    private fun transitionState(state: NativeRecordingState): RecordingCommandResult {
        val revision = nextRevision() ?: return failure("recording_state_revision_exhausted")
        return transition(current.copy(state = state, revision = revision))
    }

    private fun nextRevision(): Long? =
        if (current.revision >= Long.MAX_VALUE - 1) null else current.revision + 1

    companion object {
        fun create(
            store: RecordingStateStore,
            isSessionLive: (String) -> Boolean = { false },
        ): RecordingStateMachineInitialization {
            val loaded = try {
                store.load()
            } catch (_: RuntimeException) {
                return RecordingStateMachineInitialization.Failure("recording_state_load_failed")
            }
            val snapshot =
                when (loaded) {
                    RecordingStateLoadResult.Absent -> NativeRecordingSnapshot.Idle
                    is RecordingStateLoadResult.Loaded -> loaded.snapshot
                    is RecordingStateLoadResult.Corrupt -> {
                        return RecordingStateMachineInitialization.Failure(loaded.code)
                    }
                    is RecordingStateLoadResult.Unavailable -> {
                        return RecordingStateMachineInitialization.Failure(loaded.code)
                    }
                }
            if (snapshot.revision == Long.MAX_VALUE) {
                return RecordingStateMachineInitialization.Failure("recording_state_corrupt")
            }
            if (
                snapshot.state !in activeStates ||
                snapshot.sessionId?.let(isSessionLive) == true
            ) {
                return RecordingStateMachineInitialization.Success(
                    PersistedRecordingStateMachine(store, snapshot),
                )
            }
            if (snapshot.revision >= Long.MAX_VALUE - 1) {
                return RecordingStateMachineInitialization.Failure(
                    "recording_state_revision_exhausted",
                )
            }

            val recovered =
                snapshot.copy(
                    state = NativeRecordingState.recoverable,
                    revision = snapshot.revision + 1,
                )
            val persisted = try {
                store.save(recovered)
            } catch (_: RuntimeException) {
                false
            }
            if (!persisted) {
                return RecordingStateMachineInitialization.Failure(
                    "recording_state_recovery_persist_failed",
                )
            }
            return RecordingStateMachineInitialization.Success(
                PersistedRecordingStateMachine(store, recovered),
            )
        }

        val activeStates =
            setOf(
                NativeRecordingState.preparing,
                NativeRecordingState.recording,
                NativeRecordingState.pausedByUser,
                NativeRecordingState.pausedByInterruption,
                NativeRecordingState.stopping,
            )
    }
}
