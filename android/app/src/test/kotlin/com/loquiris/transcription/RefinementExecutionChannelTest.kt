package com.loquiris.transcription

import java.util.concurrent.Executor
import org.junit.Assert.*
import org.junit.Test

class RefinementExecutionChannelTest {
    @Test fun ioFailureRepliesAndReleasesOwnerForNextRequest() {
        val queue = mutableListOf<Runnable>()
        val replies = mutableListOf<Map<String, Any?>>()
        var calls = 0
        val controller = RefinementExecutionChannelController(
            RefinementExecutionChannelContract(false), Executor { queue += it }, Executor { it.run() },
            { _, _ ->
                calls++
                if (calls == 1) throw java.io.IOException("SECRET /private/audio")
                RefinementExecutionResult.Cancelled
            },
        )
        controller.handle("transcribe", payload(), replies::add)
        // Executor implementations may log escaping failures; this test checks
        // the controller's required reply and ownership release, not that log.
        try { queue.removeAt(0).run() } catch (_: java.io.IOException) { }
        assertEquals(1, replies.size)
        assertEquals("refinement_execution_failed", (replies.single()["failure"] as Map<*, *>)["code"])
        assertFalse(replies.toString().contains("SECRET"))
        controller.handle("transcribe", payload(run = "next"), replies::add)
        assertEquals(1, queue.size)
        queue.removeAt(0).run()
        assertEquals(2, calls)
    }

    @Test fun frozenProfileIsValidatedBeforeAnyWorkerAllocation() {
        val contract = RefinementExecutionChannelContract(false)
        val request = payload()
        assertEquals("whisper-base-q5_1", contract.parse(request)?.execution?.model?.id)
        assertNull(contract.parse(request + ("engineVersion" to "other")))
        assertNull(contract.parse(request + ("unexpected" to "ignored")))
        val manifest = request["manifest"] as Map<*, *>
        for (key in listOf("source", "artifactPath", "sha256", "bytes", "version", "license", "runtime", "enabledModes")) {
            assertNull(key, contract.parse(request + ("manifest" to manifest + (key to "modified"))))
        }
        val parameters = request["parameters"] as Map<*, *>
        assertNull(contract.parse(request + ("parameters" to parameters + ("translate" to true))))
        assertNull(contract.parse(request + ("parameters" to parameters + ("parameterVersion" to 1.0))))
        assertNull(contract.parse(request + ("parameters" to parameters + ("executionMode" to "recordingOnly"))))
        assertNull(contract.parse(request + ("manifest" to manifest + ("schemaVersion" to 2))))
    }

    @Test fun experimentalSmallNeedsExplicitNativeDevelopmentGate() {
        val small = payload(small = true)
        assertNull(RefinementExecutionChannelContract(false).parse(small))
        assertEquals("whisper-small-q5_1", RefinementExecutionChannelContract(true).parse(small)?.execution?.model?.id)
    }

    @Test fun workerIsOffCallerThreadAndCancellationIsOutOfBandAndOwnerScoped() {
        val queue = mutableListOf<Runnable>()
        val replies = mutableListOf<Map<String, Any?>>()
        var calls = 0
        val controller = RefinementExecutionChannelController(
            contract = RefinementExecutionChannelContract(false),
            executor = Executor { queue += it }, replyExecutor = Executor { it.run() },
            worker = { _, cancellation ->
                calls++
                assertTrue(cancellation.isCancelled())
                RefinementExecutionResult.Cancelled
            },
        )
        controller.handle("transcribe", payload(), replies::add)
        assertEquals(0, calls)
        controller.handle("transcribe", payload(run = "other"), replies::add)
        assertEquals("deferred", (replies.last()["failure"] as Map<*, *>)["kind"])
        controller.handle("cancel", owner(run = "wrong"), replies::add)
        assertEquals(false, replies.last()["ok"])
        controller.handle("cancel", owner(), replies::add)
        assertEquals(true, replies.last()["ok"])
        queue.single().run()
        assertEquals(1, calls)
        assertEquals("cancelled", (replies.last()["failure"] as Map<*, *>)["kind"])
        assertEquals("run", replies.last()["runId"])
        assertEquals("meeting", replies.last()["meetingId"])
    }

    @Test fun completedRawOutputRemainsSeparateAndExceptionsAreContentFree() {
        val output = PostSessionTranscriptionResult.Completed("1.9.4", listOf(
            TranscriptionSegment("segment", 0, 64, " 原文 API ", " 原文 API "),
        ))
        val replies = mutableListOf<Map<String, Any?>>()
        var fail = false
        val controller = RefinementExecutionChannelController(
            RefinementExecutionChannelContract(false), Executor { it.run() }, Executor { it.run() },
            { _, _ -> if (fail) error("SECRET /audio/private") else RefinementExecutionResult.Completed(output) },
        )
        controller.handle("transcribe", payload(), replies::add)
        val segments = replies.last()["segments"] as List<*>
        assertEquals(" 原文 API ", (segments.single() as Map<*, *>)["rawText"])
        fail = true
        controller.handle("transcribe", payload(), replies::add)
        assertFalse(replies.last().toString().contains("SECRET"))
        assertEquals("refinement_execution_failed", (replies.last()["failure"] as Map<*, *>)["code"])
        controller.close()
        controller.handle("transcribe", payload(), replies::add)
        assertEquals("refinement_execution_closed", (replies.last()["failure"] as Map<*, *>)["code"])
    }

    @Test fun closeLatchesCancellationBeforeQueuedWorkerStarts() {
        val queue = mutableListOf<Runnable>()
        val replies = mutableListOf<Map<String, Any?>>()
        val controller = RefinementExecutionChannelController(
            RefinementExecutionChannelContract(false), Executor { queue += it }, Executor { it.run() },
            { _, token -> assertTrue(token.isCancelled()); RefinementExecutionResult.Cancelled },
        )
        controller.handle("transcribe", payload(), replies::add)
        controller.close()
        queue.single().run()
        assertEquals("cancelled", (replies.single()["failure"] as Map<*, *>)["kind"])
    }

    private fun owner(run: String = "run") = mapOf<String, Any?>("v" to 1, "meetingId" to "meeting", "runId" to run)

    private fun payload(run: String = "run", small: Boolean = false): Map<String, Any?> {
        val name = if (small) "small" else "base"
        return owner(run) + mapOf(
            "audioInventorySha256" to "a".repeat(64), "engineVersion" to "1.9.4",
            "parameters" to mapOf("executionMode" to "postSession", "requestedTiming" to "live", "languageHint" to "mixed", "parameterVersion" to 1),
            "manifest" to mapOf(
                "schemaVersion" to 1, "id" to "whisper-$name-q5_1",
                "version" to "f281eb45af861ab5e5297d23694b7d46e090c02c",
                "source" to "https://huggingface.co/ggerganov/whisper.cpp/resolve/f281eb45af861ab5e5297d23694b7d46e090c02c/ggml-$name-q5_1.bin",
                "artifactPath" to "models/transcription/ggml-$name-q5_1.bin",
                "sha256" to if (small) "ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb" else "422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898",
                "bytes" to if (small) 190085487 else 59707625,
                "runtime" to mapOf("engineId" to "whisper_cpp", "modelFormat" to "ggml"),
                "license" to mapOf("id" to "MIT", "snapshotPath" to "models/licenses/openai-whisper-model-MIT.txt"),
                "capabilities" to listOf("transcription"), "enabledModes" to listOf("postSession"),
            ),
        )
    }
}
