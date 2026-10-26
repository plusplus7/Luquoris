package com.loquiris.recording

import org.junit.Assert.*
import org.junit.Test

class RecordingPrioritySignalTest {
    @Test fun `capture ownership is visible before optional workers receive cancellation`() {
        var notifications = 0
        val observer = RecordingProcessLiveness.observeStarts {
            assertTrue(RecordingProcessLiveness.owns("priority-test"))
            notifications++
        }
        try {
            RecordingProcessLiveness.claim("priority-test")
            assertEquals(1, notifications)
            observer.close()
            observer.close()
            RecordingProcessLiveness.claim("priority-test")
            assertEquals(1, notifications)
        } finally {
            observer.close()
            RecordingProcessLiveness.release("priority-test")
        }
    }

    @Test fun `optional listener failure cannot prevent capture ownership or other cancellation`() {
        val broken = RecordingProcessLiveness.observeStarts { throw IllegalStateException("private") }
        var notified = false
        val healthy = RecordingProcessLiveness.observeStarts { notified = true }
        try {
            RecordingProcessLiveness.claim("priority-failure-test")
            assertTrue(RecordingProcessLiveness.owns("priority-failure-test"))
            assertTrue(notified)
        } finally {
            broken.close()
            healthy.close()
            RecordingProcessLiveness.release("priority-failure-test")
        }
    }
}
