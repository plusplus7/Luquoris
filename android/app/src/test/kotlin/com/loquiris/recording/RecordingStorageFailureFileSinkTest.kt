package com.loquiris.recording

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class RecordingStorageFailureFileSinkTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `atomic sink publishes one decodable durable terminal reason`() {
        val root = temporaryFolder.root
        val target = File(File(root, "events"), "meeting.storage-failure")
        val synced = mutableListOf<File>()
        val sink = AtomicRecordingStorageFailureFileSink(target) { synced += it; true }
        val event = failureEvent()

        assertTrue(sink.writeAndSync(RecordingStorageFailureFrame.encode(event)))
        assertEquals(event, RecordingStorageFailureFrame.decode(target.readText().trim()))
        assertEquals(listOf(root, target.parentFile), synced)
        assertFalse(File(target.parentFile, "${target.name}.tmp").exists())
    }

    @Test
    fun `atomic sink rejects malformed input without replacing an existing reason`() {
        val target = temporaryFolder.newFile("reason")
        target.writeText("existing")
        val sink = AtomicRecordingStorageFailureFileSink(target) { true }

        assertFalse(sink.writeAndSync("not-a-frame"))
        assertEquals("existing", target.readText())
    }

    private fun failureEvent() =
        RecordingStorageFailureEvent(
            sessionId = "meeting-1",
            code = "recording_storage_critically_low",
            availableBytes = 1L,
            requiredBytes = RecordingStoragePolicy.criticalThresholdBytes,
            mediaElapsedMilliseconds = 2L,
            wallClockEpochMilliseconds = 3L,
        )
}
