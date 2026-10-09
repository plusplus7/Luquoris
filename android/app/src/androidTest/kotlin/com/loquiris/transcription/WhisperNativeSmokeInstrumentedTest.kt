package com.loquiris.transcription

import androidx.test.core.app.ApplicationProvider
import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WhisperNativeSmokeInstrumentedTest {
    @Test
    fun invalidModelFailsStablyWithoutLeakingHandles() {
        val native = JniWhisperNativeApi

        val contextHandle = native.createContext("/data/local/tmp/loquiris-model-does-not-exist.bin")

        assertEquals(0L, contextHandle)
        assertEquals("transcription_model_load_failed", native.lastErrorCode())
        assertEquals(NativeHandleCounts(0, 0, 0), native.activeHandleCounts())
    }

    @Test
    fun fixedAuthorizedWavProducesMonotonicTextAndReleasesHandles() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val model = WhisperModelStore(context).materialize() as ModelMaterializationResult.Ready
        val pcm =
            context.assets.open("flutter_assets/assets/benchmarks/audio/zh_en_mixed_v1.wav").use { input ->
                decodePcm16Wav(input.readBytes())
            }
        val native = JniWhisperNativeApi
        val contextHandle = native.createContext(model.file.absolutePath)
        assertTrue(native.lastErrorCode().orEmpty(), contextHandle != 0L)
        val runHandle = native.createRun()
        assertTrue(native.lastErrorCode().orEmpty(), runHandle != 0L)
        var resultHandle = 0L
        try {
            resultHandle = native.transcribePcm(contextHandle, runHandle, pcm, 0)
            assertTrue(native.lastErrorCode().orEmpty(), resultHandle != 0L)
            assertTrue(native.segmentCount(resultHandle) > 0)
            var previousEnd = 0L
            var visibleText = false
            repeat(native.segmentCount(resultHandle)) { index ->
                val start = native.segmentStartMilliseconds(resultHandle, index)
                val end = native.segmentEndMilliseconds(resultHandle, index)
                assertTrue(start >= previousEnd)
                assertTrue(end >= start)
                visibleText = visibleText || native.segmentText(resultHandle, index).isNotBlank()
                previousEnd = end
            }
            assertTrue(visibleText)
            assertEquals("1.9.4", native.engineVersion())
        } finally {
            if (resultHandle != 0L) native.freeResult(resultHandle)
            native.freeRun(runHandle)
            native.freeContext(contextHandle)
        }
        assertEquals(NativeHandleCounts(0, 0, 0), native.activeHandleCounts())
    }
}

private fun decodePcm16Wav(bytes: ByteArray): ShortArray {
    val dataMarker = "data".toByteArray()
    val offset = bytes.indices.firstOrNull { index ->
        index + 8 <= bytes.size && bytes.copyOfRange(index, index + 4).contentEquals(dataMarker)
    } ?: error("WAV data chunk missing")
    val length = ByteBuffer.wrap(bytes, offset + 4, 4).order(ByteOrder.LITTLE_ENDIAN).int
    val pcmOffset = offset + 8
    require(length >= 0 && pcmOffset + length <= bytes.size && length % 2 == 0)
    val samples = ShortArray(length / 2)
    ByteBuffer.wrap(bytes, pcmOffset, length).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().get(samples)
    return samples
}
