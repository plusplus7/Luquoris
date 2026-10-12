package com.loquiris.recording

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.locks.LockSupport
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Production fan-out isolation check; not an AudioRecord, AAC, or long-run benchmark. */
@RunWith(AndroidJUnit4::class)
class LiveInferenceIsolationInstrumentedTest {
    @Test
    fun stalledConsumerCannotBlockCanonicalFramesOrShutdown() {
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val exited = CountDownLatch(1)
        val sequences = mutableListOf<Long>()
        var payloadsMatch = true
        val timings = mutableListOf<Long>()
        val fanOut = PriorityPcmFanOut(25, 2, canonicalSink = { frame ->
            sequences.add(frame.sequence)
            if (!frame.copyBytes().contentEquals(payload(frame.sequence))) payloadsMatch = false
        })
        fanOut.replaceInferenceConsumer { _ ->
            entered.countDown()
            try {
                while (release.count > 0) {
                    try {
                        release.await()
                    } catch (_: InterruptedException) {
                        // Model an uninterruptible native decode.
                    }
                }
            } finally {
                exited.countDown()
            }
        }
        try {
            val started = System.nanoTime()
            repeat(250) { index ->
                val deadline = started + index * 20_000_000L
                while (System.nanoTime() < deadline) {
                    LockSupport.parkNanos(deadline - System.nanoTime())
                }
                val before = System.nanoTime()
                assertEquals(
                    PcmFanOutPublishResult.accepted,
                    fanOut.publish(PcmCaptureFrame(index.toLong(), payload(index.toLong()))),
                )
                timings.add((System.nanoTime() - before) / 1_000L)
                if (index == 0) assertTrue(entered.await(2, TimeUnit.SECONDS))
            }
            assertTrue(fanOut.awaitCanonicalProcessed(250, 2_000))
            val beforeShutdown = System.nanoTime()
            assertTrue(fanOut.shutdown())
            val shutdownMilliseconds = (System.nanoTime() - beforeShutdown) / 1_000_000L
            val metrics = fanOut.metrics
            val sorted = timings.sorted()
            val report = JSONObject()
                .put("fixture", "production_fan_out_stalled_consumer")
                .put("publishedFrames", 250)
                .put("canonicalProcessedFrames", metrics.canonicalProcessedFrames)
                .put("canonicalRejectedFrames", metrics.canonicalRejectedFrames)
                .put("canonicalPcmMatchesSource", payloadsMatch)
                .put("inferenceDroppedFrames", metrics.inferenceDroppedFrames)
                .put("publishP95Microseconds", sorted[237])
                .put("publishMaxMicroseconds", sorted.last())
                .put("shutdownMilliseconds", shutdownMilliseconds)
                .put("limitation", "Synthetic paced PCM and memory sink; no AudioRecord, AAC, model or long-duration claim.")
            val output = InstrumentationRegistry.getArguments().getString("additionalTestOutputDir")
                ?.let(::File) ?: InstrumentationRegistry.getInstrumentation().targetContext.filesDir
            check(output.mkdirs() || output.isDirectory)
            File(output, "live-inference-isolation-report.json").writeText(report.toString(2))
            assertEquals((0L until 250L).toList(), sequences)
            assertTrue(payloadsMatch)
            assertEquals(0L, metrics.canonicalRejectedFrames)
            assertEquals(0L, metrics.canonicalSinkFailures)
            assertTrue(metrics.inferenceDroppedFrames > 0)
            assertEquals(1L, exited.count)
            assertTrue("shutdown took $shutdownMilliseconds ms", shutdownMilliseconds < 1_000)
        } finally {
            release.countDown()
            fanOut.close()
            assertTrue(exited.await(2, TimeUnit.SECONDS))
        }
    }

    private fun payload(sequence: Long) = ByteArray(640) { (sequence + it).toByte() }
}
