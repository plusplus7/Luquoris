package com.loquiris.export

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.zip.ZipInputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class ExportRoundTripMatrixTest {
    @Test
    fun `plain text subtitle and json exports round trip as utf8`() {
        val cases =
            listOf(
                Triple(LocalExportFormat.text, "content.txt", "Alice: corrected text\n"),
                Triple(LocalExportFormat.subtitles, "content.srt", "1\n00:00:00,000 --> 00:00:01,000\nAlice: hello\n"),
                Triple(LocalExportFormat.json, "meeting.json", "{\"schemaVersion\":1,\"title\":\"Private\"}"),
            )

        cases.forEach { (format, entryName, content) ->
            val output = ByteArrayOutputStream()

            val result =
                ExportPackageWriter(MatrixAudioSource()).write(
                    request = request(format, documents = mapOf(entryName to content)),
                    output = output,
                )

            assertEquals(content, output.toString(Charsets.UTF_8.name()))
            assertEquals(content.toByteArray().size.toLong(), (result as ExportWriteResult.Success).bytesWritten)
        }
    }

    @Test
    fun `continuous m4a export round trips exact source bytes`() {
        val expected = byteArrayOf(0, 1, 2, 3, 4, 5)
        val output = ByteArrayOutputStream()

        val result =
            ExportPackageWriter(MatrixAudioSource(continuousBytes = expected)).write(
                request = request(LocalExportFormat.audioM4a, includeAudio = true),
                output = output,
            )

        assertArrayEquals(expected, output.toByteArray())
        assertEquals(expected.size.toLong(), (result as ExportWriteResult.Success).bytesWritten)
        assertFalse(result.usedSegmentFallback)
    }

    @Test
    fun `segment archive round trips committed entries and disclosure`() {
        val output = ByteArrayOutputStream()

        val result =
            ExportPackageWriter(MatrixAudioSource()).write(
                request =
                    request(
                        LocalExportFormat.audioSegments,
                        includeAudio = true,
                        allowSegmentFallback = true,
                    ),
                output = output,
            ) as ExportWriteResult.Success

        val entries = unzip(output.toByteArray())
        assertArrayEquals(byteArrayOf(6, 7, 8), entries.getValue("audio/segment-00000.adts"))
        assertEquals(
            "{\"schemaVersion\":1,\"warningCode\":\"export_audio_segments_selected\",\"audioReasonCode\":\"segments_selected\",\"partial\":false,\"diagnosticCodes\":[]}",
            entries.getValue("export-disclosure.json").toString(Charsets.UTF_8),
        )
        assertEquals(false, result.usedSegmentFallback)
    }

    @Test
    fun `complete meeting archive round trips documents and continuous audio`() {
        val output = ByteArrayOutputStream()
        val documents =
            mapOf(
                "meeting.json" to "{\"schemaVersion\":1}",
                "transcript.txt" to "corrected text\n",
                "transcript.srt" to "1\n00:00:00,000 --> 00:00:01,000\nhello\n",
            )

        val result =
            ExportPackageWriter(MatrixAudioSource()).write(
                request =
                    request(
                        LocalExportFormat.archive,
                        documents = documents,
                        includeAudio = true,
                        allowSegmentFallback = true,
                    ),
                output = output,
            ) as ExportWriteResult.Success

        val entries = unzip(output.toByteArray())
        assertEquals(documents.keys + "audio/recording.m4a", entries.keys)
        documents.forEach { (name, content) ->
            assertEquals(content, entries.getValue(name).toString(Charsets.UTF_8))
        }
        assertArrayEquals(byteArrayOf(1, 2, 3, 4), entries.getValue("audio/recording.m4a"))
        assertFalse(result.usedSegmentFallback)
    }

    private fun request(
        format: LocalExportFormat,
        documents: Map<String, String> = emptyMap(),
        includeAudio: Boolean = false,
        allowSegmentFallback: Boolean = false,
    ) =
        LocalExportRequest(
            operationId = "export-round-trip",
            sessionId = "meeting-1",
            format = format,
            suggestedFileName = "Loquiris_20261001_090705.zip",
            mimeType = "application/octet-stream",
            documents = documents,
            includeAudio = includeAudio,
            allowSegmentFallback = allowSegmentFallback,
            segmentPlan = emptyList(),
            audioPartial = false,
            audioDiagnosticCodes = emptyList(),
        )

    private fun unzip(bytes: ByteArray): LinkedHashMap<String, ByteArray> {
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

private class MatrixAudioSource(
    private val continuousBytes: ByteArray = byteArrayOf(1, 2, 3, 4),
) : ExportAudioSource {
    override fun continuous(sessionId: String): ExportAudioResult =
        ExportAudioResult.Available(
            listOf(
                ExportSourceEntry("recording.m4a", continuousBytes.size.toLong()) {
                    ByteArrayInputStream(continuousBytes)
                },
            ),
        )

    override fun segments(
        sessionId: String,
        plan: List<ExportSegmentPlanEntry>,
    ): ExportAudioResult =
        ExportAudioResult.Available(
            listOf(
                ExportSourceEntry("segment-00000.adts", 3) {
                    ByteArrayInputStream(byteArrayOf(6, 7, 8))
                },
            ),
        )
}
