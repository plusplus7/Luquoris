package com.loquiris.spike

import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class AacAdtsRecoverySpikeInstrumentedTest {
    @Test
    fun decodesOnlyTheDurablyCommittedPrefixOfAuthenticAacFrames() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext

        val report = AacAdtsRecoverySpike().run(context.cacheDir)

        File(context.filesDir, REPORT_NAME).writeText(report.toJson())
        Log.i(TAG, "diagnostic report written: $REPORT_NAME")
        assertTrue("encoder emitted no authentic AAC: ${report.toJson()}", report.encodedAccessUnits > 1)
        assertEquals(
            "recovery lost committed AAC or included the uncommitted tail: ${report.toJson()}",
            report.encodedAccessUnits - 1,
            report.recoveredAccessUnits,
        )
        assertEquals(
            "durable byte accounting does not close: ${report.toJson()}",
            report.durableDataBytes,
            report.recoveredDataBytes + report.discardedTailBytes,
        )
        assertTrue(
            "recovered payload differs from the encoded committed prefix: ${report.toJson()}",
            report.recoveredPayloadsMatchEncodedPrefix,
        )
        assertTrue("recovered AAC decoded too little PCM: ${report.toJson()}", report.decodedSampleCoverage >= 0.90)
        assertTrue("recovered AAC decoded too much PCM: ${report.toJson()}", report.decodedSampleCoverage <= 1.10)
        assertTrue("recovered AAC decoded to silence: ${report.toJson()}", report.decodedRms > 100.0)
        assertEquals(2, report.encoderAudioObjectType)
        assertEquals(16_000, report.encoderSampleRateHz)
        assertEquals(1, report.encoderChannelConfiguration)
        assertTrue("encoder CSD is absent: ${report.toJson()}", report.encoderAudioSpecificConfigHex.isNotEmpty())
        assertEquals("1408", report.recoveryAudioSpecificConfigHex)
        assertEquals(16_000, report.decoderSampleRateHz)
        assertEquals(1, report.decoderChannelCount)
    }

    companion object {
        private const val TAG = "LoquirisAacRecovery"
        private const val REPORT_NAME = "aac-adts-recovery-report.json"
    }
}
