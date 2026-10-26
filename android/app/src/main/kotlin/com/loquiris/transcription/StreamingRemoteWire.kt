package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame

/** Shared by both Kotlin processes. No Dart channel or native handle crosses it. */
object StreamingRemoteWire {
    private val headerKeys = setOf("v", "type", "run", "epoch")

    fun encodeRemoteCommand(command: StreamingRemoteCommand): Map<String, Any> {
        val wire = when (command) {
            is StreamingRemoteCommand.Open -> remoteHeader(command.owner, "open") + ("bundle" to command.bundleDigest)
            is StreamingRemoteCommand.Close -> remoteHeader(command.owner, "close")
            is StreamingRemoteCommand.Finish -> remoteHeader(command.owner, "finish") + ("request" to command.requestId)
            is StreamingRemoteCommand.Pcm -> remoteHeader(command.owner, "pcm") + mapOf(
                "request" to command.requestId, "sequence" to command.frame.sequence,
                "start" to requireNotNull(command.frame.canonicalStartSample), "captureEpoch" to command.frame.captureEpoch,
                "pcm" to command.frame.copyBytes(),
            )
        }
        require(decodeRemoteCommand(wire) != null) { "invalid_streaming_command" }
        return wire
    }

    fun decodeRemoteCommand(value: Map<String, Any?>): StreamingRemoteCommand? {
        val owner = remoteIdentity(value) ?: return null
        return when (value["type"]) {
            "open" -> {
                if (value.keys != headerKeys + "bundle") return null
                val bundle = value["bundle"] as? String ?: return null
                if (!bundle.matches(Regex("[a-f0-9]{64}"))) return null
                StreamingRemoteCommand.Open(owner, bundle)
            }
            "close" -> if (value.keys == headerKeys) StreamingRemoteCommand.Close(owner) else null
            "finish" -> {
                if (value.keys != headerKeys + "request") return null
                val request = value["request"] as? Long ?: return null
                if (request < 0) return null
                StreamingRemoteCommand.Finish(owner, request)
            }
            "pcm" -> {
                if (value.keys != headerKeys + setOf("request", "sequence", "start", "captureEpoch", "pcm")) return null
                val request = value["request"] as? Long ?: return null
                val sequence = value["sequence"] as? Long ?: return null
                val start = value["start"] as? Long ?: return null
                val captureEpoch = value["captureEpoch"] as? Long ?: return null
                val pcm = value["pcm"] as? ByteArray ?: return null
                if (request < 0 || sequence < 0 || start < 0 || captureEpoch < 0 || pcm.size !in 2..32000 || pcm.size % 2 != 0 || start > Long.MAX_VALUE - pcm.size / 2) return null
                StreamingRemoteCommand.Pcm(owner, request, PcmCaptureFrame(sequence, pcm, start, captureEpoch))
            }
            else -> null
        }
    }

    fun encodeRemoteReply(reply: StreamingRemoteReply): Map<String, Any> {
        val wire = when (reply) {
            is StreamingRemoteReply.Ready -> remoteHeader(reply.owner, "ready")
            is StreamingRemoteReply.Released -> remoteHeader(reply.owner, "released")
            is StreamingRemoteReply.Text -> remoteHeader(reply.owner, "text") + mapOf("request" to reply.requestId, "text" to reply.text, "endpoint" to reply.endpoint)
            is StreamingRemoteReply.Failure -> remoteHeader(reply.owner, "failure") + ("cause" to reply.cause.name)
            is StreamingRemoteReply.Rejected -> remoteHeader(reply.owner, "rejected") + ("cause" to reply.cause.name)
        }
        require(decodeRemoteReply(wire) != null) { "invalid_streaming_reply" }
        return wire
    }

    fun decodeRemoteReply(value: Map<String, Any?>): StreamingRemoteReply? {
        val owner = remoteIdentity(value) ?: return null
        return when (value["type"]) {
            "ready" -> if (value.keys == headerKeys) StreamingRemoteReply.Ready(owner) else null
            "released" -> if (value.keys == headerKeys) StreamingRemoteReply.Released(owner) else null
            "failure", "rejected" -> {
                if (value.keys != headerKeys + "cause") return null
                val cause = StreamingStopCause.entries.firstOrNull { it.name == value["cause"] } ?: return null
                if (value["type"] == "failure") StreamingRemoteReply.Failure(owner, cause) else StreamingRemoteReply.Rejected(owner, cause)
            }
            "text" -> {
                if (value.keys != headerKeys + setOf("request", "text", "endpoint")) return null
                val request = value["request"] as? Long ?: return null
                val text = value["text"] as? String ?: return null
                val endpoint = value["endpoint"] as? Boolean ?: return null
                if (request < 0 || text.length > 16000) return null
                StreamingRemoteReply.Text(owner, request, text, endpoint)
            }
            else -> null
        }
    }

    private fun remoteHeader(owner: StreamingRemoteIdentity, type: String): Map<String, Any> =
        mapOf("v" to 1, "type" to type, "run" to owner.runId, "epoch" to owner.epoch)

    private fun remoteIdentity(value: Map<String, Any?>): StreamingRemoteIdentity? {
        if (value["v"] != 1) return null
        val run = value["run"] as? String ?: return null
        val epoch = value["epoch"] as? String ?: return null
        if (run.isBlank() || run.length > 256 || epoch.isBlank() || epoch.length > 256) return null
        return StreamingRemoteIdentity(run, epoch)
    }
}
