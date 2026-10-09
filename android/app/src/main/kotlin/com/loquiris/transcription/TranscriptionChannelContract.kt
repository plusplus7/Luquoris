package com.loquiris.transcription

enum class TranscriptionLanguageHint {
    chinese,
    english,
    mixed,
}

data class TranscriptionChannelRequest(
    val runId: String,
    val meetingId: String,
    val segmentReferences: List<String>,
    val modelId: String,
    val languageHint: TranscriptionLanguageHint,
    val parameterVersion: Int,
)

sealed interface TranscriptionChannelParseResult {
    data class Ready(
        val request: TranscriptionChannelRequest,
    ) : TranscriptionChannelParseResult

    data class Failure(
        val code: String,
    ) : TranscriptionChannelParseResult
}

sealed interface TranscriptionRunIdParseResult {
    data class Ready(
        val runId: String,
    ) : TranscriptionRunIdParseResult

    data class Failure(
        val code: String,
    ) : TranscriptionRunIdParseResult
}

object TranscriptionChannelContract {
    const val channelName = "com.loquiris/transcription_v1"
    const val eventChannelName = "com.loquiris/transcription_events_v1"
    const val version = 1
    const val supportedModelId = "whisper-base-q5_1"
    const val supportedParameterVersion = 1

    private val transcribeKeys =
        setOf(
            "v",
            "runId",
            "meetingId",
            "segmentReferences",
            "modelId",
            "languageHint",
            "parameterVersion",
        )
    private val cancelKeys = setOf("v", "runId")
    private val identifierPattern = Regex("[A-Za-z0-9._-]{1,128}")
    private val segmentNamePattern = Regex("segment-[0-9]{5,}\\.adts")
    private val safeWorkerFailureCodes =
        setOf(
            "transcription_cancelled",
            "transcription_model_directory_failed",
            "transcription_model_hash_mismatch",
            "transcription_model_load_failed",
            "transcription_model_manifest_invalid",
            "transcription_model_materialization_failed",
            "transcription_model_publish_failed",
            "transcription_native_failed",
            "transcription_native_inference_failed",
            "transcription_native_input_invalid",
            "transcription_native_invalid_handle",
            "transcription_native_out_of_memory",
            "transcription_native_unavailable",
            "transcription_audio_decode_failed",
            "transcription_audio_empty",
            "transcription_audio_format_unsupported",
            "transcription_audio_invalid",
            "transcription_audio_journal_invalid",
            "transcription_audio_journal_too_large",
            "transcription_audio_manifest_invalid",
            "transcription_audio_manifest_missing",
            "transcription_audio_meeting_invalid",
            "transcription_audio_meeting_mismatch",
            "transcription_audio_missing",
            "transcription_audio_path_invalid",
            "transcription_audio_read_failed",
            "transcription_audio_segment_corrupt",
            "transcription_audio_segment_missing",
            "transcription_audio_segment_open",
            "transcription_audio_segment_too_large",
            "transcription_audio_timeline_gap",
            "transcription_audio_track_missing",
            "transcription_audio_uncommitted_tail",
        )

