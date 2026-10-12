package com.loquiris.recording

class RecordingPermissionChannelController(
    private val hasPermission: () -> Boolean,
    private val requestPermission: () -> Unit,
) {
    private var pendingReply: ((Map<String, Any?>) -> Unit)? = null

    fun handle(
        method: String,
        arguments: Any?,
        reply: (Map<String, Any?>) -> Unit,
    ) {
        val values = arguments as? Map<*, *>
        if (values == null) {
            reply(RecordingChannelContract.failure("recording_channel_invalid"))
            return
        }
        if (values["v"] != RecordingChannelContract.version) {
            reply(RecordingChannelContract.failure("recording_channel_version_unsupported"))
            return
        }
        if (method != requestMethod) {
            reply(RecordingChannelContract.failure("recording_channel_method_unknown"))
            return
        }
        if (hasPermission()) {
            reply(success())
            return
        }
        if (pendingReply != null) {
            reply(RecordingChannelContract.failure("recording_permission_request_in_progress"))
            return
        }
        pendingReply = reply
        try {
            requestPermission()
        } catch (_: RuntimeException) {
            pendingReply = null
            reply(RecordingChannelContract.failure("recording_permission_request_failed"))
        }
    }

    fun complete(granted: Boolean): Boolean {
        val reply = pendingReply ?: return false
        pendingReply = null
        reply(
            if (granted) {
                success()
            } else {
                RecordingChannelContract.failure("recording_permission_denied")
            },
        )
        return true
    }

    fun close() {
        val reply = pendingReply ?: return
        pendingReply = null
        reply(RecordingChannelContract.failure("recording_permission_request_interrupted"))
    }

    private fun success(): Map<String, Any?> =
        mapOf(
            "v" to RecordingChannelContract.version,
            "ok" to true,
        )

    companion object {
        const val requestMethod = "requestMicrophonePermission"
        const val requestCode = 2108
    }
}
