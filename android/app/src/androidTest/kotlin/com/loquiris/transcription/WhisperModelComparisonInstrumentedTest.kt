package com.loquiris.transcription

import android.os.Build
import android.os.SystemClock
import androidx.test.core.app.ApplicationProvider
import com.loquiris.BuildConfig
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Development-only paired inference on identical, authorized local PCM. */
class WhisperModelComparisonInstrumentedTest {
    @Test
    fun bothModelsTranscribeTheSameFixtureAndReleaseHandles() {
        assertTrue("Build with LOQUIRIS_EXPERIMENTAL_SMALL=true", BuildConfig.DEBUG && BuildConfig.LOQUIRIS_EXPERIMENTAL_SMALL)
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val wav = context.assets.open("flutter_assets/assets/benchmarks/audio/zh_en_mixed_v1.wav").use { it.readBytes() }
        val pcm = comparisonPcm16Wav(wav)
        val native = JniWhisperNativeApi
        val measurements = JSONArray()
        for (spec in listOf(WhisperModelStore.REVIEWED_BASE_Q5_MODEL, WhisperModelStore.EXPERIMENTAL_SMALL_Q5_MODEL)) {
            val model = WhisperModelStore(context, spec).materialize() as ModelMaterializationResult.Ready
            val loadingStarted = SystemClock.elapsedRealtime()
            val contextHandle = native.createContext(model.file.absolutePath)
            assertTrue(native.lastErrorCode().orEmpty(), contextHandle != 0L)
            val loadingMs = SystemClock.elapsedRealtime() - loadingStarted
            val runHandle = native.createRun()
            assertTrue(native.lastErrorCode().orEmpty(), runHandle != 0L)
            var resultHandle = 0L
            try {
                val started = SystemClock.elapsedRealtime()
                resultHandle = native.transcribePcm(contextHandle, runHandle, pcm, 0, TranscriptionLanguageHint.mixed)
                val elapsedMs = SystemClock.elapsedRealtime() - started
                assertTrue(native.lastErrorCode().orEmpty(), resultHandle != 0L)
                assertTrue(native.segmentCount(resultHandle) > 0)
                val segments = JSONArray()
                val text = StringBuilder()
                var previousEnd = 0L
                repeat(native.segmentCount(resultHandle)) { index ->
                    val start = native.segmentStartMilliseconds(resultHandle, index)
                    val end = native.segmentEndMilliseconds(resultHandle, index)
                    val segmentText = native.segmentText(resultHandle, index)
                    assertTrue(start >= previousEnd && end >= start)
                    previousEnd = end
                    text.append(segmentText)
                    segments.put(JSONObject().put("startMs", start).put("endMs", end).put("text", segmentText))
                }
                assertTrue(text.isNotBlank())
                measurements.put(
                    JSONObject()
                        .put("modelId", spec.id)
                        .put("modelSha256", spec.sha256)
                        .put("modelBytes", spec.bytes)
                        .put("loadingMs", loadingMs)
                        .put("inferenceMs", elapsedMs)
                        .put("realTimeFactor", elapsedMs.toDouble() / 45_000.0)
                        .put("text", text.toString())
                        .put("segments", segments),
                )
            } finally {
                if (resultHandle != 0L) native.freeResult(resultHandle)
                native.freeRun(runHandle)
                native.freeContext(contextHandle)
            }
            assertEquals(NativeHandleCounts(0, 0, 0), native.activeHandleCounts())
        }
        val output = File(context.filesDir, "device-validation/whisper-small-comparison.json")
        output.parentFile!!.mkdirs()
        output.writeText(
            JSONObject()
                .put("schemaVersion", 1)
                .put("purpose", "experimentalModelComparisonNotAccuracyAcceptance")
                .put("observedAtUtcMs", System.currentTimeMillis())
                .put("deviceModel", Build.MODEL)
                .put("deviceFingerprint", Build.FINGERPRINT)
                .put("engineVersion", native.engineVersion())
                .put("languageHint", "mixed")
                .put("audioDurationMs", 45_000)
                .put("audioSha256", MessageDigest.getInstance("SHA-256").digest(wav).joinToString("") { "%02x".format(it) })
                .put("measurements", measurements)
                .put("accuracyReferenceAvailable", false)
                .put("allNativeHandlesReleased", true)
                .toString(2) + "\n",
        )
    }
}

private fun comparisonPcm16Wav(bytes: ByteArray): ShortArray {
    val marker = "data".toByteArray()
    val offset = bytes.indices.firstOrNull { index ->
        index + 8 <= bytes.size && bytes.copyOfRange(index, index + 4).contentEquals(marker)
    } ?: error("WAV data chunk missing")
    val length = ByteBuffer.wrap(bytes, offset + 4, 4).order(ByteOrder.LITTLE_ENDIAN).int
    require(length >= 0 && offset + 8 + length <= bytes.size && length % 2 == 0)
    val samples = ShortArray(length / 2)
    ByteBuffer.wrap(bytes, offset + 8, length).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().get(samples)
    return samples
}
