package com.loquiris.spike

import android.Manifest
import android.media.AudioFormat
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class AudioRecordSpikeInstrumentedTest {
    @get:Rule
    val microphonePermission: GrantPermissionRule =
        GrantPermissionRule.grant(Manifest.permission.RECORD_AUDIO)

    @Test
    fun capturesMono16kPcmAndWritesDiagnostics() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val pcmFile = File(context.cacheDir, "audio-record-spike.pcm")
        val reportFile = File(context.filesDir, "audio-record-spike-report.json")

        val result = AudioRecordSpike(context).capture(pcmFile, CAPTURE_MILLIS)

        assertTrue("capture failed: $result", result is AudioRecordSpikeResult.Success)
        val success = result as AudioRecordSpikeResult.Success
        assertEquals(PcmCapturePlan.SAMPLE_RATE_HZ, success.diagnostics.sampleRateHz)
        assertEquals(PcmCapturePlan.CHANNEL_COUNT, success.diagnostics.channelCount)
        assertEquals(AudioFormat.ENCODING_PCM_16BIT, success.diagnostics.encoding)
        assertEquals(
            PcmCapturePlan.SAMPLE_RATE_HZ.toLong() * 2 * CAPTURE_MILLIS / 1_000,
            success.diagnostics.capturedBytes,
        )
        assertEquals(success.diagnostics.capturedBytes, pcmFile.length())
        reportFile.writeText(success.diagnostics.toJson())
        Log.i(TAG, "diagnostic report written: ${reportFile.name}")
    }

    companion object {
        private const val TAG = "LoquirisAudioSpike"
        private const val CAPTURE_MILLIS = 3_000L
    }
}
