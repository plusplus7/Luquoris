package com.loquiris.transcription

data class RefinementAudioInspectionRequest(val meetingId: String, val expectedSha256: String?)

/** Mirror of MethodChannelRefinementAudioService; no audio paths/text on the wire. */
object RefinementAudioChannelContract {
    const val channelName = "com.loquiris/refinement_audio_v1"
    private val identifier = Regex("[A-Za-z0-9][A-Za-z0-9._-]{0,127}")
    private val hash = Regex("[0-9a-f]{64}")
    private val code = Regex("[a-z][a-z0-9_]{0,63}")

    fun parse(arguments: Any?): RefinementAudioInspectionRequest? {
        val map = arguments as? Map<*, *> ?: return null
        if (map["v"] != 1 || map.keys.any { it !in setOf("v", "meetingId", "expectedSha256") }) return null
        val meetingId = map["meetingId"] as? String ?: return null
        if (!identifier.matches(meetingId)) return null
        val expected = map["expectedSha256"]
        if (expected != null && (expected !is String || !hash.matches(expected))) return null
        return RefinementAudioInspectionRequest(meetingId, expected as String?)
    }

    fun response(meetingId: String, result: RefinementAudioInventoryResult): Map<String, Any?> = when (result) {
        is RefinementAudioInventoryResult.Ready -> mapOf(
            "v" to 1, "ok" to true, "meetingId" to meetingId,
            "inventory" to mapOf("sha256" to result.sha256, "totalSamples" to result.audio.totalSamples,
                "sampleRateHz" to result.audio.sampleRateHz, "segmentCount" to result.audio.segments.size,
                "segments" to result.audio.segments.map { segment -> mapOf(
                    "index" to segment.index, "startSample" to segment.startSample,
                    "committedSamples" to segment.committedSamples, "committedBytes" to segment.committedBytes,
                    "sha256" to segment.verifiedSha256, "referenceSha256" to result.referenceHashes.getOrNull(segment.index),
                ) }),
        )
        is RefinementAudioInventoryResult.Failure -> failure(meetingId, result.code)
        is RefinementAudioInventoryResult.Deferred -> failure(meetingId, result.code, "deferred")
        RefinementAudioInventoryResult.Cancelled -> failure(meetingId, "refinement_audio_cancelled", "cancelled")
    }

    fun failure(meetingId: String?, failureCode: String, kind: String = "unavailable"): Map<String, Any?> = mapOf(
        "v" to 1, "ok" to false, "meetingId" to meetingId,
        "failure" to mapOf("kind" to kind, "code" to if (code.matches(failureCode)) failureCode else "refinement_audio_unavailable"),
    )
}
