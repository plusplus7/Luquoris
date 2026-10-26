package com.loquiris.transcription

import com.loquiris.recording.RecordingProcessLiveness
import java.io.File
import java.util.concurrent.Executor
import java.util.concurrent.RejectedExecutionException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RefinementAudioChannelControllerTest {
    @Test
    fun `inspection runs on worker then replies on reply executor with no paths`() {
        val worker = InventoryTestExecutor()
        val replies = InventoryTestExecutor()
        var result: Any? = null
        val controller = RefinementAudioChannelController(worker, replies) { _, _ -> ready() }
        controller.handle("inspect", mapOf("v" to 1, "meetingId" to "meeting")) { result = it }
        assertEquals(null, result)
        assertEquals(1, worker.pending.size)
        worker.runNext()
        assertEquals(null, result)
        replies.runNext()
        assertEquals(mapOf(
            "v" to 1, "ok" to true, "meetingId" to "meeting",
            "inventory" to mapOf("sha256" to "a".repeat(64), "totalSamples" to 1_024L,
                "sampleRateHz" to 16_000, "segmentCount" to 1,
                "segments" to listOf(mapOf("index" to 0, "startSample" to 0L, "committedSamples" to 1_024L,
                    "committedBytes" to 11L, "sha256" to "b".repeat(64), "referenceSha256" to "c".repeat(64)))),
        ), result)
    }

    @Test
    fun `invalid contracts never reach disk inspection`() {
        val direct = Executor { it.run() }
        val controller = RefinementAudioChannelController(direct, direct) { _, _ -> error("unexpected disk access") }
        for (args in listOf(null, mapOf("v" to 2), mapOf("v" to 1, "meetingId" to "../meeting"),
            mapOf("v" to 1, "meetingId" to "meeting", "expectedSha256" to "bad"))) {
            var response: Any? = null
            controller.handle("inspect", args) { response = it }
            assertEquals(false, (response as Map<*, *>)["ok"])
        }
        var unsupported: Any? = null
        controller.handle("delete", mapOf("v" to 1, "meetingId" to "meeting")) { unsupported = it }
        assertEquals(false, (unsupported as Map<*, *>)["ok"])
    }

    @Test
    fun `deferred and unavailable inspections remain distinct and content free`() {
        val direct = Executor { it.run() }
        for ((outcome, kind) in listOf(
            RefinementAudioInventoryResult.Deferred("refinement_recording_active") to "deferred",
            RefinementAudioInventoryResult.Cancelled to "cancelled",
            RefinementAudioInventoryResult.Failure("transcription_audio_missing") to "unavailable",
        )) {
            var result: Any? = null
            RefinementAudioChannelController(direct, direct) { _, _ -> outcome }
                .handle("inspect", mapOf("v" to 1, "meetingId" to "meeting")) { result = it }
            val failure = (result as Map<*, *>)["failure"] as Map<*, *>
            assertEquals(kind, failure["kind"])
        }
    }

    @Test
    fun `process recording gate covers provisional and retained owner until matching release`() {
        RecordingProcessLiveness.claim("meeting")
        try {
            assertTrue(RecordingProcessLiveness.hasActiveSession())
            RecordingProcessLiveness.release("another")
            assertTrue(RecordingProcessLiveness.hasActiveSession())
        } finally {
            RecordingProcessLiveness.release("meeting")
        }
        assertFalse(RecordingProcessLiveness.hasActiveSession())
    }

    private fun ready() = RefinementAudioInventoryResult.Ready(
        AuthoritativeAudioResolution.Ready(
            listOf(AuthoritativeAudioSegment(0, File("private/original.adts"), 11, 0, 1_024, "b".repeat(64))),
            1_024, 16_000, listOf(byteArrayOf(0x14, 0x08)),
        ), "a".repeat(64), listOf("c".repeat(64)),
    )

    @Test
    fun `worker exception and closed executor return sanitized unavailability`() {
        val direct = Executor { it.run() }
        val unavailable = mapOf(
            "v" to 1, "ok" to false, "meetingId" to "meeting",
            "failure" to mapOf("kind" to "unavailable", "code" to "refinement_audio_unavailable"),
        )
        val closed = Executor { throw RejectedExecutionException("private/path") }
        for (executor in listOf(direct, closed)) {
            var response: Any? = null
            RefinementAudioChannelController(executor, direct) { _, _ -> throw IllegalStateException("private/audio") }
                .handle("inspect", mapOf("v" to 1, "meetingId" to "meeting")) { response = it }
            assertEquals(unavailable, response)
        }
    }
}

private class InventoryTestExecutor : Executor {
    val pending = ArrayDeque<Runnable>()
    override fun execute(command: Runnable) { pending.addLast(command) }
    fun runNext() { pending.removeFirst().run() }
}
