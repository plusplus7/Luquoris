package com.loquiris.backup

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.zip.ZipInputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BackupPackageWriterTest {
    @Test
    fun `writes canonical manifest first and sorted checksummed payload`() {
        val output = ByteArrayOutputStream()
        val result =
            BackupPackageWriter().write(
                request =
                    BackupPackageRequest(
                        formatVersion = 1,
                        schemaVersion = 4,
                        appVersion = "1.2.3+45",
                        exportedAtUtc = "2026-10-01T02:03:04.000Z",
                        sources =
                            listOf(
                                source("payload/recordings/${"a".repeat(64)}/segment-00000.adts", "audio"),
                                source("payload/database/loquiris.sqlite", "database"),
                                source("payload/recordings/${"a".repeat(64)}/segments.manifest", "manifest"),
                                source("payload/recordings/${"a".repeat(64)}/segment-00000.commit", "journal"),
                            ),
                    ),
                output = output,
            )

        val success = result as BackupWriteResult.Success
        assertEquals(output.size().toLong(), success.bytesWritten)
        assertEquals(64, success.sha256.length)

        val entries = unzip(output.toByteArray())
        assertEquals(
            listOf(
                "manifest.json",
                "payload/checksums.json",
                "payload/database/loquiris.sqlite",
                "payload/recordings/${"a".repeat(64)}/segment-00000.adts",
                "payload/recordings/${"a".repeat(64)}/segment-00000.commit",
                "payload/recordings/${"a".repeat(64)}/segments.manifest",
            ),
            entries.keys.toList(),
        )
        assertEquals(
            "{\"formatVersion\":1,\"schemaVersion\":4,\"appVersion\":\"1.2.3+45\",\"exportedAtUtc\":\"2026-10-01T02:03:04.000Z\",\"encrypted\":false,\"checksums\":{\"path\":\"payload/checksums.json\",\"sha256\":\"f39b0e7817e28052ee38f94afe5c49a134c216edb60b1e265677665febe94f2c\"}}",
            entries.getValue("manifest.json").decodeToString(),
        )
        assertEquals(
            "{\"schemaVersion\":1,\"entries\":[{\"path\":\"payload/database/loquiris.sqlite\",\"bytes\":8,\"sha256\":\"3549b0028b75d981cdda2e573e9cb49dedc200185876df299f912b79f69dabd8\"},{\"path\":\"payload/recordings/${"a".repeat(64)}/segment-00000.adts\",\"bytes\":5,\"sha256\":\"6ed8919ce20490a5e3ad8630a4fab69475297abd07db73918dd5f36fcfaeb11b\"},{\"path\":\"payload/recordings/${"a".repeat(64)}/segment-00000.commit\",\"bytes\":7,\"sha256\":\"81dd6b775afcccb6dbb8a25a58ea844271bbefaeea7cb1d91c1687d7450f850c\"},{\"path\":\"payload/recordings/${"a".repeat(64)}/segments.manifest\",\"bytes\":8,\"sha256\":\"05b3abf2579a5eb66403cd78be557fd860633a1fe2103c7642030defe32c657f\"}]}" ,
            entries.getValue("payload/checksums.json").decodeToString(),
        )
    }

    @Test
    fun `rejects model cache temp and log paths`() {
        listOf(
            "payload/models/model.bin",
            "payload/cache/waveform.bin",
            "payload/logs/diagnostic.log",
            "payload/recordings/${"b".repeat(64)}/recording.m4a",
            "payload/recordings/${"b".repeat(64)}/segment-00000.adts.tmp",
        ).forEach { path ->
            val result =
                BackupPackageWriter().write(
                    request = request(listOf(source(path, "private"))),
                    output = ByteArrayOutputStream(),
                )
            assertEquals(BackupWriteResult.Failure("backup_payload_path_not_allowed"), result)
        }
    }

    @Test
    fun `fails when source changes between hash and write passes`() {
        var openings = 0
        val source =
            BackupPayloadSource("payload/database/loquiris.sqlite") {
                openings += 1
                ByteArrayInputStream(if (openings == 1) "first".encodeToByteArray() else "second".encodeToByteArray())
            }

        val result =
            BackupPackageWriter().write(
                request = request(listOf(source)),
                output = ByteArrayOutputStream(),
            )

        assertEquals(BackupWriteResult.Failure("backup_source_changed"), result)
    }

    @Test
    fun `same request produces identical bytes`() {
        val first = ByteArrayOutputStream()
        val second = ByteArrayOutputStream()
        val request = request(listOf(source("payload/database/loquiris.sqlite", "stable")))

        assertTrue(BackupPackageWriter().write(request, first) is BackupWriteResult.Success)
        assertTrue(BackupPackageWriter().write(request, second) is BackupWriteResult.Success)

        assertTrue(first.toByteArray().contentEquals(second.toByteArray()))
    }

    private fun request(sources: List<BackupPayloadSource>) =
        BackupPackageRequest(
            formatVersion = 1,
            schemaVersion = 4,
            appVersion = "test",
            exportedAtUtc = "2026-10-01T00:00:00.000Z",
            sources = sources,
        )

    private fun source(
        path: String,
        content: String,
    ) = BackupPayloadSource(path) { ByteArrayInputStream(content.encodeToByteArray()) }

    private fun unzip(bytes: ByteArray): LinkedHashMap<String, ByteArray> {
        val result = linkedMapOf<String, ByteArray>()
        ZipInputStream(ByteArrayInputStream(bytes)).use { zip ->
            while (true) {
                val entry = zip.nextEntry ?: break
                result[entry.name] = zip.readBytes()
            }
        }
        return result
    }
}
