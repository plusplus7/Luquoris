package com.loquiris.transcription

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TranscriptionLiveChannelContractTest {
    @Test
    fun `live draft request uses a complete versioned contract`() {
        val parsed = TranscriptionChannelContract.parseStartDraft(validLiveArguments())

        val request = (parsed as LiveDraftChannelParseResult.Ready).request
        assertEquals("draft-1", request.runId)
        assertEquals("meeting-1", request.meetingId)
        assertEquals("whisper-base-q5_1", request.modelId)
        assertEquals(TranscriptionLanguageHint.mixed, request.languageHint)
        assertEquals(1, request.parameterVersion)
    }

    @Test
    fun `live draft request rejects unknown fields and imprecise values`() {
        val unknown =
            TranscriptionChannelContract.parseStartDraft(validLiveArguments() + ("extra" to true))
        val imprecise =
            TranscriptionChannelContract.parseStartDraft(
                validLiveArguments() + ("parameterVersion" to 1L),
            )

        assertEquals(
            "transcription_request_invalid",
            (unknown as LiveDraftChannelParseResult.Failure).code,
        )
        assertEquals(
            "transcription_request_invalid",
            (imprecise as LiveDraftChannelParseResult.Failure).code,
        )
    }

    @Test
    fun `live draft events preserve text stability backlog and degradation state`() {
        val updated =
            TranscriptionChannelContract.liveEvent(
                LiveDraftUpdated(
                    runId = "draft-1",
                    segment =
                        ReconciledDraftSegment(
                            id = "draft-0-800-0",
                            startMilliseconds = 0,
                            endMilliseconds = 800,
                            rawText = " raw text ",
                            displayText = "raw text",
                            stable = false,
                        ),
                    backlogMilliseconds = 120,
                ),
            )
        val degraded =
            TranscriptionChannelContract.liveEvent(
                LiveDraftDegraded(
                    runId = "draft-1",
                    code = "transcription_live_backlog",
                    backlogMilliseconds = 240,
                    incomplete = true,
                ),
            )

        val chunk = updated["chunk"] as Map<*, *>
        assertEquals("draft", updated["type"])
        assertEquals("unstable", chunk["stability"])
        assertEquals(" raw text ", chunk["rawText"])
        assertEquals(120L, updated["backlogMilliseconds"])
        assertEquals("draftDegraded", degraded["type"])
        assertEquals("transcription_live_backlog", degraded["reason"])
        assertTrue(degraded["incomplete"] == true)
        assertFalse(updated.toString().contains("/data/"))
    }
}

private fun validLiveArguments(): Map<String, Any?> =
    mapOf(
        "v" to TranscriptionChannelContract.version,
        "runId" to "draft-1",
        "meetingId" to "meeting-1",
        "modelId" to "whisper-base-q5_1",
        "languageHint" to "mixed",
        "parameterVersion" to 1,
    )
