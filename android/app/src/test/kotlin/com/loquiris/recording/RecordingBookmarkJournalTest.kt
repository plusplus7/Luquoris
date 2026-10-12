package com.loquiris.recording

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class RecordingBookmarkJournalTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `bookmark is one versioned append with media and wall time`() {
        val sink = FakeBookmarkSink()
        val journal = RecordingBookmarkJournal(sink)

        val saved =
            journal.append(
                RecordingBookmarkEvent(
                    sessionId = "meeting/one",
                    mediaElapsedMilliseconds = 12_345L,
                    wallClockEpochMilliseconds = 98_765L,
                ),
            )

        assertTrue(saved)
        assertEquals(1, sink.lines.size)
        assertEquals(
            RecordingBookmarkEvent(
                sessionId = "meeting/one",
                mediaElapsedMilliseconds = 12_345L,
                wallClockEpochMilliseconds = 98_765L,
            ),
            RecordingBookmarkFrame.decode(sink.lines.single()),
        )
    }

    @Test
    fun `sink failure is returned and never acknowledged`() {
        val journal = RecordingBookmarkJournal(FakeBookmarkSink(shouldSucceed = false))

        assertFalse(
            journal.append(
                RecordingBookmarkEvent(
                    sessionId = "meeting-1",
                    mediaElapsedMilliseconds = 0,
                    wallClockEpochMilliseconds = 1,
                ),
            ),
        )
    }

    @Test
    fun `torn tail is truncated before append and remains recoverable after reopen`() {
        val journalFile = temporaryFolder.newFolder("events").resolve("meeting.bookmarks")
        val first =
            RecordingBookmarkEvent(
                sessionId = "meeting-1",
                mediaElapsedMilliseconds = 1_000L,
                wallClockEpochMilliseconds = 10_000L,
            )
        journalFile.writeText("${RecordingBookmarkFrame.encode(first)}\nv1\t99\ttorn")
        val second = first.copy(mediaElapsedMilliseconds = 2_000L, wallClockEpochMilliseconds = 11_000L)

        assertTrue(
            RecordingBookmarkJournal(
                RecoverableBookmarkFileSink(journalFile, directorySync = { true }),
            ).append(second),
        )
        assertEquals(listOf(first, second), decodedEvents(journalFile))

        val third = first.copy(mediaElapsedMilliseconds = 3_000L, wallClockEpochMilliseconds = 12_000L)
        assertTrue(
            RecordingBookmarkJournal(
                RecoverableBookmarkFileSink(journalFile, directorySync = { true }),
            ).append(third),
        )
        assertEquals(listOf(first, second, third), decodedEvents(journalFile))
    }

    @Test
    fun `retry after parent sync failure republishes directories without duplicating frame`() {
        val eventsDirectory = temporaryFolder.root.resolve("files/recording-events")
        val journalFile = eventsDirectory.resolve("meeting.bookmarks")
        val event =
            RecordingBookmarkEvent(
                sessionId = "meeting-1",
                mediaElapsedMilliseconds = 1_000L,
                wallClockEpochMilliseconds = 10_000L,
            )
        var firstSync = true
        val firstAttempt =
            RecordingBookmarkJournal(
                RecoverableBookmarkFileSink(
                    journalFile,
                    directorySync = {
                        if (firstSync) {
                            firstSync = false
                            false
                        } else {
                            true
                        }
                    },
                ),
            )
        assertFalse(firstAttempt.append(event))

        val syncedDirectories = mutableListOf<java.io.File>()
        val retry =
            RecordingBookmarkJournal(
                RecoverableBookmarkFileSink(
                    journalFile,
                    directorySync = { directory ->
                        syncedDirectories += directory
                        true
                    },
                ),
            )

        assertTrue(retry.append(event))
        assertEquals(listOf(event), decodedEvents(journalFile))
        assertEquals(
            listOf(requireNotNull(eventsDirectory.parentFile), eventsDirectory),
            syncedDirectories,
        )
    }

    private fun decodedEvents(file: java.io.File): List<RecordingBookmarkEvent> =
        file.readLines().map { line ->
            requireNotNull(RecordingBookmarkFrame.decode(line))
        }
}

private class FakeBookmarkSink(
    private val shouldSucceed: Boolean = true,
) : RecordingBookmarkSink {
    val lines = mutableListOf<String>()

    override fun appendAndSync(line: String): Boolean {
        if (!shouldSucceed) return false
        lines += line
        return true
    }
}
