package com.loquiris.export

import java.io.FilterOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

enum class LocalExportFormat {
    audioM4a,
    audioSegments,
    text,
    subtitles,
    json,
    archive,
}

data class LocalExportRequest(
    val operationId: String,
    val sessionId: String,
    val format: LocalExportFormat,
    val suggestedFileName: String,
    val mimeType: String,
    val documents: Map<String, String>,
    val includeAudio: Boolean,
    val allowSegmentFallback: Boolean,
    val segmentPlan: List<ExportSegmentPlanEntry>,
    val audioPartial: Boolean,
    val audioDiagnosticCodes: List<String>,
)

data class ExportSegmentPlanEntry(
    val sequence: Int,
    val relativePath: String,
    val committedBytes: Long,
)

data class ExportSourceEntry(
    val fileName: String,
    val bytes: Long,
    val open: () -> InputStream,
)

sealed interface ExportAudioResult {
    data class Available(
        val entries: List<ExportSourceEntry>,
    ) : ExportAudioResult

    data class Unavailable(
        val code: String,
    ) : ExportAudioResult
}

interface ExportAudioSource {
    fun continuous(sessionId: String): ExportAudioResult

    fun segments(
        sessionId: String,
        plan: List<ExportSegmentPlanEntry>,
    ): ExportAudioResult
}

sealed interface ExportWriteResult {
    data class Success(
        val bytesWritten: Long,
        val usedSegmentFallback: Boolean,
        val warningCodes: List<String>,
    ) : ExportWriteResult

    data class Failure(
        val code: String,
    ) : ExportWriteResult
}

interface ExportWriteControl {
    fun isCancellationRequested(): Boolean

    fun onProgress(
        bytesProcessed: Long,
        totalBytes: Long?,
    )
}

private object NoopExportWriteControl : ExportWriteControl {
    override fun isCancellationRequested(): Boolean = false

    override fun onProgress(
        bytesProcessed: Long,
        totalBytes: Long?,
    ) = Unit
}

