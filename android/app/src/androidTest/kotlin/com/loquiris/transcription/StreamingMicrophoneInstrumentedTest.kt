package com.loquiris.transcription

import android.Manifest
import android.content.pm.PackageManager
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.loquiris.BuildConfig
import com.loquiris.recording.*
import java.io.File
import java.util.UUID
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Explicitly authorized microphone input only; never resets application data. */
@RunWith(AndroidJUnit4::class)
class StreamingMicrophoneInstrumentedTest {
    @Test fun microphonePcmIsDurableAcrossStreamingPauseAndResume() {
        assumeTrue("requires explicit native-spike debug build", BuildConfig.LOQUIRIS_STREAMING_NATIVE_SPIKE)
        assumeTrue("requires fresh human microphone authorization",
            InstrumentationRegistry.getArguments().getString("authorizedMicrophone") == "true")
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        assertEquals(PackageManager.PERMISSION_GRANTED, context.checkSelfPermission(Manifest.permission.RECORD_AUDIO))
        val id = "streaming-mic-${UUID.randomUUID()}"
        val directory = File(context.filesDir, id)
        check(directory.mkdir()) // New directory only. Never overwrite/delete an earlier run.
        val ready = CountDownLatch(1)
        val failures = CopyOnWriteArrayList<StreamingStopCause>()
        val events = CopyOnWriteArrayList<StreamingCaptureEvent>()
        val owner = StreamingRemoteIdentity(id, UUID.randomUUID().toString())
        val binding = StreamingMessengerBinding(context, owner, "1".repeat(64),
            "com.loquiris.spike.StreamingNativeKernelProbeService",
            onFailure = { failures.add(it); ready.countDown() },
            onReply = { reply, _ -> if (reply is StreamingRemoteReply.Ready) ready.countDown() })
        val consumer = StreamingPcmConsumer(binding.session, { events.addAll(it) }, failures::add)
        var pipeline: RecordingCapturePipeline? = null
        var unownedSource: PcmCaptureSource? = null
        var unownedEncoder: AndroidAacSegmentEncoder? = null
        val finishWorker = Executors.newSingleThreadExecutor { task ->
            Thread(task, "streaming-mic-probe-finish").apply { isDaemon = true }
        }
        var originalFailure: Throwable? = null
        var assertionsPassed = false
        val controlMs = mutableListOf<Long>()
        try {
            assertTrue(binding.bindRemote())
            assertTrue(ready.await(20, TimeUnit.SECONDS))
            assertTrue("model creation failed: $failures", failures.isEmpty())
            val source = AndroidAudioRecordSource.create(context)
            assertTrue("AudioRecord creation failed", source is PcmCaptureSourceCreateResult.Success)
            unownedSource = (source as PcmCaptureSourceCreateResult.Success).source
            val encoder = AndroidAacSegmentEncoder.create(directory, id)
            assertTrue("AAC encoder creation failed", encoder is RecordingEncoderCreateResult.Success)
            unownedEncoder = (encoder as RecordingEncoderCreateResult.Success).encoder
            val active = RecordingCapturePipeline(
                unownedSource, AndroidCanonicalPcmEncoder(unownedEncoder))
            pipeline = active
            unownedSource = null
            unownedEncoder = null
            active.replaceInferenceConsumer(consumer)
            assertEquals(RecordingCaptureCommandResult.Success, active.start())
            Thread.sleep(10000)
            var before = SystemClock.elapsedRealtime()
            assertEquals(RecordingCaptureCommandResult.Success, active.pause())
            controlMs.add(SystemClock.elapsedRealtime() - before)
            awaitDrain(active)
            finishWorker.submit { consumer.finishBoundary(StreamingBoundaryReason.PAUSE) }.get(10, TimeUnit.SECONDS)
            val paused = active.snapshot()
            Thread.sleep(1000)
            assertEquals(paused.bytesWritten, active.snapshot().bytesWritten)
            before = SystemClock.elapsedRealtime()
            assertEquals(RecordingCaptureCommandResult.Success, active.resume())
            controlMs.add(SystemClock.elapsedRealtime() - before)
            Thread.sleep(10000)
            assertEquals(RecordingCaptureCommandResult.Success, active.pause())
            awaitDrain(active)
            finishWorker.submit { consumer.finishBoundary(StreamingBoundaryReason.STOP) }.get(10, TimeUnit.SECONDS)
            consumer.closeAsync().toCompletableFuture().get(10, TimeUnit.SECONDS)
            assertEquals(RecordingCaptureCommandResult.Success, active.finish())
            val snapshot = active.snapshot()
            assertEquals(RecordingCapturePipelineState.finished, snapshot.state)
            assertNull(snapshot.failureCode)
            assertEquals(0L, snapshot.fanOut.canonicalRejectedFrames)
            assertEquals(0L, snapshot.fanOut.canonicalSinkFailures)
            assertEquals(snapshot.fanOut.canonicalAcceptedFrames, snapshot.fanOut.canonicalProcessedFrames)
            assertEquals(0L, snapshot.fanOut.inferenceConsumerFailures)
            assertTrue(snapshot.bytesWritten > 0)
            assertTrue(AtomicRecordingSegmentManifestStore(directory).load() is RecordingSegmentManifestDecodeResult.Success)
            assertTrue("live inference failed: $failures", failures.isEmpty())
            assertTrue("microphone test requires actual speech before pause",
                events.filterIsInstance<StreamingCaptureText>().any { it.captureEpoch == 0L && it.rawText.isNotBlank() })
            assertTrue("microphone test requires actual speech after resume",
                events.filterIsInstance<StreamingCaptureText>().any { it.captureEpoch == 1L && it.rawText.isNotBlank() })
            assertTrue(events.filterIsInstance<StreamingCaptureGap>().any {
                it.reason == StreamingBoundaryReason.PAUSE && it.captureEpoch == 1L })
            assertTrue(binding.session.releaseAcknowledgement.toCompletableFuture().isDone)
            assertTrue("pause/resume feedback exceeded 500 ms: $controlMs", controlMs.all { it <= 500 })
            assertionsPassed = true
        } catch (failure: Throwable) {
            originalFailure = failure
            throw failure
        } finally {
            var cleanupFailure: Throwable? = null
            var cleanupFailed = false
            fun cleanupMicrophoneProbe(action: () -> Unit) {
                try { action() } catch (failure: Throwable) {
                    cleanupFailed = true
                    val primary = originalFailure ?: cleanupFailure
                    if (primary == null) cleanupFailure = failure
                    else if (primary !== failure) primary.addSuppressed(failure)
                }
            }
            cleanupMicrophoneProbe { pipeline?.close() }
            cleanupMicrophoneProbe { unownedSource?.release() }
            cleanupMicrophoneProbe { unownedEncoder?.abort() }
            cleanupMicrophoneProbe { consumer.closeAsync().toCompletableFuture().get(10, TimeUnit.SECONDS) }
            cleanupMicrophoneProbe { binding.closeBinding().toCompletableFuture().get(10, TimeUnit.SECONDS) }
            cleanupMicrophoneProbe { finishWorker.shutdownNow() }
            // No raw transcript/audio in logs. Keep this new AAC directory for inspection.
            cleanupMicrophoneProbe {
                val report = JSONObject().put("run", id).put("microphone", true)
                    .put("assertionsPassed", assertionsPassed)
                    .put("cleanupFailed", cleanupFailed)
                    .put("canonicalBytes", pipeline?.snapshot()?.bytesWritten ?: 0)
                    .put("controlMilliseconds", org.json.JSONArray(controlMs))
                    .put("textEvents", events.count { it is StreamingCaptureText })
                    .put("gapEvents", events.count { it is StreamingCaptureGap })
                    .put("failures", org.json.JSONArray(failures.map { it.name }))
                    .put("limitation", "Short native-pipeline smoke, not Dart/UI, accuracy or long-run qualification")
                File(directory, "probe-report.json").writeText(report.toString(2))
                println("streaming_microphone_report=$id/probe-report.json")
            }
            if (originalFailure == null) cleanupFailure?.let { throw it }
        }
    }

    private fun awaitDrain(pipeline: RecordingCapturePipeline) {
        val deadline = SystemClock.elapsedRealtime() + 5000
        while (SystemClock.elapsedRealtime() < deadline) {
            val metrics = pipeline.snapshot().fanOut
            if (metrics.canonicalProcessedFrames == metrics.canonicalAcceptedFrames &&
                metrics.inferenceProcessedFrames + metrics.inferenceDroppedFrames == metrics.inferenceAcceptedFrames) return
            Thread.sleep(20)
        }
        fail("paused pipeline did not settle its queued and in-flight frames")
    }
}
