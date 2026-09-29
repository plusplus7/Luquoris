package com.loquiris.spike

import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class AacCodecCapabilityProbeInstrumentedTest {
    @Test
    fun reportsAacLc64kEncoderAvailability() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext

        val report = AacCodecCapabilityProbe().run()

        File(context.filesDir, REPORT_NAME).writeText(report.toJson())
        Log.i(TAG, "diagnostic report written: $REPORT_NAME")
        assertTrue(
            "No AAC-LC encoder configured for 16 kHz mono at 64 kbit/s: ${report.toJson()}",
            report.targetAvailable,
        )
    }

    companion object {
        private const val TAG = "LoquirisAacSpike"
        private const val REPORT_NAME = "aac-codec-capability-report.json"
    }
}
