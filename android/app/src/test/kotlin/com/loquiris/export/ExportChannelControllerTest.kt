package com.loquiris.export

import java.io.IOException
import java.io.OutputStream
import java.util.concurrent.Executor
import org.junit.Assert.assertEquals
import org.junit.Test

class ExportChannelControllerTest {
    @Test
    fun `write failure deletes destination and reports cleanup refusal`() {
        val destinations = FakeDestinations(deleteResult = false)
        val replies = mutableListOf<Any?>()
        val controller =
            ExportChannelController(
                exportExecutor = Executor(Runnable::run),
                replyExecutor = Executor(Runnable::run),
                writer = ExportPackageWriter(FakeControllerAudioSource()),
                destinations = destinations,
                destinationLauncher = ExportDestinationLauncher { _, _ -> },
            )

        controller.handle("save", textRequest(), replies::add)
        controller.onDestinationResult("content://documents/export-1")

        assertEquals(listOf("content://documents/export-1"), destinations.deleted)
        assertEquals(
            ExportChannelContract.failure("export_incomplete_output_cleanup_failed"),
            replies.single(),
        )
    }

    private fun textRequest(): Map<String, Any> =
        mapOf(
            "v" to 1,
            "operationId" to "export-1",
            "sessionId" to "meeting-1",
            "format" to "text",
            "suggestedFileName" to "Loquiris_20261001_090705.txt",
            "mimeType" to "text/plain",
            "documents" to mapOf("meeting.txt" to "hello"),
            "includeAudio" to false,
            "allowSegmentFallback" to false,
            "segmentPlan" to emptyList<Any>(),
            "audioPartial" to false,
            "audioDiagnosticCodes" to emptyList<String>(),
        )
}

private class FakeDestinations(
    private val deleteResult: Boolean,
) : ExportDestinations {
    val deleted = mutableListOf<String>()

    override fun open(destinationId: String): OutputStream =
        object : OutputStream() {
            override fun write(value: Int) {
                throw IOException("injected provider failure")
            }

            override fun write(
                bytes: ByteArray,
                offset: Int,
                length: Int,
            ) {
                throw IOException("injected provider failure")
            }
        }

    override fun delete(destinationId: String): Boolean {
        deleted += destinationId
        return deleteResult
    }

    override fun displayName(destinationId: String): String? = null
}

private class FakeControllerAudioSource : ExportAudioSource {
    override fun continuous(sessionId: String): ExportAudioResult =
        ExportAudioResult.Unavailable("export_audio_unavailable")

    override fun segments(
        sessionId: String,
        plan: List<ExportSegmentPlanEntry>,
    ): ExportAudioResult = ExportAudioResult.Unavailable("export_audio_unavailable")
}
