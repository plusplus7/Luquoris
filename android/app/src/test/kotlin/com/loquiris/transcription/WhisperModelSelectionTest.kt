package com.loquiris.transcription

import com.loquiris.BuildConfig
import org.junit.Assert.assertEquals
import org.junit.Test

class WhisperModelSelectionTest {
    @Test
    fun `native contract and materialization select the same debug gated model`() {
        val expected = if (BuildConfig.DEBUG && BuildConfig.LOQUIRIS_EXPERIMENTAL_SMALL) {
            WhisperModelStore.EXPERIMENTAL_SMALL_Q5_MODEL
        } else {
            WhisperModelStore.REVIEWED_BASE_Q5_MODEL
        }
        assertEquals(expected, WhisperModelStore.selectedModelSpec)
        assertEquals(expected.id, TranscriptionChannelContract.supportedModelId)
    }
}
