package com.loquiris.recording

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PersistedRecordingStateMachineTest {
    @Test
    fun `commands persist legal transitions and repeated commands are idempotent`() {
        val store = FakeRecordingStateStore()
        val machine = createMachine(store)

        assertChanged(machine.start("meeting-1"), NativeRecordingState.preparing)
        assertChanged(machine.markRecording(), NativeRecordingState.recording)
        assertChanged(machine.updateProgress(elapsedMilliseconds = 2_000, bytesWritten = 16_000), NativeRecordingState.recording)
        assertChanged(machine.pause(), NativeRecordingState.pausedByUser)
        assertUnchanged(machine.pause(), NativeRecordingState.pausedByUser)
        assertChanged(machine.resume(), NativeRecordingState.recording)
        assertUnchanged(machine.resume(), NativeRecordingState.recording)
        assertChanged(machine.stop(), NativeRecordingState.stopping)
        assertUnchanged(machine.stop(), NativeRecordingState.stopping)
        assertChanged(machine.markFinalized(), NativeRecordingState.finalized)

        assertEquals(7, store.saved.size)
        assertEquals(2_000, machine.snapshot().elapsedMilliseconds)
        assertEquals(16_000, machine.snapshot().bytesWritten)
    }

    @Test
    fun `active session rejects a different start without overwriting persisted state`() {
        val store = FakeRecordingStateStore()
        val machine = createMachine(store)
        assertTrue(machine.start("meeting-1") is RecordingCommandResult.Success)

        val result = machine.start("meeting-2")

        assertEquals("recording_session_conflict", (result as RecordingCommandResult.Failure).code)
        assertEquals("meeting-1", machine.snapshot().sessionId)
        assertEquals(1, store.saved.size)
    }

    @Test
    fun `failed persistence leaves authoritative in-memory state unchanged`() {
        val store = FakeRecordingStateStore().apply { failNextSave = true }
        val machine = createMachine(store)

        val result = machine.start("meeting-1")

        assertEquals("recording_state_persist_failed", (result as RecordingCommandResult.Failure).code)
        assertEquals(NativeRecordingState.idle, machine.snapshot().state)
        assertEquals(null, machine.snapshot().sessionId)
    }

    @Test
    fun `process reconstruction makes a stale active snapshot recoverable`() {
        val store =
            FakeRecordingStateStore(
                loaded =
                    NativeRecordingSnapshot(
                        sessionId = "meeting-1",
                        state = NativeRecordingState.recording,
                        elapsedMilliseconds = 3_000,
                        bytesWritten = 24_000,
                        revision = 4,
                    ),
            )

        val machine = createMachine(store)

        assertEquals(NativeRecordingState.recoverable, machine.snapshot().state)
        assertEquals(5, machine.snapshot().revision)
        assertEquals(NativeRecordingState.recoverable, store.saved.single().state)
    }

    @Test
    fun `state reconstruction preserves a recorder still owned by this process`() {
        val store = FakeRecordingStateStore(loaded = activeSnapshot())

        val initialized =
            PersistedRecordingStateMachine.create(
                store,
                isSessionLive = { it == "meeting-1" },
            ) as RecordingStateMachineInitialization.Success

        assertEquals(NativeRecordingState.recording, initialized.machine.snapshot().state)
        assertTrue(store.saved.isEmpty())
    }

    @Test
    fun `fatal capture failure durably makes an active session recoverable`() {
        val store = FakeRecordingStateStore()
        val machine = createMachine(store)
        machine.start("meeting-1")
        machine.markRecording()

        assertChanged(machine.markRecoverable(), NativeRecordingState.recoverable)
        assertUnchanged(machine.markRecoverable(), NativeRecordingState.recoverable)
        assertEquals(NativeRecordingState.recoverable, store.saved.last().state)
    }

    @Test
    fun `recovery resolution never starts implicitly and explicit continuation preserves progress`() {
        val store = FakeRecordingStateStore()
        val machine = createMachine(store)
        machine.start("meeting-1")
        machine.markRecording()
        machine.updateProgress(elapsedMilliseconds = 3_000, bytesWritten = 24_000)
        machine.markRecoverable()
        val savesBeforeReview = store.saved.size

        assertEquals(NativeRecordingState.recoverable, machine.snapshot().state)
        assertEquals(savesBeforeReview, store.saved.size)
        assertChanged(
            machine.continueRecovered(
                sessionId = "meeting-1",
                elapsedMilliseconds = 3_200,
                bytesWritten = 25_000,
            ),
            NativeRecordingState.preparing,
        )
        assertEquals(3_200, machine.snapshot().elapsedMilliseconds)
        assertEquals(25_000, machine.snapshot().bytesWritten)
    }

    @Test
    fun `saving recovered state finalizes without entering a microphone state`() {
        val store = FakeRecordingStateStore()
        val machine = createMachine(store)
        machine.start("meeting-1")
        machine.markRecoverable()

        assertChanged(machine.finalizeRecovered("meeting-1"), NativeRecordingState.finalized)
        assertUnchanged(machine.finalizeRecovered("meeting-1"), NativeRecordingState.finalized)
        assertFalse(store.saved.any { it.state == NativeRecordingState.recording })
    }

    @Test
    fun `interruption pause is distinct from user pause and resumes explicitly`() {
        val store = FakeRecordingStateStore()
        val machine = createMachine(store)
        machine.start("meeting-1")
        machine.markRecording()

        assertChanged(machine.pauseForInterruption(), NativeRecordingState.pausedByInterruption)
        assertUnchanged(machine.pauseForInterruption(), NativeRecordingState.pausedByInterruption)
        assertChanged(machine.resumeFromInterruption(), NativeRecordingState.recording)
        assertEquals(NativeRecordingState.recording, store.saved.last().state)
    }

    @Test
    fun `snapshot is read only`() {
        val store = FakeRecordingStateStore()
        val machine = createMachine(store)

        val first = machine.snapshot()
        val second = machine.snapshot()

        assertEquals(first, second)
        assertTrue(store.saved.isEmpty())
    }

    @Test
    fun `finalized session start retry is unchanged and never persisted`() {
        val store = FakeRecordingStateStore()
        val machine = createMachine(store)
        machine.start("meeting-1")
        machine.stop()
        machine.markFinalized()
        val savesBeforeRetry = store.saved.size

        val retry = machine.start("meeting-1")

        assertUnchanged(retry, NativeRecordingState.finalized)
        assertEquals(savesBeforeRetry, store.saved.size)
    }

    @Test
    fun `corrupt persisted state fails initialization without an idle machine`() {
        val result =
            PersistedRecordingStateMachine.create(
                FakeRecordingStateStore(loadResult = RecordingStateLoadResult.Corrupt("recording_state_corrupt")),
            )

        assertEquals(
            "recording_state_corrupt",
            (result as RecordingStateMachineInitialization.Failure).code,
        )
    }

    @Test
    fun `recovery persistence failure returns typed initialization failure`() {
        val store =
            FakeRecordingStateStore(
                loaded = activeSnapshot(),
            ).apply { failNextSave = true }

        val result = PersistedRecordingStateMachine.create(store)

        assertEquals(
            "recording_state_recovery_persist_failed",
            (result as RecordingStateMachineInitialization.Failure).code,
        )
    }

    @Test
    fun `recovery persistence exception returns typed initialization failure`() {
        val store =
            FakeRecordingStateStore(
                loaded = activeSnapshot(),
            ).apply { throwNextSave = true }

        val result = PersistedRecordingStateMachine.create(store)

        assertEquals(
            "recording_state_recovery_persist_failed",
            (result as RecordingStateMachineInitialization.Failure).code,
        )
    }

    @Test
    fun `load exception returns typed initialization failure`() {
        val result =
            PersistedRecordingStateMachine.create(
                FakeRecordingStateStore().apply { throwOnLoad = true },
            )

        assertEquals(
            "recording_state_load_failed",
            (result as RecordingStateMachineInitialization.Failure).code,
        )
    }

    @Test
    fun `active snapshot with exhausted revision fails initialization as corrupt`() {
        val result =
            PersistedRecordingStateMachine.create(
                FakeRecordingStateStore(
                    loaded = activeSnapshot().copy(revision = Long.MAX_VALUE),
                ),
            )

        assertEquals(
            "recording_state_corrupt",
            (result as RecordingStateMachineInitialization.Failure).code,
        )
    }

    @Test
    fun `active snapshot before reserved terminal revision fails recovery without persistence`() {
        val store =
            FakeRecordingStateStore(
                loaded = activeSnapshot().copy(revision = Long.MAX_VALUE - 1),
            )

        val result = PersistedRecordingStateMachine.create(store)

        assertEquals(
            "recording_state_revision_exhausted",
            (result as RecordingStateMachineInitialization.Failure).code,
        )
        assertTrue(store.saved.isEmpty())
    }

    @Test
    fun `command before reserved terminal revision fails without persistence`() {
        val store =
            FakeRecordingStateStore(
                loaded =
                    NativeRecordingSnapshot(
                        sessionId = "meeting-0",
                        state = NativeRecordingState.finalized,
                        elapsedMilliseconds = 0,
                        bytesWritten = 0,
                        revision = Long.MAX_VALUE - 1,
                    ),
            )
        val machine = createMachine(store)
        val savesBeforeFailure = store.saved.size

        val result = machine.start("meeting-1")

        assertEquals(
            "recording_state_revision_exhausted",
            (result as RecordingCommandResult.Failure).code,
        )
        assertEquals(Long.MAX_VALUE - 1, machine.snapshot().revision)
        assertEquals(NativeRecordingState.finalized, machine.snapshot().state)
        assertEquals(savesBeforeFailure, store.saved.size)
    }

    @Test
    fun `store exception returns typed failure and preserves current state`() {
        val store = FakeRecordingStateStore()
        val machine = createMachine(store)
        store.throwNextSave = true

        val result = machine.start("meeting-1")

        assertEquals("recording_state_persist_failed", (result as RecordingCommandResult.Failure).code)
        assertEquals(NativeRecordingState.idle, machine.snapshot().state)
    }

    private fun assertChanged(
        result: RecordingCommandResult,
        expectedState: NativeRecordingState,
    ) {
        val success = result as RecordingCommandResult.Success
        assertTrue(success.changed)
        assertEquals(expectedState, success.snapshot.state)
    }

    private fun assertUnchanged(
        result: RecordingCommandResult,
        expectedState: NativeRecordingState,
    ) {
        val success = result as RecordingCommandResult.Success
        assertFalse(success.changed)
        assertEquals(expectedState, success.snapshot.state)
    }

    private fun createMachine(store: RecordingStateStore): PersistedRecordingStateMachine =
        (PersistedRecordingStateMachine.create(store) as RecordingStateMachineInitialization.Success).machine

    private fun activeSnapshot() =
        NativeRecordingSnapshot(
            sessionId = "meeting-1",
            state = NativeRecordingState.recording,
            elapsedMilliseconds = 3_000,
            bytesWritten = 24_000,
            revision = 4,
        )
}

private class FakeRecordingStateStore(
    private val loaded: NativeRecordingSnapshot? = null,
    private val loadResult: RecordingStateLoadResult? = null,
) : RecordingStateStore {
    val saved = mutableListOf<NativeRecordingSnapshot>()
    var failNextSave = false
    var throwNextSave = false
    var throwOnLoad = false

    override fun load(): RecordingStateLoadResult {
        if (throwOnLoad) error("store unavailable")
        return loadResult ?: loaded?.let(RecordingStateLoadResult::Loaded) ?: RecordingStateLoadResult.Absent
    }

    override fun save(snapshot: NativeRecordingSnapshot): Boolean {
        if (throwNextSave) {
            throwNextSave = false
            error("store unavailable")
        }
        if (failNextSave) {
            failNextSave = false
            return false
        }
        saved += snapshot
        return true
    }
}
