package com.loquiris.export

import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingExportAudioSourceTest {
    @Test
    fun `persisted partial plan exports its intact committed entries only`() {
        val root = Files.createTempDirectory("loquiris-export-root").toFile()
        val session = File(root, "recordings/hash").apply { mkdirs() }
        File(session, "segment-00000.adts").writeBytes(byteArrayOf(1, 2, 3, 4))

        val result =
            resolvePlannedSegmentEntries(
                root = root,
                expectedDirectory = session,
                plan =
                    listOf(
                        ExportSegmentPlanEntry(
                            sequence = 0,
                            relativePath = "recordings/hash/segment-00000.adts",
                            committedBytes = 3,
                        ),
                    ),
            )

        val available = result as ExportAudioResult.Available
        assertEquals(1, available.entries.size)
        assertEquals(3L, available.entries.single().bytes)
        assertEquals(listOf<Byte>(1, 2, 3), available.entries.single().open().use { it.readBytes().toList() })
    }

    @Test
    fun `shortened or cross-session planned files are rejected`() {
        val root = Files.createTempDirectory("loquiris-export-root").toFile()
        val session = File(root, "recordings/hash").apply { mkdirs() }
        File(session, "segment-00000.adts").writeBytes(byteArrayOf(1, 2))
        val other = File(root, "recordings/other").apply { mkdirs() }
        File(other, "segment-00000.adts").writeBytes(byteArrayOf(1, 2, 3))

        val shortened =
            resolvePlannedSegmentEntries(
                root,
                session,
                listOf(
                    ExportSegmentPlanEntry(
                        0,
                        "recordings/hash/segment-00000.adts",
                        3,
                    ),
                ),
            )
        val foreign =
            resolvePlannedSegmentEntries(
                root,
                session,
                listOf(
                    ExportSegmentPlanEntry(
                        0,
                        "recordings/other/segment-00000.adts",
                        3,
                    ),
                ),
            )

        assertEquals(
            ExportAudioResult.Unavailable("export_audio_source_truncated"),
            shortened,
        )
        assertTrue(foreign is ExportAudioResult.Unavailable)
    }
}
