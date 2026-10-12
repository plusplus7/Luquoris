package com.loquiris.export

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.zip.ZipInputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ExportPackageWriterTest {
    @Test
    fun `plain documents are written without a container`() {
        val output = ByteArrayOutputStream()
        val result =
            ExportPackageWriter(FakeAudioSource()).write(
                request = request(format = LocalExportFormat.text, documents = mapOf("content.txt" to "hello")),
                output = output,
            )

        assertArrayEquals("hello".toByteArray(), output.toByteArray())
        assertEquals(5L, (result as ExportWriteResult.Success).bytesWritten)
        assertEquals(false, result.usedSegmentFallback)
    }

    @Test
    fun `archive falls back to committed segments and discloses it`() {
        val source =
            FakeAudioSource(
                continuous = ExportAudioResult.Unavailable("recording_m4a_mux_failed"),
                segments =
                    ExportAudioResult.Available(
                        listOf(
                            ExportSourceEntry("segment-00000.aac", 3) { ByteArrayInputStream(byteArrayOf(1, 2, 3)) },
                            ExportSourceEntry("segment-00001.aac", 2) { ByteArrayInputStream(byteArrayOf(4, 5)) },
                        ),
                    ),
            )
        val output = ByteArrayOutputStream()

        val result =
            ExportPackageWriter(source).write(
                request =
                    request(
                        format = LocalExportFormat.archive,
                        documents = mapOf("meeting.json" to "{\"schemaVersion\":1}"),
                        includeAudio = true,
                        allowSegmentFallback = true,
                    ),
                output = output,
            ) as ExportWriteResult.Success

        val entries = unzip(output.toByteArray())
        assertEquals(
            setOf(
                "meeting.json",
                "audio/segment-00000.aac",
                "audio/segment-00001.aac",
                "export-disclosure.json",
            ),
            entries.keys,
        )
        assertTrue(String(entries.getValue("export-disclosure.json")).contains("recording_m4a_mux_failed"))
        assertEquals(true, result.usedSegmentFallback)
        assertEquals(listOf("export_audio_segments_used"), result.warningCodes)
    }

    @Test
    fun `continuous audio request never silently changes to segments`() {
        val source =
            FakeAudioSource(
                continuous = ExportAudioResult.Unavailable("recording_m4a_mux_failed"),
                segments =
                    ExportAudioResult.Available(
                        listOf(ExportSourceEntry("segment.aac", 1) { ByteArrayInputStream(byteArrayOf(1)) }),
                    ),
            )

        val result =
            ExportPackageWriter(source).write(
                request = request(format = LocalExportFormat.audioM4a, includeAudio = true),
                output = ByteArrayOutputStream(),
            )

        assertEquals(
            ExportWriteResult.Failure("recording_m4a_mux_failed"),
            result,
        )
    }

    @Test
    fun `shortened source cannot produce a successful audio export`() {
        val source =
            FakeAudioSource(
                continuous =
                    ExportAudioResult.Available(
                        listOf(
                            ExportSourceEntry("recording.m4a", 3) {
                                ByteArrayInputStream(byteArrayOf(8, 9))
                            },
                        ),
                    ),
            )

        val result =
            ExportPackageWriter(source).write(
                request = request(format = LocalExportFormat.audioM4a, includeAudio = true),
                output = ByteArrayOutputStream(),
            )

        assertEquals(ExportWriteResult.Failure("export_audio_source_truncated"), result)
    }

    @Test
    fun `partial segment package discloses durable recovery findings`() {
        val source =
            FakeAudioSource(
                segments =
                    ExportAudioResult.Available(
                        listOf(
                            ExportSourceEntry("segment-00000.aac", 2) {
                                ByteArrayInputStream(byteArrayOf(1, 2))
                            },
                        ),
                    ),
            )
        val output = ByteArrayOutputStream()

        val result =
            ExportPackageWriter(source).write(
                request =
                    request(
                        format = LocalExportFormat.audioSegments,
                        includeAudio = true,
                        allowSegmentFallback = true,
                        audioPartial = true,
                        audioDiagnosticCodes = listOf("recording_recovery_timeline_gap"),
                    ),
                output = output,
            ) as ExportWriteResult.Success

        val disclosure = String(unzip(output.toByteArray()).getValue("export-disclosure.json"))
        assertTrue(disclosure.contains("\"partial\":true"))
        assertTrue(disclosure.contains("recording_recovery_timeline_gap"))
        assertTrue(result.warningCodes.contains("export_audio_partial"))
    }

    @Test
    fun `cooperative cancellation stops a bounded copy and reports progress`() {
        val bytes = ByteArray(32 * 1024) { 7 }
        val source =
            FakeAudioSource(
                continuous =
                    ExportAudioResult.Available(
                        listOf(
                            ExportSourceEntry("recording.m4a", bytes.size.toLong()) {
                                ByteArrayInputStream(bytes)
                            },
                        ),
                    ),
            )
        val control = CancellingWriteControl()
        val output = ByteArrayOutputStream()

        val result =
            ExportPackageWriter(source).write(
                request = request(format = LocalExportFormat.audioM4a, includeAudio = true),
                output = output,
                control = control,
            )

        assertEquals(ExportWriteResult.Failure("export_cancelled"), result)
        assertTrue(output.size() in 1 until bytes.size)
        assertTrue(control.snapshots.any { it.first > 0L && it.second == bytes.size.toLong() })
    }

    @Test
    fun `cancellation requested by the final progress callback cannot report success`() {
        val content = "one bounded write"
        val control = CancellingWriteControl()

        val result =
            ExportPackageWriter(FakeAudioSource()).write(
                request =
                    request(
                        format = LocalExportFormat.text,
                        documents = mapOf("meeting.txt" to content),
                    ),
                output = ByteArrayOutputStream(),
                control = control,
            )

        assertEquals(ExportWriteResult.Failure("export_cancelled"), result)
        assertEquals(content.toByteArray().size.toLong(), control.snapshots.last().first)
    }

    private fun request(
        format: LocalExportFormat,
        documents: Map<String, String> = emptyMap(),
        includeAudio: Boolean = false,
        allowSegmentFallback: Boolean = false,
        audioPartial: Boolean = false,
        audioDiagnosticCodes: List<String> = emptyList(),
    ) =
        LocalExportRequest(
            operationId = "export-1",
            sessionId = "meeting-1",
            format = format,
            suggestedFileName = "Loquiris_20261001_090705.zip",
            mimeType = "application/zip",
            documents = documents,
            includeAudio = includeAudio,
            allowSegmentFallback = allowSegmentFallback,
            segmentPlan = emptyList(),
            audioPartial = audioPartial,
            audioDiagnosticCodes = audioDiagnosticCodes,
        )

    private fun unzip(bytes: ByteArray): Map<String, ByteArray> {
        val entries = linkedMapOf<String, ByteArray>()
        ZipInputStream(ByteArrayInputStream(bytes)).use { input ->
            var entry = input.nextEntry
            while (entry != null) {
                entries[entry.name] = input.readBytes()
                input.closeEntry()
                entry = input.nextEntry
            }
        }
        return entries
    }
}

private class CancellingWriteControl : ExportWriteControl {
    val snapshots = mutableListOf<Pair<Long, Long?>>()
    private var cancelled = false

    override fun isCancellationRequested(): Boolean = cancelled

    override fun onProgress(
        bytesProcessed: Long,
        totalBytes: Long?,
    ) {
        snapshots += bytesProcessed to totalBytes
        if (bytesProcessed > 0) cancelled = true
    }
}

private class FakeAudioSource(
    private val continuous: ExportAudioResult =
        ExportAudioResult.Available(
            listOf(ExportSourceEntry("recording.m4a", 2) { ByteArrayInputStream(byteArrayOf(8, 9)) }),
        ),
    private val segments: ExportAudioResult = ExportAudioResult.Unavailable("recording_segments_unavailable"),
) : ExportAudioSource {
    override fun continuous(sessionId: String): ExportAudioResult = continuous

    override fun segments(
        sessionId: String,
        plan: List<ExportSegmentPlanEntry>,
    ): ExportAudioResult = segments
}
