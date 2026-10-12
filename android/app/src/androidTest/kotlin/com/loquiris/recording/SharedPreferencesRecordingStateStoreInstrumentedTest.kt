package com.loquiris.recording

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SharedPreferencesRecordingStateStoreInstrumentedTest {
    private val context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    @Before
    fun clearStore() {
        context.getSharedPreferences(PREFERENCES_NAME, 0).edit().clear().commit()
    }

    @Test
    fun snapshotSurvivesStoreReconstruction() {
        val first = SharedPreferencesRecordingStateStore(context, PREFERENCES_NAME)
        val expected =
            NativeRecordingSnapshot(
                sessionId = "meeting-1",
                state = NativeRecordingState.pausedByUser,
                elapsedMilliseconds = 12_345,
                bytesWritten = 67_890,
                revision = 9,
            )

        assertEquals(true, first.save(expected))

        val second = SharedPreferencesRecordingStateStore(context, PREFERENCES_NAME)
        assertEquals(expected, (second.load() as RecordingStateLoadResult.Loaded).snapshot)
    }

    @Test
    fun machineReconstructionPersistsRecoverableState() {
        val first = SharedPreferencesRecordingStateStore(context, PREFERENCES_NAME)
        first.save(
            NativeRecordingSnapshot(
                sessionId = "meeting-1",
                state = NativeRecordingState.recording,
                elapsedMilliseconds = 3_000,
                bytesWritten = 24_000,
                revision = 4,
            ),
        )

        val restored =
            (
                PersistedRecordingStateMachine.create(
                    SharedPreferencesRecordingStateStore(context, PREFERENCES_NAME),
                ) as RecordingStateMachineInitialization.Success
            ).machine

        assertEquals(NativeRecordingState.recoverable, restored.snapshot().state)
        assertEquals(
            NativeRecordingState.recoverable,
            (
                SharedPreferencesRecordingStateStore(context, PREFERENCES_NAME).load()
                    as RecordingStateLoadResult.Loaded
            ).snapshot.state,
        )
    }

    @Test
    fun malformedSnapshotIsReportedAsCorruptAndRetained() {
        context
            .getSharedPreferences(PREFERENCES_NAME, 0)
            .edit()
            .putString("authoritative_snapshot", "{not-json")
            .commit()

        val store = SharedPreferencesRecordingStateStore(context, PREFERENCES_NAME)

        assertEquals("recording_state_corrupt", (store.load() as RecordingStateLoadResult.Corrupt).code)
        assertEquals(
            "{not-json",
            context.getSharedPreferences(PREFERENCES_NAME, 0).getString("authoritative_snapshot", null),
        )
    }

    @Test
    fun incompatibleSnapshotsAreReportedAsCorruptAndRetained() {
        val incompatibleSnapshots =
            listOf(
                """{"schemaVersion":2,"sessionId":"meeting-1","state":"recording","elapsedMilliseconds":0,"bytesWritten":0,"revision":1}""",
                """{"schemaVersion":1,"sessionId":"meeting-1","state":"futureState","elapsedMilliseconds":0,"bytesWritten":0,"revision":1}""",
                """{"schemaVersion":1,"sessionId":" ","state":"recording","elapsedMilliseconds":0,"bytesWritten":0,"revision":1}""",
                """{"schemaVersion":1,"sessionId":"meeting-1","state":"recording","elapsedMilliseconds":-1,"bytesWritten":0,"revision":1}""",
                """{"schemaVersion":1,"sessionId":"meeting-1","state":"recording","elapsedMilliseconds":0,"bytesWritten":0,"revision":9223372036854775807}""",
            )

        incompatibleSnapshots.forEach { encoded ->
            context
                .getSharedPreferences(PREFERENCES_NAME, 0)
                .edit()
                .putString("authoritative_snapshot", encoded)
                .commit()

            val result = SharedPreferencesRecordingStateStore(context, PREFERENCES_NAME).load()

            assertEquals("recording_state_corrupt", (result as RecordingStateLoadResult.Corrupt).code)
            assertEquals(
                encoded,
                context.getSharedPreferences(PREFERENCES_NAME, 0).getString("authoritative_snapshot", null),
            )
        }
    }

    companion object {
        private const val PREFERENCES_NAME = "recording-state-test"
    }
}
