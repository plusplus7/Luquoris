package com.loquiris.recording

import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import org.json.JSONArray
import org.json.JSONObject

internal data class RecordingDeviceRestartPrefix(
    val sequence: Int,
    val dataFileName: String,
    val committedBytes: Int,
    val sha256: String,
)

internal data class RecordingDeviceRestartMarker(
    val nonce: String,
    val sessionId: String,
    val bytesWritten: Long,
    val revision: Long,
    val manifestSha256: String,
    val prefixes: List<RecordingDeviceRestartPrefix>,
)

internal object RecordingDeviceRestartFixture {
    fun writeMarker(
        nonce: String,
        snapshot: NativeRecordingSnapshot,
    ) {
        val sessionId = requireNotNull(snapshot.sessionId)
        val sessionDirectory =
            AppPrivateRecordingStorage.sessionDirectory(
                InstrumentationRegistry.getInstrumentation().targetContext,
                sessionId,
            )
        val manifestFile = File(sessionDirectory, AtomicRecordingSegmentManifestStore.MANIFEST_FILE_NAME)
        val manifest =
            (
                AtomicRecordingSegmentManifestStore(sessionDirectory).load()
                    as RecordingSegmentManifestDecodeResult.Success
            ).manifest
        val prefixes =
            manifest.segments.mapNotNull { segment ->
                val data = File(sessionDirectory, segment.dataFileName).readBytes()
                val journal = File(sessionDirectory, segment.journalFileName).readBytes()
                val recovered = RecordingCommittedPrefixRecovery.recover(data, journal)
                if (recovered.committedBytes == 0) {
                    null
                } else {
                    RecordingDeviceRestartPrefix(
                        sequence = segment.index,
                        dataFileName = segment.dataFileName,
                        committedBytes = recovered.committedBytes,
                        sha256 = data.copyOf(recovered.committedBytes).sha256(),
                    )
                }
            }
        check(prefixes.isNotEmpty()) { "Device-restart fixture has no committed prefix" }

        val directory = fixtureDirectory()
        check(!directory.exists() || directory.deleteRecursively()) { "Unable to clear device-restart fixture" }
        check(directory.mkdirs()) { "Unable to create device-restart fixture" }
        val temporary = File(directory, "marker.tmp")
        val payload =
            JSONObject()
                .put("nonce", nonce)
                .put("sessionId", sessionId)
                .put("bytesWritten", snapshot.bytesWritten)
                .put("revision", snapshot.revision)
                .put("manifestSha256", manifestFile.readBytes().sha256())
                .put(
                    "prefixes",
                    JSONArray().apply {
                        prefixes.forEach { prefix ->
                            put(
                                JSONObject()
                                    .put("sequence", prefix.sequence)
                                    .put("dataFileName", prefix.dataFileName)
                                    .put("committedBytes", prefix.committedBytes)
                                    .put("sha256", prefix.sha256),
                            )
                        }
                    },
                ).toString()
                .toByteArray(Charsets.UTF_8)
        FileOutputStream(temporary).use { output ->
            output.write(payload)
            output.fd.sync()
        }
        check(temporary.renameTo(markerFile())) { "Unable to publish device-restart marker" }
        check(AndroidRecordingFileOperations.syncDirectory(directory)) {
            "Unable to sync device-restart marker directory"
        }
    }

    fun readMarker(): RecordingDeviceRestartMarker {
        val file = markerFile()
        check(file.isFile) { "Missing device-restart marker" }
        val json = JSONObject(file.readText())
        val rawPrefixes = json.getJSONArray("prefixes")
        val prefixes =
            buildList {
                repeat(rawPrefixes.length()) { index ->
                    val raw = rawPrefixes.getJSONObject(index)
                    add(
                        RecordingDeviceRestartPrefix(
                            sequence = raw.getInt("sequence"),
                            dataFileName = raw.getString("dataFileName"),
                            committedBytes = raw.getInt("committedBytes"),
                            sha256 = raw.getString("sha256"),
                        ),
                    )
                }
            }
        return RecordingDeviceRestartMarker(
            nonce = json.getString("nonce"),
            sessionId = json.getString("sessionId"),
            bytesWritten = json.getLong("bytesWritten"),
            revision = json.getLong("revision"),
            manifestSha256 = json.getString("manifestSha256"),
            prefixes = prefixes,
        )
    }

    fun currentManifestSha256(sessionId: String): String =
        File(
            AppPrivateRecordingStorage.sessionDirectory(
                InstrumentationRegistry.getInstrumentation().targetContext,
                sessionId,
            ),
            AtomicRecordingSegmentManifestStore.MANIFEST_FILE_NAME,
        ).readBytes().sha256()

    fun currentPrefixes(sessionId: String): List<RecordingDeviceRestartPrefix> {
        val directory =
            AppPrivateRecordingStorage.sessionDirectory(
                InstrumentationRegistry.getInstrumentation().targetContext,
                sessionId,
            )
        val manifest =
            (
                AtomicRecordingSegmentManifestStore(directory).load()
                    as RecordingSegmentManifestDecodeResult.Success
            ).manifest
        return manifest.segments.mapNotNull { segment ->
            val data = File(directory, segment.dataFileName).readBytes()
            val journal = File(directory, segment.journalFileName).readBytes()
            val recovered = RecordingCommittedPrefixRecovery.recover(data, journal)
            if (recovered.committedBytes == 0) {
                null
            } else {
                RecordingDeviceRestartPrefix(
                    sequence = segment.index,
                    dataFileName = segment.dataFileName,
                    committedBytes = recovered.committedBytes,
                    sha256 = data.copyOf(recovered.committedBytes).sha256(),
                )
            }
        }
    }

    fun consumeMarker(): Boolean = markerFile().delete()

    private fun fixtureDirectory(): File =
        File(
            InstrumentationRegistry.getInstrumentation().targetContext.filesDir,
            "recording-device-restart",
        )

    private fun markerFile(): File = File(fixtureDirectory(), "ready.json")
}

private fun ByteArray.sha256(): String =
    MessageDigest
        .getInstance("SHA-256")
        .digest(this)
        .joinToString(separator = "") { byte -> "%02x".format(byte.toInt() and 0xff) }
