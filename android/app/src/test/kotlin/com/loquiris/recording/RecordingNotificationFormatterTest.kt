package com.loquiris.recording

import org.junit.Assert.assertEquals
import org.junit.Test

class RecordingNotificationFormatterTest {
    @Test
    fun `duration supports recordings longer than four hours`() {
        assertEquals("04:02:03", RecordingNotificationFormatter.duration(14_523_000L))
    }

    @Test
    fun `byte count uses stable binary units`() {
        assertEquals("0 B", RecordingNotificationFormatter.bytes(0))
        assertEquals("1.5 KiB", RecordingNotificationFormatter.bytes(1_536))
        assertEquals("2.0 MiB", RecordingNotificationFormatter.bytes(2L * 1_024L * 1_024L))
    }
}
