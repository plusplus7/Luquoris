package com.loquiris.recording

enum class SessionPlaybackState {
    ready,
    playing,
    paused,
    completed,
}

data class SessionPlaybackSnapshot(
    val sessionId: String,
    val state: SessionPlaybackState,
    val positionMilliseconds: Long,
    val durationMilliseconds: Long,
)

object SessionPlaybackChannelContract {
    const val channelName = "com.loquiris/session_playback_v1"
    const val version = 1

    fun snapshot(snapshot: SessionPlaybackSnapshot): Map<String, Any?> =
        mapOf(
            "v" to version,
            "ok" to true,
            "snapshot" to
                mapOf(
                    "sessionId" to snapshot.sessionId,
                    "state" to snapshot.state.name,
                    "positionMilliseconds" to snapshot.positionMilliseconds,
                    "durationMilliseconds" to snapshot.durationMilliseconds,
                ),
        )

    fun released(): Map<String, Any?> = mapOf("v" to version, "ok" to true)

    fun failure(code: String): Map<String, Any?> =
        mapOf(
            "v" to version,
            "ok" to false,
            "failure" to mapOf("code" to code),
        )
}
