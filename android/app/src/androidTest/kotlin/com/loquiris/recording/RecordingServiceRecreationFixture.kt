package com.loquiris.recording

import android.os.Bundle
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.io.FileOutputStream
import org.json.JSONObject

internal data class RecordingServiceRecreationMarker(
    val nonce: String,
    val sessionId: String,
    val bytesWritten: Long,
    val revision: Long,
)

internal object RecordingServiceRecreationFixture {
    const val PHASE_ARGUMENT = "loquirisRecordingRecreationPhase"
    const val NONCE_ARGUMENT = "loquirisRecordingRecreationNonce"
    const val PREPARE_PHASE = "prepare"
    const val RECOVER_PHASE = "recover"

    fun requireNonce(arguments: Bundle): String =
        requireNotNull(arguments.getString(NONCE_ARGUMENT)?.takeIf(String::isNotBlank)) {
            "A fresh $NONCE_ARGUMENT is required"
        }

    fun writeMarker(
        nonce: String,
        snapshot: NativeRecordingSnapshot,
    ) {
        val sessionId = requireNotNull(snapshot.sessionId)
        val directory = fixtureDirectory()
        check(!directory.exists() || directory.deleteRecursively()) { "Unable to clear recreation fixture" }
        check(directory.mkdirs()) { "Unable to create recreation fixture" }
        val target = markerFile()
        val temporary = File(directory, "marker.tmp")
        val payload =
            JSONObject()
                .put("nonce", nonce)
                .put("sessionId", sessionId)
                .put("bytesWritten", snapshot.bytesWritten)
                .put("revision", snapshot.revision)
                .toString()
                .toByteArray(Charsets.UTF_8)
        FileOutputStream(temporary).use { output ->
            output.write(payload)
            output.fd.sync()
        }
        check(temporary.renameTo(target)) { "Unable to publish recreation marker" }
    }

    fun readMarker(): RecordingServiceRecreationMarker {
        val file = markerFile()
        check(file.isFile) { "Missing service recreation marker" }
        val json = JSONObject(file.readText())
        return RecordingServiceRecreationMarker(
            nonce = json.getString("nonce"),
            sessionId = json.getString("sessionId"),
            bytesWritten = json.getLong("bytesWritten"),
            revision = json.getLong("revision"),
        )
    }

    fun consumeMarker(): Boolean = markerFile().delete()

    private fun fixtureDirectory(): File =
        File(
            InstrumentationRegistry.getInstrumentation().targetContext.filesDir,
            "recording-service-recreation",
        )

    private fun markerFile(): File = File(fixtureDirectory(), "ready.json")
}