class ExportPackageWriter(
    private val audioSource: ExportAudioSource,
) {
    fun write(
        request: LocalExportRequest,
        output: OutputStream,
        control: ExportWriteControl = NoopExportWriteControl,
    ): ExportWriteResult {
        if (!request.isValid()) return ExportWriteResult.Failure("export_request_invalid")
        val counted = CountingOutputStream(output, control)
        return try {
            counted.checkCancellation()
            when (request.format) {
                LocalExportFormat.text,
                LocalExportFormat.subtitles,
                LocalExportFormat.json,
                -> writeDocument(request, counted)
                LocalExportFormat.audioM4a -> writeContinuousAudio(request, counted)
                LocalExportFormat.audioSegments -> writeSegmentArchive(request, counted)
                LocalExportFormat.archive -> writeMeetingArchive(request, counted)
            }
        } catch (error: ExportSourceException) {
            ExportWriteResult.Failure(error.code)
        } catch (_: IOException) {
            ExportWriteResult.Failure("export_destination_write_failed")
        }
    }

    private fun writeDocument(
        request: LocalExportRequest,
        output: CountingOutputStream,
    ): ExportWriteResult {
        if (
            request.documents.size != 1 || request.includeAudio || request.segmentPlan.isNotEmpty() ||
            request.audioPartial || request.audioDiagnosticCodes.isNotEmpty()
        ) {
            return ExportWriteResult.Failure("export_request_invalid")
        }
        val bytes = request.documents.values.single().toByteArray(Charsets.UTF_8)
        output.totalBytes = bytes.size.toLong()
        output.writeBounded(bytes)
        output.flush()
        return success(output)
    }

    private fun writeContinuousAudio(
        request: LocalExportRequest,
        output: CountingOutputStream,
    ): ExportWriteResult {
        if (!request.includeAudio || request.allowSegmentFallback || request.documents.isNotEmpty()) {
            return ExportWriteResult.Failure("export_request_invalid")
        }
        return when (val audio = audioSource.continuous(request.sessionId)) {
            is ExportAudioResult.Available -> {
                if (audio.entries.size != 1) return ExportWriteResult.Failure("export_audio_invalid")
                output.totalBytes = audio.entries.single().bytes
                audio.entries.single().copyTo(output)
                output.flush()
                success(
                    output,
                    warningCodes = if (request.audioPartial) listOf("export_audio_partial") else emptyList(),
                )
            }
            is ExportAudioResult.Unavailable -> ExportWriteResult.Failure(audio.code)
        }
    }

    private fun writeSegmentArchive(
        request: LocalExportRequest,
        output: CountingOutputStream,
    ): ExportWriteResult {
        if (!request.includeAudio || !request.allowSegmentFallback || request.documents.isNotEmpty()) {
            return ExportWriteResult.Failure("export_request_invalid")
        }
        return when (val segments = audioSource.segments(request.sessionId, request.segmentPlan)) {
            is ExportAudioResult.Available -> {
                if (segments.entries.isEmpty()) return ExportWriteResult.Failure("export_audio_unavailable")
                ZipOutputStream(output).use { zip ->
                    segments.entries.forEach { it.copyTo(zip, "audio/${it.fileName}") }
                    writeDisclosure(
                        zip = zip,
                        audioReasonCode = "segments_selected",
                        warningCode = "export_audio_segments_selected",
                        partial = request.audioPartial,
                        diagnosticCodes = request.audioDiagnosticCodes,
                    )
                }
                success(
                    output,
                    warningCodes =
                        buildList {
                            add("export_audio_segments_selected")
                            if (request.audioPartial) add("export_audio_partial")
                        },
                )
            }
            is ExportAudioResult.Unavailable -> ExportWriteResult.Failure(segments.code)
        }
    }

    private fun writeMeetingArchive(
        request: LocalExportRequest,
        output: CountingOutputStream,
    ): ExportWriteResult {
        if (!request.includeAudio || !request.allowSegmentFallback || request.documents.isEmpty()) {
            return ExportWriteResult.Failure("export_request_invalid")
        }
        var usedFallback = false
        val warnings = mutableListOf<String>().apply {
            if (request.audioPartial) add("export_audio_partial")
        }
        ZipOutputStream(output).use { zip ->
            request.documents.toSortedMap().forEach { (name, content) ->
                zip.writeEntry(name, content.byteInputStream(Charsets.UTF_8))
            }
            when (val continuous = audioSource.continuous(request.sessionId)) {
                is ExportAudioResult.Available -> {
                    if (continuous.entries.size != 1) {
                        return ExportWriteResult.Failure("export_audio_invalid")
                    }
                    continuous.entries.single().copyTo(zip, "audio/recording.m4a")
                    if (request.audioPartial) {
                        writeDisclosure(
                            zip = zip,
                            audioReasonCode = "recording_recovery_partial",
                            warningCode = "export_audio_partial",
                            partial = true,
                            diagnosticCodes = request.audioDiagnosticCodes,
                        )
                    }
                }
                is ExportAudioResult.Unavailable -> {
                    when (val segments = audioSource.segments(request.sessionId, request.segmentPlan)) {
                        is ExportAudioResult.Available -> {
                            if (segments.entries.isEmpty()) return ExportWriteResult.Failure(continuous.code)
                            segments.entries.forEach { it.copyTo(zip, "audio/${it.fileName}") }
                            writeDisclosure(
                                zip = zip,
                                audioReasonCode = continuous.code,
                                warningCode = "export_audio_segments_used",
                                partial = request.audioPartial,
                                diagnosticCodes = request.audioDiagnosticCodes,
                            )
                            usedFallback = true
                            warnings += "export_audio_segments_used"
                        }
                        is ExportAudioResult.Unavailable -> return ExportWriteResult.Failure(continuous.code)
                    }
                }
            }
        }
        return success(output, usedFallback, warnings)
    }

    private fun writeDisclosure(
        zip: ZipOutputStream,
        audioReasonCode: String,
        warningCode: String,
        partial: Boolean,
        diagnosticCodes: List<String>,
    ) {
        val encodedDiagnostics = diagnosticCodes.joinToString(",") { "\"${jsonEscape(it)}\"" }
        val json =
            """{"schemaVersion":1,"warningCode":"${jsonEscape(warningCode)}","audioReasonCode":"${jsonEscape(audioReasonCode)}","partial":$partial,"diagnosticCodes":[$encodedDiagnostics]}"""
        zip.writeEntry("export-disclosure.json", json.byteInputStream(Charsets.UTF_8))
    }

    private fun ExportSourceEntry.copyTo(
        output: OutputStream,
        targetName: String? = null,
    ) {
        if (bytes < 0 || !isSafeFileName(fileName)) throw IOException("invalid source entry")
        if (targetName == null) {
            open().use { input -> input.copyExactlyTo(output, bytes) }
        } else {
            (output as ZipOutputStream).writeEntry(targetName, open(), bytes)
        }
    }

    private fun ZipOutputStream.writeEntry(
        name: String,
        input: InputStream,
        expectedBytes: Long? = null,
    ) {
        if (!isSafeEntryName(name)) throw IOException("invalid export entry")
        putNextEntry(ZipEntry(name).apply { time = 0L })
        input.use {
            if (expectedBytes == null) {
                it.copyTo(this)
            } else {
                it.copyExactlyTo(this, expectedBytes)
            }
        }
        closeEntry()
    }

    private fun InputStream.copyExactlyTo(
        output: OutputStream,
        expectedBytes: Long,
    ) {
        var remaining = expectedBytes
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        while (remaining > 0) {
            if (output is CountingOutputStream) output.checkCancellation()
            val read = read(buffer, 0, minOf(buffer.size.toLong(), remaining).toInt())
            if (read < 0) throw ExportSourceException("export_audio_source_truncated")
            if (read == 0) continue
            output.write(buffer, 0, read)
            remaining -= read
        }
    }

    private fun LocalExportRequest.isValid(): Boolean =
        operationId.matches(Regex("[A-Za-z0-9_-]{1,128}")) &&
            sessionId.isNotBlank() &&
            suggestedFileName.isNotBlank() &&
            mimeType.isNotBlank() &&
            documents.keys.all(::isSafeFileName) &&
            segmentPlan.zipWithNext().all { (first, second) -> first.sequence < second.sequence } &&
            segmentPlan.all {
                it.sequence >= 0 && it.committedBytes > 0 && isSafeRelativePath(it.relativePath)
            } &&
            audioDiagnosticCodes.all(::isSafeCode)

    private fun success(
        output: CountingOutputStream,
        usedSegmentFallback: Boolean = false,
        warningCodes: List<String> = emptyList(),
    ): ExportWriteResult {
        output.checkCancellation()
        return ExportWriteResult.Success(output.count, usedSegmentFallback, warningCodes)
    }

    private fun isSafeFileName(value: String): Boolean =
        value.isNotBlank() && value.none { it == '/' || it == '\\' || it.code < 0x20 }

    private fun isSafeEntryName(value: String): Boolean =
        value.isNotBlank() &&
            !value.startsWith('/') &&
            value.split('/').all { part -> part.isNotBlank() && part != "." && part != ".." }

    private fun isSafeRelativePath(value: String): Boolean =
        !value.startsWith('/') &&
            !value.contains('\\') &&
            value.split('/').all { part -> part.isNotBlank() && part != "." && part != ".." }

    private fun isSafeCode(value: String): Boolean = value.matches(Regex("[a-z0-9_]{1,128}"))

    private fun jsonEscape(value: String): String =
        buildString {
            value.forEach { character ->
                when (character) {
                    '\\' -> append("\\\\")
                    '"' -> append("\\\"")
                    else -> append(character)
                }
            }
        }

    private fun CountingOutputStream.writeBounded(bytes: ByteArray) {
        var offset = 0
        while (offset < bytes.size) {
            checkCancellation()
            val length = minOf(DEFAULT_BUFFER_SIZE, bytes.size - offset)
            write(bytes, offset, length)
            offset += length
        }
    }
}

private class ExportSourceException(
    val code: String,
) : IOException(code)

private class CountingOutputStream(
    output: OutputStream,
    private val control: ExportWriteControl,
) : FilterOutputStream(output) {
    var count: Long = 0
        private set

    var totalBytes: Long? = null
        set(value) {
            field = value
            control.onProgress(count, value)
        }

    fun checkCancellation() {
        if (control.isCancellationRequested()) {
            throw ExportSourceException("export_cancelled")
        }
    }

    override fun write(value: Int) {
        checkCancellation()
        out.write(value)
        count += 1
        control.onProgress(count, totalBytes)
    }

    override fun write(
        bytes: ByteArray,
        offset: Int,
        length: Int,
    ) {
        checkCancellation()
        out.write(bytes, offset, length)
        count += length
        control.onProgress(count, totalBytes)
    }
}
