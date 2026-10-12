package com.loquiris.recording

import android.content.Context
import java.io.File

object AppPrivateRecordingStorage {
    fun sessionDirectory(
        context: Context,
        sessionId: String,
    ): File {
        require(sessionId.isNotBlank()) { "sessionId must be non-blank" }
        return File(File(context.applicationContext.filesDir, RECORDINGS_DIRECTORY), sessionId.sha256Hex())
    }

    private const val RECORDINGS_DIRECTORY = "recordings"
}
