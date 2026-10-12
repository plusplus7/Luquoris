package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame
import com.loquiris.recording.PcmInferenceConsumer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

class LivePcmInferenceRegistryTest {
    @Test
    fun `stop cannot be overtaken by a delayed attachment callback`() {
        val registry = LivePcmInferenceRegistry()
        val attached = AtomicReference<PcmInferenceConsumer?>()
        val entering = CountDownLatch(1)
        val release = CountDownLatch(1)
        val detached = CountDownLatch(1)
        val stopEntered = CountDownLatch(1)
        registry.bindCapture("meeting-1") { consumer ->
            if (consumer != null) {
                entering.countDown()
                check(release.await(2, TimeUnit.SECONDS))
            } else if (entering.count == 0L) {
                detached.countDown()
            }
            attached.set(consumer)
        }
        val workers = Executors.newFixedThreadPool(2)
        try {
            val start = workers.submit { registry.start(request()) { FakeLiveDraftSession() } }
            org.junit.Assert.assertTrue(entering.await(2, TimeUnit.SECONDS))
            val stop = workers.submit {
                stopEntered.countDown()
                registry.stopDraft("draft-1")
            }
            org.junit.Assert.assertTrue(stopEntered.await(2, TimeUnit.SECONDS))
            detached.await(100, TimeUnit.MILLISECONDS)
            release.countDown()
            start.get(2, TimeUnit.SECONDS)
            stop.get(2, TimeUnit.SECONDS)
            assertNull(attached.get())
        } finally {
            release.countDown()
            workers.shutdownNow()
        }
    }

    @Test
    fun `owner loss during model creation cannot resurrect a draft`() {
        assertStartInterrupted("transcription_live_channel_closed") { registry ->
            registry.closeOwner()
        }
    }

    @Test
    fun `recording stop during model creation cannot resurrect a draft`() {
        assertStartInterrupted("transcription_live_recording_stopped") { registry ->
            registry.unbindCapture("meeting-1", "transcription_live_recording_stopped")
        }
    }

    @Test
    fun `thermal degradation during model creation cannot resurrect a draft`() {
        assertStartInterrupted("transcription_live_thermal") { registry ->
            registry.degradeForThermal("meeting-1")
        }
    }

    @Test
    fun `explicit stop during model creation cannot resurrect a draft`() {
        assertStartInterrupted("transcription_live_closed") { registry ->
            registry.stopDraft("draft-1")
        }
    }

    private fun assertStartInterrupted(
        code: String,
        interrupt: (LivePcmInferenceRegistry) -> Unit,
    ) {
        val registry = LivePcmInferenceRegistry()
        val attachments = mutableListOf<PcmInferenceConsumer?>()
        val session = FakeLiveDraftSession()
        registry.bindCapture("meeting-1", attachments::add)

        val result = registry.start(request()) {
            interrupt(registry)
            session
        }

        assertEquals(LiveDraftStartResult.Failure(code), result)
        assertEquals(1, session.closeCalls)
        assertNull(attachments.last())
        registry.bindCapture("meeting-1", attachments::add)
        assertNull(attachments.last())
    }

    @Test
    fun `start and stop are idempotent and attach only to the matching capture`() {
        val registry = LivePcmInferenceRegistry()
        val attachments = mutableListOf<PcmInferenceConsumer?>()
        val session = FakeLiveDraftSession()
        var factories = 0
        registry.bindCapture("meeting-1", attachments::add)

        assertEquals(
            LiveDraftStartResult.Started,
            registry.start(request()) {
                factories += 1
                session
            },
        )
        assertEquals(LiveDraftStartResult.Started, registry.start(request()) { error("must not recreate") })

        assertEquals(1, factories)
        assertEquals(1, session.startCalls)
        assertSame(session, attachments.last())

        registry.stopDraft("draft-1")
        registry.stopDraft("draft-1")
        assertEquals(1, session.closeCalls)
        assertNull(attachments.last())
    }

    @Test
    fun `capture can arrive after draft start and thermal degradation never affects recording binding`() {
        val registry = LivePcmInferenceRegistry()
        val attachments = mutableListOf<PcmInferenceConsumer?>()
        val session = FakeLiveDraftSession()
        registry.start(request(), factory = { session })

        registry.bindCapture("meeting-1", attachments::add)
        assertSame(session, attachments.last())

        registry.degradeForThermal("meeting-1")

        assertEquals(listOf("transcription_live_thermal"), session.degradations)
        assertEquals(1, session.closeCalls)
        assertNull(attachments.last())
    }

    @Test
    fun `recording stop and channel owner loss release active sessions once`() {
        val stopped = FakeLiveDraftSession()
        val ownerLost = FakeLiveDraftSession()
        val registry = LivePcmInferenceRegistry()
        registry.bindCapture("meeting-1") {}
        registry.start(request(), factory = { stopped })

        registry.unbindCapture("meeting-1", "transcription_live_recording_stopped")
        assertEquals(listOf("transcription_live_recording_stopped"), stopped.degradations)
        assertEquals(1, stopped.closeCalls)

        registry.bindCapture("meeting-1") {}
        registry.start(request(runId = "draft-2"), factory = { ownerLost })
        registry.closeOwner()
        registry.closeOwner()
        assertEquals(listOf("transcription_live_channel_closed"), ownerLost.degradations)
        assertEquals(1, ownerLost.closeCalls)
    }

    @Test
    fun `failed model start never attaches inference consumer`() {
        val registry = LivePcmInferenceRegistry()
        val attachments = mutableListOf<PcmInferenceConsumer?>()
        val session = FakeLiveDraftSession(LiveDraftStartResult.Failure("transcription_model_hash_mismatch"))
        registry.bindCapture("meeting-1", attachments::add)

        assertEquals(
            LiveDraftStartResult.Failure("transcription_model_hash_mismatch"),
            registry.start(request(), factory = { session }),
        )

        assertEquals(1, session.closeCalls)
        assertNull(attachments.lastOrNull())
    }
}

private fun request(runId: String = "draft-1") =
    LiveDraftRequest(
        runId = runId,
        meetingId = "meeting-1",
        modelId = "whisper-base-q5_1",
        languageHint = TranscriptionLanguageHint.mixed,
        parameterVersion = 1,
    )

private class FakeLiveDraftSession(
    private val startResult: LiveDraftStartResult = LiveDraftStartResult.Started,
) : LiveDraftSession {
    var startCalls = 0
    var closeCalls = 0
    val degradations = mutableListOf<String>()

    override fun start(): LiveDraftStartResult {
        startCalls += 1
        return startResult
    }

    override fun degrade(code: String) {
        degradations += code
    }

    override fun consume(frame: PcmCaptureFrame) = Unit

    override fun close() {
        closeCalls += 1
    }
}
