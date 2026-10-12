package com.loquiris.recording

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingForegroundPromotionTest {
    @Test
    fun `platform promotion exception becomes failure`() {
        val promoted =
            RecordingForegroundPromotion.attempt(
                ForegroundPromoter { error("foreground start disallowed") },
            )

        assertFalse(promoted)
    }

    @Test
    fun `successful platform promotion is reported`() {
        var calls = 0

        val promoted = RecordingForegroundPromotion.attempt(ForegroundPromoter { calls += 1 })

        assertTrue(promoted)
        assertTrue(calls == 1)
    }
}
