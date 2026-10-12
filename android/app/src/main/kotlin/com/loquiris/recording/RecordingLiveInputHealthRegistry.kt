package com.loquiris.recording

/** Process-local bridge for throttled, non-authoritative microphone health. */
object RecordingLiveInputHealthRegistry {
    @Volatile
    private var current: Entry? = null

    fun publish(sessionId: String, snapshot: AudioInputHealthSnapshot) {
        current = Entry(sessionId, snapshot)
    }

    fun read(sessionId: String?): AudioInputHealthSnapshot? =
        current?.takeIf { it.sessionId == sessionId }?.snapshot

    fun clear(sessionId: String?) {
        if (current?.sessionId == sessionId) current = null
    }

    private data class Entry(
        val sessionId: String,
        val snapshot: AudioInputHealthSnapshot,
    )
}
