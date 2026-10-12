package com.loquiris.export

import android.content.Context
import com.loquiris.recording.AppPrivateRecordingStorage
import com.loquiris.recording.RecordingM4aArtifactResolveResult
import com.loquiris.recording.RecordingM4aArtifactResolver
import com.loquiris.recording.RecordingM4aRebuildResult
import com.loquiris.recording.RecordingM4aRebuilder
import java.io.File
import java.io.FileInputStream
import java.io.FilterInputStream
import java.io.InputStream

class RecordingExportAudioSource(
    context: Context,
    private val resolver: RecordingM4aArtifactResolver = RecordingM4aArtifactResolver(),
    private val rebuilder: RecordingM4aRebuilder = RecordingM4aRebuilder(),
) : ExportAudioSource {
    private val applicationContext = context.applicationContext

    override fun continuous(sessionId: String): ExportAudioResult {
        val directory = AppPrivateRecordingStorage.sessionDirectory(applicationContext, sessionId)
        val ready = resolver.resolve(directory)
        if (ready is RecordingM4aArtifactResolveResult.Ready) {
            return availableFile(ready.file, "recording.m4a")
        }
        return when (val rebuilt = rebuilder.rebuild(directory)) {
            is RecordingM4aRebuildResult.Success ->
                availableFile(File(directory, rebuilt.fileName), "recording.m4a")
            is RecordingM4aRebuildResult.Failure -> ExportAudioResult.Unavailable(rebuilt.code)
        }
    }

    override fun segments(
        sessionId: String,
        plan: List<ExportSegmentPlanEntry>,
    ): ExportAudioResult {
        if (plan.isEmpty()) return ExportAudioResult.Unavailable("recording_segments_empty")
        return try {
            val root = applicationContext.filesDir.canonicalFile
            val expectedDirectory =
                AppPrivateRecordingStorage.sessionDirectory(applicationContext, sessionId).canonicalFile
            resolvePlannedSegmentEntries(root, expectedDirectory, plan)
        } catch (_: Exception) {
            ExportAudioResult.Unavailable("recording_segments_read_failed")
        }
    }

    private fun availableFile(
        file: File,
        exportName: String,
    ): ExportAudioResult =
        if (file.isFile && file.length() > 0) {
            ExportAudioResult.Available(
                listOf(
                    ExportSourceEntry(exportName, file.length()) { FileInputStream(file) },
                ),
            )
        } else {
            ExportAudioResult.Unavailable("recording_m4a_output_missing")
        }
}

internal fun resolvePlannedSegmentEntries(
    root: File,
    expectedDirectory: File,
    plan: List<ExportSegmentPlanEntry>,
): ExportAudioResult {
    val canonicalRoot = root.canonicalFile
    val canonicalExpectedDirectory = expectedDirectory.canonicalFile
    if (!canonicalExpectedDirectory.path.startsWith(canonicalRoot.path + File.separator)) {
        return ExportAudioResult.Unavailable("recording_segment_path_invalid")
    }
    val entries =
        plan.map { segment ->
            val dataFile = File(canonicalRoot, segment.relativePath).canonicalFile
            if (
                !dataFile.path.startsWith(canonicalExpectedDirectory.path + File.separator) ||
                !dataFile.isFile
            ) {
                return ExportAudioResult.Unavailable("recording_segment_missing")
            }
            if (dataFile.length() < segment.committedBytes) {
                return ExportAudioResult.Unavailable("export_audio_source_truncated")
            }
            ExportSourceEntry(
                fileName = "segment-${segment.sequence.toString().padStart(5, '0')}.aac",
                bytes = segment.committedBytes,
            ) {
                BoundedInputStream(FileInputStream(dataFile), segment.committedBytes)
            }
        }
    return ExportAudioResult.Available(entries)
}

private class BoundedInputStream(
    input: InputStream,
    private var remaining: Long,
) : FilterInputStream(input) {
    override fun read(): Int {
        if (remaining <= 0) return -1
        val value = super.read()
        if (value >= 0) remaining -= 1
        return value
    }

    override fun read(
        buffer: ByteArray,
        offset: Int,
        length: Int,
    ): Int {
        if (remaining <= 0) return -1
        val read = super.read(buffer, offset, minOf(length.toLong(), remaining).toInt())
        if (read > 0) remaining -= read
        return read
    }
}