    fun parseTranscribe(arguments: Any?): TranscriptionChannelParseResult {
        val values = arguments as? Map<*, *>
            ?: return TranscriptionChannelParseResult.Failure("transcription_request_invalid")
        versionFailure(values)?.let { return TranscriptionChannelParseResult.Failure(it) }
        if (values.keys != transcribeKeys) {
            return TranscriptionChannelParseResult.Failure("transcription_request_invalid")
        }
        val runId = values["runId"] as? String
        val meetingId = values["meetingId"] as? String
        val modelId = values["modelId"] as? String
        val parameterVersion = values["parameterVersion"] as? Int
        val languageHint =
            (values["languageHint"] as? String)?.let { raw ->
                TranscriptionLanguageHint.entries.firstOrNull { it.name == raw }
            }
        val rawReferences = values["segmentReferences"] as? List<*>
        if (!isSafeIdentifier(runId) ||
            !isSafeIdentifier(meetingId) ||
            !isSafeIdentifier(modelId) ||
            parameterVersion == null ||
            parameterVersion <= 0 ||
            languageHint == null ||
            rawReferences.isNullOrEmpty()
        ) {
            return TranscriptionChannelParseResult.Failure("transcription_request_invalid")
        }
        val references = rawReferences.filterIsInstance<String>()
        if (references.size != rawReferences.size || references.any { !isSafeSegmentReference(it) }) {
            return TranscriptionChannelParseResult.Failure("transcription_request_invalid")
        }
        return TranscriptionChannelParseResult.Ready(
            TranscriptionChannelRequest(
                runId = checkNotNull(runId),
                meetingId = checkNotNull(meetingId),
                segmentReferences = references.toList(),
                modelId = checkNotNull(modelId),
                languageHint = languageHint,
                parameterVersion = parameterVersion,
            ),
        )
    }

    fun parseCancel(arguments: Any?): TranscriptionRunIdParseResult {
        val values = arguments as? Map<*, *>
            ?: return TranscriptionRunIdParseResult.Failure("transcription_request_invalid")
        versionFailure(values)?.let { return TranscriptionRunIdParseResult.Failure(it) }
        val runId = values["runId"] as? String
        if (values.keys != cancelKeys || !isSafeIdentifier(runId)) {
            return TranscriptionRunIdParseResult.Failure("transcription_request_invalid")
        }
        return TranscriptionRunIdParseResult.Ready(checkNotNull(runId))
    }

    fun completed(
        runId: String,
        result: PostSessionTranscriptionResult.Completed,
    ): Map<String, Any?> =
        mapOf(
            "v" to version,
            "ok" to true,
            "runId" to runId,
            "result" to
                mapOf(
                    "engineVersion" to result.engineVersion,
                    "warningCode" to result.warningCode,
                    "chunks" to
                        result.segments.map { segment ->
                            mapOf(
                                "segmentId" to segment.id,
                                "startMilliseconds" to segment.startMilliseconds,
                                "endMilliseconds" to segment.endMilliseconds,
                                "rawText" to segment.rawText,
                                "displayText" to segment.displayText,
                                "stability" to "stable",
                            )
                        },
                ),
        )

    fun progress(
        runId: String,
        fraction: Double,
    ): Map<String, Any?> =
        mapOf(
            "v" to version,
            "runId" to runId,
            "type" to "progress",
            "fraction" to fraction,
            "remainingMilliseconds" to null,
        )

    fun cancelled(runId: String): Map<String, Any?> =
        mapOf(
            "v" to version,
            "ok" to true,
            "runId" to runId,
            "cancelled" to true,
        )

    fun failure(
        code: String,
        runId: String? = null,
    ): Map<String, Any?> =
        buildMap {
            put("v", version)
            put("ok", false)
            if (runId != null) put("runId", runId)
            put("failure", mapOf("code" to code))
        }

    fun safeWorkerFailureCode(code: String): String =
        code.takeIf(safeWorkerFailureCodes::contains) ?: "transcription_native_failed"

    private fun versionFailure(values: Map<*, *>): String? {
        val received = values["v"]
        return when {
            received !is Int -> "transcription_request_invalid"
            received != version -> "transcription_channel_version_unsupported"
            else -> null
        }
    }

    private fun isSafeIdentifier(value: String?): Boolean =
        value != null && identifierPattern.matches(value)

    private fun isSafeSegmentReference(value: String): Boolean {
        if (value.startsWith('/') || value.contains('\\')) return false
        val parts = value.split('/')
        return parts.size >= 3 &&
            parts.first() == "recordings" &&
            parts.none { it.isEmpty() || it == "." || it == ".." } &&
            segmentNamePattern.matches(parts.last())
    }
}
