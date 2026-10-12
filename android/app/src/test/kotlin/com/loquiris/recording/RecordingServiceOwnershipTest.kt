package com.loquiris.recording

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingServiceOwnershipTest {
    @Test
    fun `initial rejected request stops an unowned service`() {
        val ownership = RecordingServiceOwnership()

        assertTrue(ownership.shouldStopAfterRejectedStart())
    }

    @Test
    fun `running service rejects conflicting request without stopping owner`() {
        val ownership = RecordingServiceOwnership()
        assertTrue(ownership.claim("meeting-a"))

        assertFalse(ownership.claim("meeting-b"))
        assertFalse(ownership.shouldStopAfterRejectedStart())
        assertTrue(ownership.owns("meeting-a"))
    }

    @Test
    fun `repeated request for owned session is idempotent`() {
        val ownership = RecordingServiceOwnership()
        assertTrue(ownership.claim("meeting-a"))

        assertTrue(ownership.claim("meeting-a"))
        assertTrue(ownership.owns("meeting-a"))
    }

    @Test
    fun `failed owned start releases ownership so the service can stop`() {
        val ownership = RecordingServiceOwnership()
        assertTrue(ownership.claim("meeting-a"))

        assertTrue(ownership.release("meeting-a"))
        assertTrue(ownership.shouldStopAfterRejectedStart())
        assertFalse(ownership.owns("meeting-a"))
    }
}
