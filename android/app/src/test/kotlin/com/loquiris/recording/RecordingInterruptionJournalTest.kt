package com.loquiris.recording

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class RecordingInterruptionJournalTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `frame round trips without exposing raw session id`() {
        val event = event(RecordingInterruptionSource.call, RecordingInterruptionPhase.confirmationRequired)

        val frame = RecordingInterruptionFrame.encode(event)

        assertFalse(frame.contains(event.sessionId))
        assertEquals(event, RecordingInterruptionFrame.decode(frame))
    }

    @Test
    fun `recoverable sink truncates torn suffix before appending`() {
        val file = File(temporaryFolder.newFolder("events"), "meeting.interruptions")
        val first = event(RecordingInterruptionSource.audioFocus, RecordingInterruptionPhase.began)
        file.writeText("${RecordingInterruptionFrame.encode(first)}\nv1\t99\ttorn")
        val second = event(RecordingInterruptionSource.audioFocus, RecordingInterruptionPhase.ended)
        val journal =
            RecordingInterruptionJournal(
                RecoverableInterruptionFileSink(file, directorySync = { true }),
            )

        assertTrue(journal.append(second))
        assertEquals(
            listOf(first, second),
            file.readLines().map { requireNotNull(RecordingInterruptionFrame.decode(it)) },
        )
    }

    private fun event(
        source: RecordingInterruptionSource,
        phase: RecordingInterruptionPhase,
    ) = RecordingInterruptionEvent(
        sessionId = "sensitive meeting id",
        source = source,
        phase = phase,
        mediaElapsedMilliseconds = 1_500,
        wallClockEpochMilliseconds = 50_000,
    )
}
