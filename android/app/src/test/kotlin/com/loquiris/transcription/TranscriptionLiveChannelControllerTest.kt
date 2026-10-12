package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame
import com.loquiris.recording.PcmInferenceConsumer
import java.util.concurrent.Executor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class TranscriptionLiveChannelControllerTest {
    @Test
    fun `stop invalidates a queued draft without allocating its model`() {
        val inference = LiveQueuedExecutor()
        val ui = LiveQueuedExecutor()
        var allocations = 0
        val controller = liveController(inference, ui, LivePcmInferenceRegistry()) { _, _ ->
            allocations += 1
            EmittingLiveDraftSession()
        }
        controller.handle("startDraft", liveArguments()) {}
        controller.handle("stopDraft", stopArguments()) {}
        inference.runAll()
        ui.runAll()
        assertEquals(0, allocations)
    }

    @Test
    fun `owner loss invalidates queued starts before model allocation`() {
        val inference = LiveQueuedExecutor()
        val ui = LiveQueuedExecutor()
        val replies = mutableListOf<Map<String, Any?>>()
        var allocations = 0
        val controller = liveController(inference, ui, LivePcmInferenceRegistry()) { _, _ ->
            allocations += 1
            EmittingLiveDraftSession()
        }
        controller.handle("startDraft", liveArguments(), replies::add)
        controller.closeLiveOwner()
        inference.runAll()
        ui.runAll()
        assertEquals(0, allocations)
        assertEquals(false, replies.single()["ok"])
    }

    @Test
    fun `owner loss discards draft events already queued to the reply executor`() {
        val inference = LiveQueuedExecutor()
        val ui = LiveQueuedExecutor()
        val events = mutableListOf<Map<String, Any?>>()
        val session = EmittingLiveDraftSession()
        val controller = liveController(inference, ui, LivePcmInferenceRegistry(), events::add) { _, emit ->
            session.emitter = emit
            session
        }
        controller.handle("startDraft", liveArguments()) {}
        inference.runAll()
        session.emitDraft()
        controller.closeLiveOwner()
        ui.runAll()
        assertTrue(events.isEmpty())
        inference.runAll()
    }

    @Test
    fun `start draft leaves caller thread attaches once and emits on reply executor`() {
        val inference = LiveQueuedExecutor()
        val ui = LiveQueuedExecutor()
        val registry = LivePcmInferenceRegistry()
        val attachments = mutableListOf<PcmInferenceConsumer?>()
        val replies = mutableListOf<Map<String, Any?>>()
        val events = mutableListOf<Map<String, Any?>>()
        val session = EmittingLiveDraftSession()
        var factoryCalls = 0
        registry.bindCapture("meeting-1", attachments::add)
        val controller =
            liveController(
                inference = inference,
                ui = ui,
                registry = registry,
                eventEmitter = events::add,
                factory = { _, emit ->
                    factoryCalls += 1
                    session.emitter = emit
                    session
                },
            )

        controller.handle("startDraft", liveArguments(), replies::add)
        controller.handle("startDraft", liveArguments(), replies::add)

        assertEquals(0, factoryCalls)
        assertTrue(replies.isEmpty())
        inference.runAll()
        assertEquals(1, factoryCalls)
        assertSame(session, attachments.last())
        assertTrue(replies.isEmpty())
        ui.runAll()
        assertEquals(2, replies.size)
        assertTrue(replies.all { it["ok"] == true && it["started"] == true })

        session.emitDraft()
        assertTrue(events.isEmpty())
        ui.runAll()
        assertEquals("draft", events.single()["type"])
    }

    @Test
    fun `stop draft and channel close are idempotent and detach inference`() {
        val inference = LiveQueuedExecutor()
        val ui = LiveQueuedExecutor()
        val registry = LivePcmInferenceRegistry()
        val attachments = mutableListOf<PcmInferenceConsumer?>()
        val stopped = EmittingLiveDraftSession()
        val ownerLost = EmittingLiveDraftSession()
        var nextSession: LiveDraftSession = stopped
        registry.bindCapture("meeting-1", attachments::add)
        val controller =
            liveController(
                inference = inference,
                ui = ui,
                registry = registry,
                factory = { _, _ -> nextSession },
            )

        controller.handle("startDraft", liveArguments()) {}
        inference.runAll()
        controller.handle("stopDraft", stopArguments()) {}
        controller.handle("stopDraft", stopArguments()) {}
        inference.runAll()
        assertEquals(1, stopped.closeCalls)
        assertNull(attachments.last())

        nextSession = ownerLost
        controller.handle("startDraft", liveArguments(runId = "draft-2")) {}
        inference.runAll()
        controller.closeLiveOwner()
        controller.closeLiveOwner()
        assertEquals(1, ownerLost.closeCalls)
        inference.runAll()
        assertEquals(listOf("transcription_live_channel_closed"), ownerLost.degradations)
        assertEquals(1, ownerLost.closeCalls)
        assertNull(attachments.last())
    }
}

private fun liveController(
    inference: LiveQueuedExecutor,
    ui: LiveQueuedExecutor,
    registry: LivePcmInferenceRegistry,
    eventEmitter: (Map<String, Any?>) -> Unit = {},
    factory: (LiveDraftRequest, (LiveDraftRuntimeEvent) -> Unit) -> LiveDraftSession,
) =
    TranscriptionChannelController(
        worker = TranscriptionChannelWorker { _, _, _ ->
            PostSessionTranscriptionResult.Completed("test", emptyList())
        },
        inferenceExecutor = inference,
        replyExecutor = ui,
        eventEmitter = eventEmitter,
        liveRegistry = registry,
        liveDraftFactory = factory,
    )

private fun liveArguments(runId: String = "draft-1"): Map<String, Any?> =
    mapOf(
        "v" to TranscriptionChannelContract.version,
        "runId" to runId,
        "meetingId" to "meeting-1",
        "modelId" to "whisper-base-q5_1",
        "languageHint" to "mixed",
        "parameterVersion" to 1,
    )

private fun stopArguments(): Map<String, Any?> =
    mapOf("v" to TranscriptionChannelContract.version, "runId" to "draft-1")

private class EmittingLiveDraftSession : LiveDraftSession {
    lateinit var emitter: (LiveDraftRuntimeEvent) -> Unit
    var closeCalls = 0
    val degradations = mutableListOf<String>()

    override fun start() = LiveDraftStartResult.Started

    override fun degrade(code: String) {
        degradations += code
    }

    override fun consume(frame: PcmCaptureFrame) = Unit

    override fun close() {
        closeCalls += 1
    }

    fun emitDraft() {
        emitter(
            LiveDraftUpdated(
                runId = "draft-1",
                segment = ReconciledDraftSegment("draft-0", 0, 20, " raw ", "raw", false),
                backlogMilliseconds = 20,
            ),
        )
    }
}

private class LiveQueuedExecutor : Executor {
    private val work = ArrayDeque<Runnable>()

    override fun execute(command: Runnable) {
        work += command
    }

    fun runAll() {
        while (work.isNotEmpty()) work.removeFirst().run()
    }
}
