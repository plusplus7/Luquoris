package com.loquiris.recording

import com.loquiris.transcription.LiveDraftRequest
import com.loquiris.transcription.LiveDraftSession
import com.loquiris.transcription.LiveDraftStartResult
import com.loquiris.transcription.LivePcmInferenceRegistry
import com.loquiris.transcription.TranscriptionLanguageHint
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test

class RecordingLiveInferenceLifecycleTest {
    @Test
    fun `recording end detaches and releases inference exactly once`() {
        val registry = LivePcmInferenceRegistry()
        val lifecycle = RecordingLiveInferenceLifecycle(registry)
        val attachments = mutableListOf<PcmInferenceConsumer?>()
        val session = LifecycleDraftSession()
        registry.start(request("draft-1"), factory = { session })
        lifecycle.attach("meeting-1", attachments::add)

        lifecycle.recordingEnded("meeting-1")
        lifecycle.recordingEnded("meeting-1")

        assertNull(attachments.last())
        assertEquals(listOf("transcription_live_recording_stopped"), session.degradations)
        assertEquals(1, session.closeCalls)
    }

    @Test
    fun `severe thermal releases draft but leaves canonical capture binding available`() {
        val registry = LivePcmInferenceRegistry()
        val lifecycle = RecordingLiveInferenceLifecycle(registry)
        val attachments = mutableListOf<PcmInferenceConsumer?>()
        val thermalSession = LifecycleDraftSession()
        val restartedSession = LifecycleDraftSession()
        lifecycle.attach("meeting-1", attachments::add)
        registry.start(request("draft-1"), factory = { thermalSession })

        lifecycle.severeThermal("meeting-1")

        assertNull(attachments.last())
        assertEquals(listOf("transcription_live_thermal"), thermalSession.degradations)
        assertEquals(1, thermalSession.closeCalls)

        assertEquals(
            LiveDraftStartResult.Failure("transcription_live_thermal"),
            registry.start(request("draft-2"), factory = { restartedSession }),
        )
        assertNull(attachments.last())
        lifecycle.recordingEnded("meeting-1")
        lifecycle.attach("meeting-1", attachments::add)
        registry.start(request("draft-3"), factory = { restartedSession })
        assertSame(restartedSession, attachments.last())
    }
}

private fun request(runId: String) =
    LiveDraftRequest(
        runId = runId,
        meetingId = "meeting-1",
        modelId = "whisper-base-q5_1",
        languageHint = TranscriptionLanguageHint.mixed,
        parameterVersion = 1,
    )

private class LifecycleDraftSession : LiveDraftSession {
    val degradations = mutableListOf<String>()
    var closeCalls = 0

    override fun start() = LiveDraftStartResult.Started

    override fun degrade(code: String) {
        degradations += code
    }

    override fun consume(frame: PcmCaptureFrame) = Unit

    override fun close() {
        closeCalls += 1
    }
}
