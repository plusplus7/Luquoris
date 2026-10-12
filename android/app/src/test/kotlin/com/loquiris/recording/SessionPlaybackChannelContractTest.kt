package com.loquiris.recording

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class SessionPlaybackChannelContractTest {
    @Test
    fun `snapshot excludes app private file paths`() {
        val encoded =
            SessionPlaybackChannelContract.snapshot(
                SessionPlaybackSnapshot(
                    sessionId = "meeting-1",
                    state = SessionPlaybackState.ready,
                    positionMilliseconds = 0,
                    durationMilliseconds = 10_000,
                ),
            )

        val snapshot = encoded["snapshot"] as Map<*, *>
        assertEquals("meeting-1", snapshot["sessionId"])
        assertEquals("ready", snapshot["state"])
        assertEquals(10_000L, snapshot["durationMilliseconds"])
        assertFalse(snapshot.containsKey("path"))
    }
}
