package com.loquiris.transcription

data class RefinementExecutionOwner(val meetingId: String, val runId: String)
data class RefinementChannelExecution(val owner: RefinementExecutionOwner, val execution: RefinementExecutionRequest)

/** Sole native owner of refinement_execution_v1; frozen profiles never select arbitrary assets. */
class RefinementExecutionChannelContract(private val allowExperimentalSmall: Boolean) {
    fun parse(arguments: Any?): RefinementChannelExecution? {
        val map = arguments as? Map<*, *> ?: return null
        if (map.keys != setOf("v", "meetingId", "runId", "audioInventorySha256", "engineVersion", "manifest", "parameters")) return null
        val owner = owner(map, exactKeys = false) ?: return null
        val hash = map["audioInventorySha256"] as? String ?: return null
        if (!digest.matches(hash) || map["engineVersion"] != "1.9.4") return null
        val parameters = map["parameters"] as? Map<*, *> ?: return null
        if (parameters.keys != setOf("executionMode", "requestedTiming", "languageHint", "parameterVersion") ||
            parameters["executionMode"] != "postSession" || parameters["parameterVersion"] != 1 ||
            parameters["requestedTiming"] !in setOf("live", "postSession")) return null
        val hint = when (parameters["languageHint"]) {
            "mixed" -> TranscriptionLanguageHint.mixed
            "chinese" -> TranscriptionLanguageHint.chinese
            "english" -> TranscriptionLanguageHint.english
            else -> return null
        }
        val manifest = map["manifest"] as? Map<*, *> ?: return null
        val spec = when (manifest["id"]) {
            "whisper-base-q5_1" -> WhisperModelStore.REVIEWED_BASE_Q5_MODEL
            "whisper-small-q5_1" -> if (allowExperimentalSmall) WhisperModelStore.EXPERIMENTAL_SMALL_Q5_MODEL else return null
            else -> return null
        }
        // StandardMessageCodec may choose Int or Long for an integral byte count.
        val bytes = manifest["bytes"]
        if (bytes !is Int && bytes !is Long) return null
        val canonical = manifest + ("bytes" to (bytes as Number).toLong())
        if (canonical != pinnedManifest(spec)) return null
        return RefinementChannelExecution(owner, RefinementExecutionRequest(owner.meetingId, hash, "1.9.4", spec, hint))
    }

    fun owner(arguments: Any?, exactKeys: Boolean = true): RefinementExecutionOwner? {
        val map = arguments as? Map<*, *> ?: return null
        if (map["v"] != 1 || (exactKeys && map.keys != setOf("v", "meetingId", "runId"))) return null
        val meeting = map["meetingId"] as? String ?: return null
        val run = map["runId"] as? String ?: return null
        if (!identifier.matches(meeting) || !identifier.matches(run)) return null
        return RefinementExecutionOwner(meeting, run)
    }

    fun failure(owner: RefinementExecutionOwner?, code: String, kind: String = "unavailable") = envelope(owner, false) +
        ("failure" to mapOf("kind" to kind, "code" to if (safeCode.matches(code)) code else "refinement_execution_failed"))

    fun success(owner: RefinementExecutionOwner) = envelope(owner, true)

    fun response(owner: RefinementExecutionOwner, result: RefinementExecutionResult): Map<String, Any?> = when (result) {
        is RefinementExecutionResult.Completed -> success(owner) + mapOf(
            "engineVersion" to result.output.engineVersion,
            "segments" to result.output.segments.map { segment -> mapOf(
                "id" to segment.id, "startMs" to segment.startMilliseconds, "endMs" to segment.endMilliseconds,
                "rawText" to segment.rawText, "displayText" to segment.displayText,
            ) },
        )
        is RefinementExecutionResult.Deferred -> failure(owner, result.code, "deferred")
        is RefinementExecutionResult.Failure -> failure(owner, result.code)
        RefinementExecutionResult.Cancelled -> failure(owner, "refinement_execution_cancelled", "cancelled")
    }

    private fun envelope(owner: RefinementExecutionOwner?, ok: Boolean) = mapOf<String, Any?>(
        "v" to 1, "ok" to ok, "meetingId" to owner?.meetingId, "runId" to owner?.runId,
    )

    private fun pinnedManifest(spec: ModelArtifactSpec): Map<String, Any?> = mapOf(
        "schemaVersion" to 1, "id" to spec.id, "version" to revision,
        "source" to "https://huggingface.co/ggerganov/whisper.cpp/resolve/$revision/${spec.assetPath.substringAfterLast('/')}",
        "artifactPath" to spec.assetPath, "sha256" to spec.sha256, "bytes" to spec.bytes,
        "runtime" to mapOf("engineId" to "whisper_cpp", "modelFormat" to "ggml"),
        "license" to mapOf("id" to "MIT", "snapshotPath" to "models/licenses/openai-whisper-model-MIT.txt"),
        "capabilities" to listOf("transcription"), "enabledModes" to listOf("postSession"),
    )

    companion object {
        const val channelName = "com.loquiris/refinement_execution_v1"
        private const val revision = "f281eb45af861ab5e5297d23694b7d46e090c02c"
        private val identifier = Regex("[A-Za-z0-9][A-Za-z0-9._-]{0,127}")
        private val digest = Regex("[0-9a-f]{64}")
        private val safeCode = Regex("[a-z][a-z0-9_]{0,63}")
    }
}
