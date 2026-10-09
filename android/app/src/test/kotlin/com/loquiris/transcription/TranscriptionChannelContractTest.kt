package com.loquiris.transcription

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TranscriptionChannelContractTest {
    @Test
    fun `transcribe request requires the complete versioned typed contract`() {
        val parsed = TranscriptionChannelContract.parseTranscribe(validArguments())

        val request = (parsed as TranscriptionChannelParseResult.Ready).request
        assertEquals("run-1", request.runId)
        assertEquals("meeting-1", request.meetingId)
        assertEquals(listOf("recordings/storage-key/segment-00000.adts"), request.segmentReferences)
        assertEquals("whisper-base-q5_1", request.modelId)
        assertEquals(TranscriptionLanguageHint.mixed, request.languageHint)
        assertEquals(1, request.parameterVersion)
    }

    @Test
    fun `request rejects unsupported versions and imprecise field types`() {
        val wrongVersion =
            TranscriptionChannelContract.parseTranscribe(validArguments() + ("v" to 2))
        val longParameter =
            TranscriptionChannelContract.parseTranscribe(
                validArguments() + ("parameterVersion" to 1L),
            )
        val unknownField =
            TranscriptionChannelContract.parseTranscribe(validArguments() + ("extra" to true))

        assertEquals(
            "transcription_channel_version_unsupported",
            (wrongVersion as TranscriptionChannelParseResult.Failure).code,
        )
        assertEquals(
            "transcription_request_invalid",
            (longParameter as TranscriptionChannelParseResult.Failure).code,
        )
        assertEquals(
            "transcription_request_invalid",
            (unknownField as TranscriptionChannelParseResult.Failure).code,
        )
    }

    @Test
    fun `request rejects absolute traversing and backslash segment references`() {
        val invalidReferences =
            listOf(
                "/data/user/0/private.adts",
                "../private.adts",
                "recordings/key/../private.adts",
                "recordings\\key\\segment-00000.adts",
            )

        invalidReferences.forEach { reference ->
            val parsed =
                TranscriptionChannelContract.parseTranscribe(
                    validArguments() + ("segmentReferences" to listOf(reference)),
                )
            assertEquals(
                reference,
                "transcription_request_invalid",
                (parsed as TranscriptionChannelParseResult.Failure).code,
            )
        }
    }

    @Test
    fun `completed result contains stable chunks and no native file path`() {
        val encoded =
            TranscriptionChannelContract.completed(
                runId = "run-1",
                result =
                    PostSessionTranscriptionResult.Completed(
                        engineVersion = "1.9.4",
                        segments =
                            listOf(
                                TranscriptionSegment(
                                    id = "segment-000000",
                                    startMilliseconds = 10,
                                    endMilliseconds = 20,
                                    rawText = " raw ",
                                    displayText = "raw",
                                ),
                            ),
                        warningCode = "transcription_audio_uncommitted_tail",
                    ),
            )

        val result = encoded["result"] as Map<*, *>
        val chunk = (result["chunks"] as List<*>).single() as Map<*, *>
        assertEquals("stable", chunk["stability"])
        assertEquals(" raw ", chunk["rawText"])
        assertEquals("raw", chunk["displayText"])
        assertFalse(encoded.toString().contains("/data/"))
        assertTrue(encoded["ok"] == true)
    }
}

private fun validArguments(): Map<String, Any?> =
    mapOf(
        "v" to TranscriptionChannelContract.version,
        "runId" to "run-1",
        "meetingId" to "meeting-1",
        "segmentReferences" to listOf("recordings/storage-key/segment-00000.adts"),
        "modelId" to "whisper-base-q5_1",
        "languageHint" to "mixed",
        "parameterVersion" to 1,
    )
