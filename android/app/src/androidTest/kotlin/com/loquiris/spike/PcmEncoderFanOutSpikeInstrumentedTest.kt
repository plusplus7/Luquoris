package com.loquiris.spike

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class PcmEncoderFanOutSpikeInstrumentedTest {
    @Test
    fun stalledInferenceNeverBackpressuresConcurrentCanonicalEncoder() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext

        val report = PcmEncoderFanOutSpike().run()

        val reportJson = report.toJson()
        File(context.filesDir, REPORT_NAME).writeText(reportJson)
        InstrumentationRegistry.getArguments().getString("additionalTestOutputDir")?.let { outputPath ->
            val outputDirectory = File(outputPath)
            check(outputDirectory.mkdirs() || outputDirectory.isDirectory)
            File(outputDirectory, REPORT_NAME).writeText(reportJson)
        }
        assertEquals(800, report.publishedFrames)
        assertEquals(report.publishedFrames.toLong(), report.canonicalAcceptedFrames)
        assertEquals(report.publishedFrames.toLong(), report.canonicalProcessedFrames)
        assertEquals(0L, report.canonicalRejectedFrames)
        assertEquals(2L, report.inferenceAcceptedFrames)
        assertEquals(798L, report.inferenceDroppedFrames)
        assertTrue(report.canonicalPcmMatchesSource)
        assertTrue(report.encoderWasConcurrentCanonicalSink)
        assertEquals(25, report.canonicalQueueCapacity)
        assertTrue(
            "canonical queue high-water was ${report.canonicalQueueHighWaterMark}",
            report.canonicalQueueHighWaterMark in 1 until report.canonicalQueueCapacity,
        )
        assertEquals(0, report.canonicalSequenceGaps)
        assertEquals(0, report.producerMissedDeadlines)
        assertTrue(
            "paced producer took ${report.producerElapsedMilliseconds} ms",
            report.producerElapsedMilliseconds in 15_500L..17_000L,
        )
        assertTrue(
            "producer max lateness was ${report.producerMaxLatenessMicroseconds} us",
            report.producerMaxLatenessMicroseconds < 5_000L,
        )
        assertTrue("publish p95 was ${report.publishP95Microseconds} us", report.publishP95Microseconds < 5_000L)
        assertTrue("publish max was ${report.publishMaxMicroseconds} us", report.publishMaxMicroseconds < 15_000L)
        assertTrue("encoder coverage was ${report.encodedSampleCoverage}", report.encodedSampleCoverage in 0.98..1.02)
        assertTrue("decoder coverage was ${report.decodedSampleCoverage}", report.decodedSampleCoverage in 0.98..1.02)
        assertTrue(report.encodedAccessUnits > 0)
    }

    companion object {
        private const val REPORT_NAME = "pcm-encoder-fan-out-spike-report.json"
    }
}
