package com.loquiris.spike

import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class AacRoundTripSpikeInstrumentedTest {
    @Test
    fun encodesAndDecodesDeterministicPcmAtTargetSettings() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext

        val report = AacRoundTripSpike().run()

        File(context.filesDir, REPORT_NAME).writeText(report.toJson())
        Log.i(TAG, "diagnostic report written: $REPORT_NAME")
        assertTrue("AAC encoder emitted no access units: ${report.toJson()}", report.accessUnitCount > 0)
        assertTrue("AAC encoder emitted no payload: ${report.toJson()}", report.encodedBytes > 0)
        assertTrue("AAC decoder emitted no PCM: ${report.toJson()}", report.decodedSamples > 0)
        assertTrue("AAC alignment search reached its limit: ${report.toJson()}", !report.alignmentSearchClipped)
        assertTrue("AAC round trip evaluated too little input: ${report.toJson()}", report.referenceCoverage >= 0.90)
        assertTrue(
            "AAC decoder returned too few samples: ${report.toJson()}",
            report.decodedToInputSampleRatio >= 0.90,
        )
        assertTrue(
            "AAC decoder returned too many samples: ${report.toJson()}",
            report.decodedToInputSampleRatio <= 1.10,
        )
        assertTrue("AAC decoder changed sample rate: ${report.toJson()}", report.decoderSampleRateHz == 16_000)
        assertTrue("AAC decoder changed channel count: ${report.toJson()}", report.decoderChannelCount == 1)
        assertTrue("AAC round-trip correlation is too low: ${report.toJson()}", report.correlation >= 0.75)
        assertTrue("AAC round-trip SNR is too low: ${report.toJson()}", report.signalToNoiseRatioDb >= 5.0)
    }

    companion object {
        private const val TAG = "LoquirisAacSpike"
        private const val REPORT_NAME = "aac-round-trip-report.json"
    }
}
