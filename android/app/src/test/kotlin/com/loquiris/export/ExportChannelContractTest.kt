package com.loquiris.export

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ExportChannelContractTest {
    @Test
    fun `decodes the mirrored Dart version one request`() {
        val decoded =
            ExportChannelContract.decodeRequest(
                mapOf(
                    "v" to 1,
                    "operationId" to "export-1",
                    "sessionId" to "meeting-1",
                    "format" to "archive",
                    "suggestedFileName" to "Loquiris_20261001_090705.zip",
                    "mimeType" to "application/zip",
                    "documents" to mapOf("meeting.json" to "{}"),
                    "includeAudio" to true,
                    "allowSegmentFallback" to true,
                    "segmentPlan" to
                        listOf(
                            mapOf(
                                "sequence" to 0,
                                "relativePath" to "recordings/hash/segment-00000.adts",
                                "committedBytes" to 321L,
                            ),
                        ),
                    "audioPartial" to true,
                    "audioDiagnosticCodes" to listOf("recording_recovery_timeline_gap"),
                ),
            )

        assertEquals(
            ExportRequestDecodeResult.Success(
                LocalExportRequest(
                    operationId = "export-1",
                    sessionId = "meeting-1",
                    format = LocalExportFormat.archive,
                    suggestedFileName = "Loquiris_20261001_090705.zip",
                    mimeType = "application/zip",
                    documents = mapOf("meeting.json" to "{}"),
                    includeAudio = true,
                    allowSegmentFallback = true,
                    segmentPlan =
                        listOf(
                            ExportSegmentPlanEntry(
                                sequence = 0,
                                relativePath = "recordings/hash/segment-00000.adts",
                                committedBytes = 321,
                            ),
                        ),
                    audioPartial = true,
                    audioDiagnosticCodes = listOf("recording_recovery_timeline_gap"),
                ),
            ),
            decoded,
        )
    }

    @Test
    fun `rejects malformed or oversized channel input`() {
        val malformed =
            ExportChannelContract.decodeRequest(
                mapOf(
                    "v" to 1,
                    "operationId" to "export-1",
                    "sessionId" to "meeting-1",
                    "format" to "text",
                    "suggestedFileName" to "../secret.txt",
                    "mimeType" to "text/plain",
                    "documents" to mapOf("content.txt" to "hello"),
                    "includeAudio" to false,
                    "allowSegmentFallback" to false,
                    "segmentPlan" to emptyList<Any>(),
                    "audioPartial" to false,
                    "audioDiagnosticCodes" to emptyList<String>(),
                ),
            )
        val oversized =
            ExportChannelContract.decodeRequest(
                mapOf(
                    "v" to 1,
                    "operationId" to "export-2",
                    "sessionId" to "meeting-1",
                    "format" to "text",
                    "suggestedFileName" to "Loquiris.txt",
                    "mimeType" to "text/plain",
                    "documents" to mapOf("content.txt" to "x".repeat(16 * 1024 * 1024 + 1)),
                    "includeAudio" to false,
                    "allowSegmentFallback" to false,
                    "segmentPlan" to emptyList<Any>(),
                    "audioPartial" to false,
                    "audioDiagnosticCodes" to emptyList<String>(),
                ),
            )

        assertTrue(malformed is ExportRequestDecodeResult.Failure)
        assertTrue(oversized is ExportRequestDecodeResult.Failure)
    }

    @Test
    fun `success response contains only destination metadata`() {
        assertEquals(
            mapOf(
                "v" to 1,
                "ok" to true,
                "receipt" to
                    mapOf(
                        "fileName" to "Loquiris.zip",
                        "bytesWritten" to 99L,
                        "usedSegmentFallback" to true,
                        "warningCodes" to listOf("export_audio_segments_used"),
                    ),
            ),
            ExportChannelContract.success(
                fileName = "Loquiris.zip",
                result =
                    ExportWriteResult.Success(
                        bytesWritten = 99,
                        usedSegmentFallback = true,
                        warningCodes = listOf("export_audio_segments_used"),
                    ),
            ),
        )
    }

    @Test
    fun `operation commands and progress use the same validated identity`() {
        assertEquals(
            ExportOperationDecodeResult.Success("export-3"),
            ExportChannelContract.decodeOperation(
                mapOf("v" to 1, "operationId" to "export-3"),
            ),
        )
        assertEquals(
            mapOf(
                "v" to 1,
                "ok" to true,
                "progress" to
                    mapOf(
                        "operationId" to "export-3",
                        "phase" to "writing",
                        "bytesProcessed" to 1024L,
                        "totalBytes" to 4096L,
                        "cancellable" to true,
                    ),
            ),
            ExportChannelContract.progress(
                operationId = "export-3",
                phase = ExportProgressPhase.writing,
                bytesProcessed = 1024,
                totalBytes = 4096,
                cancellable = true,
            ),
        )
    }
}
