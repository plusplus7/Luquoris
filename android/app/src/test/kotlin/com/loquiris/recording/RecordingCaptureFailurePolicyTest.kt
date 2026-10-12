package com.loquiris.recording

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingCaptureFailurePolicyTest {
    @Test
    fun `only a failed capture pipeline requires service recovery`() {
        assertTrue(RecordingCaptureFailurePolicy.requiresRecovery(RecordingCapturePipelineState.failed))
        assertFalse(RecordingCaptureFailurePolicy.requiresRecovery(RecordingCapturePipelineState.recording))
        assertFalse(RecordingCaptureFailurePolicy.requiresRecovery(RecordingCapturePipelineState.paused))
        assertFalse(RecordingCaptureFailurePolicy.requiresRecovery(RecordingCapturePipelineState.finished))
    }
}
