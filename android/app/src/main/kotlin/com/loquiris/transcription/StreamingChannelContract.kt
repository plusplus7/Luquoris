package com.loquiris.transcription

data class StreamingPlatformOwner(val meetingId: String, val runId: String, val epoch: Long)
data class StreamingPlatformStart(val owner: StreamingPlatformOwner, val modelId: String, val bundleSha256: String, val parameterVersion: Int)
enum class StreamingPlatformCloseReason { STOPPED, CANCELLED, REPLACED }
data class StreamingPlatformClose(val owner: StreamingPlatformOwner, val reason: StreamingPlatformCloseReason)

/** Sole Android owner of streaming_v1; mirrored by streaming_channel_contract.dart. */
object StreamingChannelContract {
    const val channelName = "com.loquiris/streaming_v1"
    private val ownerKeys = setOf("v", "meetingId", "runId", "epoch")
    private val identifier = Regex("[A-Za-z0-9][A-Za-z0-9._-]{0,127}")
    private val hash = Regex("[a-f0-9]{64}")
    private const val maximumSample = Long.MAX_VALUE / 125

    fun decodeStart(raw: Any?): StreamingPlatformStart? {
        if (raw !is Map<*, *> || !keys(raw, ownerKeys + setOf("modelId", "bundleSha256", "parameterVersion"))) return null
        val owner = owner(raw) ?: return null
        val modelId = raw["modelId"] as? String ?: return null
        val digest = raw["bundleSha256"] as? String ?: return null
        if (!identifier.matches(modelId) || !hash.matches(digest) || long(raw["parameterVersion"]) != 1L) return null
        return StreamingPlatformStart(owner, modelId, digest, 1)
    }

    fun decodeClose(raw: Any?): StreamingPlatformClose? {
        if (raw !is Map<*, *> || !keys(raw, ownerKeys + "reason")) return null
        val owner = owner(raw) ?: return null
        val reason = when (raw["reason"]) {
            "stopped" -> StreamingPlatformCloseReason.STOPPED
            "cancelled" -> StreamingPlatformCloseReason.CANCELLED
            "replaced" -> StreamingPlatformCloseReason.REPLACED
            else -> return null
        }
        return StreamingPlatformClose(owner, reason)
    }

    fun encodeCapture(owner: StreamingPlatformOwner, identity: StreamingRemoteIdentity, event: StreamingCaptureEvent): Map<String, Any>? {
        if (!validOwner(owner) || identity.runId != owner.runId || event.owner != identity || event.sequence < 0 || event.sequence >= Long.MAX_VALUE - 1) return null
        val base = header(owner) + ("sequence" to event.sequence)
        val start: Long
        val end: Long
        val epoch: Long
        val fields = when (event) {
            is StreamingCaptureText -> {
                start = event.startSample; end = event.endSampleExclusive; epoch = event.captureEpoch
                if (end == start || !identifier.matches(event.utteranceId) || event.rawText.length > 16000) return null
                mapOf("type" to "text", "utteranceId" to event.utteranceId, "rawText" to event.rawText, "finalized" to event.finalized)
            }
            is StreamingCaptureGap -> {
                start = event.startSample; end = event.endSampleExclusive; epoch = event.captureEpoch
                val reason = when (event.reason) {
                    StreamingBoundaryReason.PAUSE -> "pause"
                    StreamingBoundaryReason.AUDIO_FOCUS -> "audioFocus"
                    StreamingBoundaryReason.DISCONTINUITY -> "discontinuity"
                    StreamingBoundaryReason.STOP -> return null
                }
                mapOf("type" to "gap", "reason" to reason)
            }
        }
        if (start < 0 || end < start || end > maximumSample || epoch < 0) return null
        return base + fields + mapOf("startSample" to start, "endSampleExclusive" to end, "captureEpoch" to epoch)
    }

    fun header(owner: StreamingPlatformOwner): Map<String, Any> = mapOf(
        "v" to 1, "meetingId" to owner.meetingId, "runId" to owner.runId, "epoch" to owner.epoch)

    private fun owner(raw: Map<*, *>): StreamingPlatformOwner? {
        if (long(raw["v"]) != 1L) return null
        val meeting = raw["meetingId"] as? String ?: return null
        val run = raw["runId"] as? String ?: return null
        val epoch = long(raw["epoch"]) ?: return null
        return StreamingPlatformOwner(meeting, run, epoch).takeIf(::validOwner)
    }

    private fun validOwner(owner: StreamingPlatformOwner): Boolean =
        identifier.matches(owner.meetingId) && identifier.matches(owner.runId) && owner.epoch >= 0

    private fun keys(raw: Map<*, *>, keys: Set<String>): Boolean =
        raw.size == keys.size && raw.keys.all { it is String && it in keys }

    private fun long(raw: Any?): Long? = when (raw) {
        is Int -> raw.toLong()
        is Long -> raw
        else -> null
    }
}
