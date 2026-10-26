package com.loquiris.transcription

import com.loquiris.recording.*
import java.util.concurrent.CompletableFuture
import org.junit.Assert.*
import org.junit.Test

class LiveCaptureEndpointRegistryTest {
    @Test fun finalizedCleanupCannotRemoveFreshBindingInstalledBySessionClose() {
        val registry = LivePcmInferenceRegistry()
        val fresh = Endpoint()
        val draft = object : LegacyDraft() {
            override fun close() { super.close(); registry.bindCaptureEndpoint("meeting", fresh) }
        }
        registry.bindCaptureEndpoint("meeting", Endpoint())
        registry.start(request()) { draft }
        registry.recordingFinalized("meeting")
        assertSame(fresh, registry.captureEndpoint("meeting"))
        registry.closeOwner()
    }

    @Test fun endpointIsExactCaptureBindingAndLegacyRebindingInvalidatesIt() {
        val registry = LivePcmInferenceRegistry()
        val endpoint = Endpoint()
        registry.bindCaptureEndpoint("meeting", endpoint)
        assertSame(endpoint, registry.captureEndpoint("meeting"))
        val draft = Draft()
        assertEquals(LiveDraftStartResult.Started, registry.start(request()) { draft })
        assertSame(draft, endpoint.consumer)
        registry.bindCapture("meeting") { }
        assertNull(registry.captureEndpoint("meeting"))
        assertNull(endpoint.consumer)
        registry.closeOwner()
    }

    @Test fun stoppingRetainsCapableConsumerButBlocksNewStartsBeforeFactory() {
        val registry = LivePcmInferenceRegistry()
        val endpoint = Endpoint()
        val draft = Draft()
        registry.bindCaptureEndpoint("meeting", endpoint)
        registry.start(request()) { draft }
        registry.recordingStopping("meeting")
        assertSame(draft, endpoint.consumer)
        assertEquals(0, draft.closes)
        assertNull(registry.captureEndpoint("meeting"))
        assertEquals(LiveDraftStartResult.Failure("transcription_live_recording_stopped"),
            registry.start(request("late")) { error("stopped capture allocated model") })
        registry.recordingFinalized("meeting")
        assertSame(draft, endpoint.consumer)
        assertEquals(0, draft.closes)
        registry.stopDraft("run")
        assertEquals(1, draft.closes)
    }

    @Test fun stoppingLegacyDraftStillClosesImmediately() {
        val registry = LivePcmInferenceRegistry()
        val endpoint = Endpoint()
        val draft = LegacyDraft()
        registry.bindCaptureEndpoint("meeting", endpoint)
        registry.start(request()) { draft }
        registry.recordingStopping("meeting")
        assertEquals(1, draft.closes)
        assertNull(endpoint.consumer)
    }

    @Test fun stopDuringFactoryIsVisibleToPendingStarterAndCannotReattach() {
        val registry = LivePcmInferenceRegistry()
        val endpoint = Endpoint()
        val draft = Draft()
        registry.bindCaptureEndpoint("meeting", endpoint)
        val result = registry.start(request()) {
            assertNull(registry.pendingCancellationCode("run"))
            registry.recordingStopping("meeting")
            assertEquals("transcription_live_recording_stopped", registry.pendingCancellationCode("run"))
            draft
        }
        assertEquals(LiveDraftStartResult.Failure("transcription_live_recording_stopped"), result)
        assertNull(endpoint.consumer)
        assertEquals(1, draft.closes)
    }

    @Test fun failureUnbindRemovesEndpointAndClosesEvenCapableDraft() {
        val registry = LivePcmInferenceRegistry()
        val endpoint = Endpoint()
        val draft = Draft()
        registry.bindCaptureEndpoint("meeting", endpoint)
        registry.start(request()) { draft }
        registry.unbindCapture("meeting", "recording_failed")
        assertNull(registry.captureEndpoint("meeting"))
        assertNull(endpoint.consumer)
        assertEquals(listOf("recording_failed"), draft.degradations)
        assertEquals(1, draft.closes)
    }

    @Test fun freshBindingClearsStoppedFenceAndInactiveEndpointCannotAllocate() {
        val registry = LivePcmInferenceRegistry()
        registry.recordingStopping("meeting")
        val endpoint = Endpoint()
        registry.bindCaptureEndpoint("meeting", endpoint)
        assertSame(endpoint, registry.captureEndpoint("meeting"))
        endpoint.acceptsInference = false
        assertNull(registry.captureEndpoint("meeting"))
        registry.recordingStopping("meeting")
        registry.bindCaptureEndpoint("meeting", Endpoint())
        assertEquals(LiveDraftStartResult.Started, registry.start(request()) { Draft() })
        registry.closeOwner()
    }

    private fun request(run: String = "run") = LiveDraftRequest(run, "meeting", "probe", TranscriptionLanguageHint.mixed, 1)
    private class Endpoint : CaptureInferenceEndpoint {
        override var acceptsInference = true
        var consumer: PcmInferenceConsumer? = null
        override fun replaceInferenceConsumer(consumer: PcmInferenceConsumer?) { this.consumer = consumer }
        override fun finishInference(consumer: PcmInferenceConsumer, action: () -> Unit) =
            CompletableFuture.completedFuture(PcmInferenceBoundaryResult.detached)
        override fun inferenceBacklog() = PcmInferenceBacklog(emptyList(), 0, false)
    }
    private open class LegacyDraft : LiveDraftSession {
        var closes = 0
        val degradations = mutableListOf<String>()
        override fun start() = LiveDraftStartResult.Started
        override fun consume(frame: PcmCaptureFrame) = Unit
        override fun degrade(code: String) { degradations.add(code) }
        override fun close() { closes++ }
    }
    private class Draft : LegacyDraft(), PcmCaptureBoundaryConsumer {
        override fun onCaptureBoundary(boundary: PcmCaptureBoundary) = Unit
        override fun onBoundaryRejected(result: PcmInferenceBoundaryResult) = Unit
    }
}
