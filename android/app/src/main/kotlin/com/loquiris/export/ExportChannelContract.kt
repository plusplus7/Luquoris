package com.loquiris.export

sealed interface ExportRequestDecodeResult {
    data class Success(
        val request: LocalExportRequest,
    ) : ExportRequestDecodeResult

    data class Failure(
        val code: String,
    ) : ExportRequestDecodeResult
}

sealed interface ExportOperationDecodeResult {
    data class Success(
        val operationId: String,
    ) : ExportOperationDecodeResult

    data class Failure(
        val code: String,
    ) : ExportOperationDecodeResult
}

enum class ExportProgressPhase {
    selectingDestination,
    preparing,
    writing,
    finalizing,
}

object ExportChannelContract {
    const val channelName = "com.loquiris/export_v1"
    const val requestCode = 0x4c51
    private const val version = 1
    private const val maxDocumentBytes = 16 * 1024 * 1024

    fun decodeRequest(arguments: Any?): ExportRequestDecodeResult {
        val values = arguments as? Map<*, *> ?: return invalid()
        if (values["v"] != version) return invalid()
        val operationId = values["operationId"] as? String ?: return invalid()
        val sessionId = values["sessionId"] as? String ?: return invalid()
        val formatName = values["format"] as? String ?: return invalid()
        val suggestedFileName = values["suggestedFileName"] as? String ?: return invalid()
        val mimeType = values["mimeType"] as? String ?: return invalid()
        val includeAudio = values["includeAudio"] as? Boolean ?: return invalid()
        val allowSegmentFallback = values["allowSegmentFallback"] as? Boolean ?: return invalid()
        val audioPartial = values["audioPartial"] as? Boolean ?: return invalid()
        val format = LocalExportFormat.entries.firstOrNull { it.name == formatName } ?: return invalid()
        val rawDocuments = values["documents"] as? Map<*, *> ?: return invalid()
        val rawSegmentPlan = values["segmentPlan"] as? List<*> ?: return invalid()
        val rawDiagnosticCodes = values["audioDiagnosticCodes"] as? List<*> ?: return invalid()
        if (
            !safeOperationId(operationId) ||
            sessionId.isBlank() || sessionId.toByteArray().size > 512 ||
            !safeFileName(suggestedFileName) || suggestedFileName.toByteArray().size > 255 ||
            mimeType.isBlank() || mimeType.length > 128 || rawDocuments.size > 8 ||
            rawSegmentPlan.size > 1024 || rawDiagnosticCodes.size > 64
        ) {
            return invalid()
        }
        val documents = linkedMapOf<String, String>()
        var totalBytes = 0L
        rawDocuments.forEach { (rawName, rawContent) ->
            val name = rawName as? String ?: return invalid()
            val content = rawContent as? String ?: return invalid()
            if (!safeFileName(name)) return invalid()
            totalBytes += content.toByteArray(Charsets.UTF_8).size
            if (totalBytes > maxDocumentBytes) return invalid()
            documents[name] = content
        }
        val segmentPlan = mutableListOf<ExportSegmentPlanEntry>()
        rawSegmentPlan.forEach { rawEntry ->
            val entry = rawEntry as? Map<*, *> ?: return invalid()
            val sequence = (entry["sequence"] as? Number)?.toInt() ?: return invalid()
            val relativePath = entry["relativePath"] as? String ?: return invalid()
            val committedBytes = (entry["committedBytes"] as? Number)?.toLong() ?: return invalid()
            if (sequence < 0 || committedBytes <= 0 || !safeRelativePath(relativePath)) return invalid()
            segmentPlan += ExportSegmentPlanEntry(sequence, relativePath, committedBytes)
        }
        if (segmentPlan.zipWithNext().any { (first, second) -> first.sequence >= second.sequence }) {
            return invalid()
        }
        val diagnosticCodes =
            rawDiagnosticCodes.map { rawCode ->
                val code = rawCode as? String ?: return invalid()
                if (!safeCode(code)) return invalid()
                code
            }
        return ExportRequestDecodeResult.Success(
            LocalExportRequest(
                operationId = operationId,
                sessionId = sessionId,
                format = format,
                suggestedFileName = suggestedFileName,
                mimeType = mimeType,
                documents = documents,
                includeAudio = includeAudio,
                allowSegmentFallback = allowSegmentFallback,
                segmentPlan = segmentPlan,
                audioPartial = audioPartial,
                audioDiagnosticCodes = diagnosticCodes,
            ),
        )
    }

    fun decodeOperation(arguments: Any?): ExportOperationDecodeResult {
        val values = arguments as? Map<*, *> ?: return operationInvalid()
        if (values["v"] != version) return operationInvalid()
        val operationId = values["operationId"] as? String ?: return operationInvalid()
        return if (safeOperationId(operationId)) {
            ExportOperationDecodeResult.Success(operationId)
        } else {
            operationInvalid()
        }
    }

    fun progress(
        operationId: String,
        phase: ExportProgressPhase,
        bytesProcessed: Long,
        totalBytes: Long?,
        cancellable: Boolean,
    ): Map<String, Any?> =
        mapOf(
            "v" to version,
            "ok" to true,
            "progress" to
                mapOf(
                    "operationId" to operationId,
                    "phase" to phase.name,
                    "bytesProcessed" to bytesProcessed,
                    "totalBytes" to totalBytes,
                    "cancellable" to cancellable,
                ),
        )

    fun acknowledged(): Map<String, Any> = mapOf("v" to version, "ok" to true)

    fun success(
        fileName: String,
        result: ExportWriteResult.Success,
    ): Map<String, Any> =
        mapOf(
            "v" to version,
            "ok" to true,
            "receipt" to
                mapOf(
                    "fileName" to fileName,
                    "bytesWritten" to result.bytesWritten,
                    "usedSegmentFallback" to result.usedSegmentFallback,
                    "warningCodes" to result.warningCodes,
                ),
        )

    fun failure(code: String): Map<String, Any> =
        mapOf(
            "v" to version,
            "ok" to false,
            "failure" to mapOf("code" to code),
        )

    private fun safeFileName(value: String): Boolean =
        value.isNotBlank() &&
            value != "." &&
            value != ".." &&
            !value.contains("..") &&
            value.none { it == '/' || it == '\\' || it.code < 0x20 }

    private fun safeRelativePath(value: String): Boolean =
        value.isNotBlank() &&
            !value.startsWith('/') &&
            !value.contains('\\') &&
            value.split('/').all { part -> part.isNotBlank() && part != "." && part != ".." }

    private fun safeCode(value: String): Boolean = value.matches(Regex("[a-z0-9_]{1,128}"))

    private fun safeOperationId(value: String): Boolean = value.matches(Regex("[A-Za-z0-9_-]{1,128}"))

    private fun invalid() = ExportRequestDecodeResult.Failure("export_request_invalid")

    private fun operationInvalid() = ExportOperationDecodeResult.Failure("export_request_invalid")
}
