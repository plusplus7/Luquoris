package com.loquiris.transcription

import java.util.concurrent.Executor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TranscriptionChannelControllerTest {
    @Test
    fun `inference leaves the caller executor and replies only on the UI executor`() {
        val inference = QueuedExecutor()
        val ui = QueuedExecutor()
        val workerCalls = mutableListOf<String>()
        val replies = mutableListOf<Map<String, Any?>>()
        val controller =
            controller(
                inference = inference,
                ui = ui,
                worker = { request, _, _ ->
                    workerCalls += request.runId
                    completed()
                },
            )

        controller.handle("transcribe", validArguments(), replies::add)

        assertTrue(workerCalls.isEmpty())
        assertTrue(replies.isEmpty())
        inference.runNext()
        assertEquals(listOf("run-1"), workerCalls)
        assertTrue(replies.isEmpty())
        ui.runAll()
        assertEquals("run-1", replies.single()["runId"])
        assertTrue(replies.single()["ok"] == true)
    }

    @Test
    fun `progress is monotonic and precedes exactly one terminal reply`() {
        val inference = QueuedExecutor()
        val ui = QueuedExecutor()
        val order = mutableListOf<String>()
        val controller =
            controller(
                inference = inference,
                ui = ui,
                eventEmitter = { event ->
                    order += "progress:${event["fraction"]}"
                },
                worker = { _, _, progress ->
                    listOf(0.5, 0.25, 0.8, 1.4).forEach(progress)
                    completed()
                },
            )

        controller.handle("transcribe", validArguments()) { order += "terminal:${it["ok"]}" }
        inference.runNext()
        ui.runAll()

        assertEquals(
            listOf("progress:0.5", "progress:0.8", "progress:1.0", "terminal:true"),
            order,
        )
        assertEquals(1, order.count { it.startsWith("terminal:") })
    }

    @Test
    fun `cancellation is idempotent and reaches the registered run`() {
        val inference = QueuedExecutor()
        val ui = QueuedExecutor()
        val cancellationStates = mutableListOf<Boolean>()
        val transcribeReplies = mutableListOf<Map<String, Any?>>()
        val cancelReplies = mutableListOf<Map<String, Any?>>()
        val controller =
            controller(
                inference = inference,
                ui = ui,
                worker = { _, cancellation, _ ->
                    cancellationStates += cancellation.isCancelled()
                    PostSessionTranscriptionResult.Cancelled
                },
            )
        controller.handle("transcribe", validArguments(), transcribeReplies::add)

        controller.handle("cancel", cancelArguments(), cancelReplies::add)
        controller.handle("cancel", cancelArguments(), cancelReplies::add)
        inference.runNext()
        ui.runAll()

        assertEquals(listOf(true), cancellationStates)
        assertEquals(2, cancelReplies.size)
        assertTrue(cancelReplies.all { it["ok"] == true && it["cancelled"] == true })
        assertEquals(
            "transcription_cancelled",
            ((transcribeReplies.single()["failure"] as Map<*, *>)["code"]),
        )
    }

    @Test
    fun `close cancels active work clears registry and rejects new runs`() {
        val inference = QueuedExecutor()
        val ui = QueuedExecutor()
        val observedCancelled = mutableListOf<Boolean>()
        val firstReplies = mutableListOf<Map<String, Any?>>()
        val rejectedReplies = mutableListOf<Map<String, Any?>>()
        val controller =
            controller(
                inference = inference,
                ui = ui,
                worker = { _, cancellation, _ ->
                    observedCancelled += cancellation.isCancelled()
                    PostSessionTranscriptionResult.Cancelled
                },
            )
        controller.handle("transcribe", validArguments(), firstReplies::add)

        controller.close()
        controller.handle(
            "transcribe",
            validArguments() + ("runId" to "run-2"),
            rejectedReplies::add,
        )
        inference.runNext()
        ui.runAll()

        assertEquals(listOf(true), observedCancelled)
        assertEquals(0, controller.activeRunCount)
        assertEquals(
            "transcription_channel_closed",
            ((rejectedReplies.single()["failure"] as Map<*, *>)["code"]),
        )
        assertEquals(1, firstReplies.size)
    }

    @Test
    fun `validation failures also reply through the UI executor`() {
        val inference = QueuedExecutor()
        val ui = QueuedExecutor()
        val replies = mutableListOf<Map<String, Any?>>()
        val controller = controller(inference = inference, ui = ui)

        controller.handle("transcribe", validArguments() + ("v" to 99), replies::add)

        assertTrue(replies.isEmpty())
        assertTrue(inference.isEmpty)
        ui.runAll()
        assertFalse(replies.single()["ok"] as Boolean)
        assertEquals(
            "transcription_channel_version_unsupported",
            ((replies.single()["failure"] as Map<*, *>)["code"]),
        )
    }

    @Test
    fun `terminal failure excludes unsafe worker exception text`() {
        val inference = QueuedExecutor()
        val ui = QueuedExecutor()
        val replies = mutableListOf<Map<String, Any?>>()
        val controller =
            controller(
                inference = inference,
                ui = ui,
                worker = { _, _, _ ->
                    PostSessionTranscriptionResult.Failure(
                        "/data/user/0/com.loquiris/files/recordings/private",
                    )
                },
            )

        controller.handle("transcribe", validArguments(), replies::add)
        inference.runNext()
        ui.runAll()

        assertEquals(
            "transcription_native_failed",
            ((replies.single()["failure"] as Map<*, *>)["code"]),
        )
        assertFalse(replies.single().toString().contains("/data/user/0"))
    }
}

private fun controller(
    inference: QueuedExecutor,
    ui: QueuedExecutor,
    eventEmitter: (Map<String, Any?>) -> Unit = {},
    worker: TranscriptionChannelWorker =
        TranscriptionChannelWorker { _, _, _ -> completed() },
) =
    TranscriptionChannelController(
        worker = worker,
        inferenceExecutor = inference,
        replyExecutor = ui,
        eventEmitter = eventEmitter,
    )

private fun completed() =
    PostSessionTranscriptionResult.Completed(
        engineVersion = "1.9.4",
        segments = emptyList(),
    )

private fun validArguments(): Map<String, Any?> =
    mapOf(
        "v" to TranscriptionChannelContract.version,
        "runId" to "run-1",
        "meetingId" to "meeting-1",
        "segmentReferences" to listOf("recordings/storage-key/segment-00000.adts"),
        "modelId" to TranscriptionChannelContract.supportedModelId,
        "languageHint" to "mixed",
        "parameterVersion" to 1,
    )

private fun cancelArguments(): Map<String, Any?> =
    mapOf("v" to TranscriptionChannelContract.version, "runId" to "run-1")

private class QueuedExecutor : Executor {
    private val work = ArrayDeque<Runnable>()

    val isEmpty: Boolean
        get() = work.isEmpty()

    override fun execute(command: Runnable) {
        work += command
    }

    fun runNext() {
        work.removeFirst().run()
    }

    fun runAll() {
        while (work.isNotEmpty()) runNext()
    }
}
