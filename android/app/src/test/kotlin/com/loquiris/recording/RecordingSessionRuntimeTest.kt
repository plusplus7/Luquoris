package com.loquiris.recording

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingSessionRuntimeTest {
    @Test
    fun `capture pause and resume publish monotonic duration and byte snapshots`() {
        var now = 1_000L
        var bytes = 0L
        val machine = startedMachine()
        val runtime =
            RecordingSessionRuntime(
                machine = machine,
                timer = MonotonicRecordingTimer(elapsedRealtimeMillis = { now }),
                bytesWritten = { bytes },
                bookmarkJournal = RecordingBookmarkJournal(RuntimeBookmarkSink()),
                wallClockEpochMillis = { 50_000L },
            )

        assertTrue(runtime.captureStarted() is RecordingCommandResult.Success)
        now = 3_000L
        bytes = 16_000L
        assertTrue(runtime.publishProgress() is RecordingCommandResult.Success)
        assertEquals(2_000L, machine.snapshot().elapsedMilliseconds)
        assertEquals(16_000L, machine.snapshot().bytesWritten)

        assertTrue(runtime.pause() is RecordingCommandResult.Success)
        now = 20_000L
        assertEquals(2_000L, runtime.snapshot().elapsedMilliseconds)

        assertTrue(runtime.resume() is RecordingCommandResult.Success)
        now = 21_000L
        assertEquals(3_000L, runtime.snapshot().elapsedMilliseconds)
    }

    @Test
    fun `stop persists the exact capture boundary before entering stopping`() {
        var now = 1_000L
        val machine = startedMachine()
        val runtime =
            RecordingSessionRuntime(
                machine = machine,
                timer = MonotonicRecordingTimer(elapsedRealtimeMillis = { now }),
                bytesWritten = { 4_096L },
                bookmarkJournal = RecordingBookmarkJournal(RuntimeBookmarkSink()),
                wallClockEpochMillis = { 90_000L },
            )
        runtime.captureStarted(captureBoundaryElapsedRealtimeMillis = 1_000L)
        now = 20_000L

        val result = runtime.stop(captureBoundaryElapsedRealtimeMillis = 2_500L)

        assertTrue(result is RecordingCommandResult.Success)
        assertEquals(NativeRecordingState.stopping, machine.snapshot().state)
        assertEquals(1_500L, machine.snapshot().elapsedMilliseconds)
        assertEquals(4_096L, machine.snapshot().bytesWritten)
    }

    @Test
    fun `bookmark persists current media and wall time only after progress succeeds`() {
        var now = 10_000L
        val sink = RuntimeBookmarkSink()
        val runtime =
            RecordingSessionRuntime(
                machine = startedMachine(),
                timer = MonotonicRecordingTimer(elapsedRealtimeMillis = { now }),
                bytesWritten = { 80L },
                bookmarkJournal = RecordingBookmarkJournal(sink),
                wallClockEpochMillis = { 90_000L },
            )
        runtime.captureStarted()
        now = 11_500L

        assertTrue(runtime.bookmark())
        assertEquals(
            RecordingBookmarkEvent(
                sessionId = "meeting-1",
                mediaElapsedMilliseconds = 1_500L,
                wallClockEpochMilliseconds = 90_000L,
            ),
            RecordingBookmarkFrame.decode(sink.lines.single()),
        )
    }

    @Test
    fun `bookmark is rejected while capture has not started`() {
        val sink = RuntimeBookmarkSink()
        val runtime =
            RecordingSessionRuntime(
                machine = startedMachine(),
                timer = MonotonicRecordingTimer(elapsedRealtimeMillis = { 0L }),
                bytesWritten = { 0L },
                bookmarkJournal = RecordingBookmarkJournal(sink),
                wallClockEpochMillis = { 1L },
            )

        assertFalse(runtime.bookmark())
        assertTrue(sink.lines.isEmpty())
    }

    @Test
    fun `interruption pauses media time and persists its wall clock event`() {
        var now = 10_000L
        val sink = RuntimeInterruptionSink()
        val runtime =
            RecordingSessionRuntime(
                machine = startedMachine(),
                timer = MonotonicRecordingTimer(elapsedRealtimeMillis = { now }),
                bytesWritten = { 640L },
                bookmarkJournal = RecordingBookmarkJournal(RuntimeBookmarkSink()),
                interruptionJournal = RecordingInterruptionJournal(sink),
                wallClockEpochMillis = { 90_000L },
            )
        runtime.captureStarted()
        now = 20_000L

        assertTrue(
            runtime.pauseForInterruption(captureBoundaryElapsedRealtimeMillis = 11_500L) is
                RecordingCommandResult.Success,
        )
        assertTrue(runtime.recordInterruption(RecordingInterruptionSource.call, RecordingInterruptionPhase.began))

        assertEquals(1_500L, runtime.snapshot().elapsedMilliseconds)
        assertEquals(
            RecordingInterruptionEvent(
                sessionId = "meeting-1",
                source = RecordingInterruptionSource.call,
                phase = RecordingInterruptionPhase.began,
                mediaElapsedMilliseconds = 1_500L,
                wallClockEpochMilliseconds = 90_000L,
            ),
            RecordingInterruptionFrame.decode(sink.lines.single()),
        )
    }

    @Test
    fun `progress failure after durable user pause makes session recoverable`() {
        var now = 1_000L
        val store = FailingRuntimeStateStore(failOnSave = 4)
        val machine =
            (PersistedRecordingStateMachine.create(store) as RecordingStateMachineInitialization.Success).machine
        machine.start("meeting-1")
        val runtime =
            RecordingSessionRuntime(
                machine = machine,
                timer = MonotonicRecordingTimer(elapsedRealtimeMillis = { now }),
                bytesWritten = { 640L },
                bookmarkJournal = RecordingBookmarkJournal(RuntimeBookmarkSink()),
                wallClockEpochMillis = { 90_000L },
            )
        runtime.captureStarted()
        now = 2_000L

        assertTrue(runtime.pause() is RecordingCommandResult.Failure)
        assertEquals(NativeRecordingState.recoverable, machine.snapshot().state)
    }

    @Test
    fun `progress failure after durable interruption pause makes session recoverable`() {
        val store = FailingRuntimeStateStore(failOnSave = 4)
        val interruptionSink = RuntimeInterruptionSink()
        val machine =
            (PersistedRecordingStateMachine.create(store) as RecordingStateMachineInitialization.Success).machine
        machine.start("meeting-1")
        val runtime =
            RecordingSessionRuntime(
                machine = machine,
                timer = MonotonicRecordingTimer(elapsedRealtimeMillis = { 2_000L }),
                bytesWritten = { 640L },
                bookmarkJournal = RecordingBookmarkJournal(RuntimeBookmarkSink()),
                interruptionJournal = RecordingInterruptionJournal(interruptionSink),
                wallClockEpochMillis = { 90_000L },
            )
        runtime.captureStarted(captureBoundaryElapsedRealtimeMillis = 1_000L)

        assertTrue(
            runtime.pauseForInterruption(captureBoundaryElapsedRealtimeMillis = 2_000L) is
                RecordingCommandResult.Failure,
        )
        assertEquals(NativeRecordingState.recoverable, machine.snapshot().state)
        assertTrue(runtime.recordInterruption(RecordingInterruptionSource.call, RecordingInterruptionPhase.began))
        assertEquals(
            RecordingInterruptionEvent(
                sessionId = "meeting-1",
                source = RecordingInterruptionSource.call,
                phase = RecordingInterruptionPhase.began,
                mediaElapsedMilliseconds = 1_000L,
                wallClockEpochMilliseconds = 90_000L,
            ),
            RecordingInterruptionFrame.decode(interruptionSink.lines.single()),
        )
    }

    private fun startedMachine(): PersistedRecordingStateMachine {
        val result = PersistedRecordingStateMachine.create(RuntimeStateStore())
        val machine = (result as RecordingStateMachineInitialization.Success).machine
        machine.start("meeting-1")
        return machine
    }
}

private class RuntimeStateStore : RecordingStateStore {
    override fun load(): RecordingStateLoadResult = RecordingStateLoadResult.Absent

    override fun save(snapshot: NativeRecordingSnapshot): Boolean = true
}

private class FailingRuntimeStateStore(
    private val failOnSave: Int,
) : RecordingStateStore {
    private var saveCount = 0

    override fun load(): RecordingStateLoadResult = RecordingStateLoadResult.Absent

    override fun save(snapshot: NativeRecordingSnapshot): Boolean {
        saveCount += 1
        return saveCount != failOnSave
    }
}

private class RuntimeBookmarkSink : RecordingBookmarkSink {
    val lines = mutableListOf<String>()

    override fun appendAndSync(line: String): Boolean {
        lines += line
        return true
    }
}

private class RuntimeInterruptionSink : RecordingInterruptionSink {
    val lines = mutableListOf<String>()

    override fun appendAndSync(line: String): Boolean {
        lines += line
        return true
    }
}
