package com.loquiris.recording

import android.Manifest
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RecordingCapturePipelineInstrumentedTest {
    @get:Rule
    val microphonePermission: GrantPermissionRule =
        GrantPermissionRule.grant(Manifest.permission.RECORD_AUDIO)

    @Test
    fun microphoneFramesAreDurablyEncodedAcrossPauseAndResume() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val directory = File(context.filesDir, "recording-pipeline-instrumented").apply { deleteRecursively() }
        val sourceResult = AndroidAudioRecordSource.create(context)
        val encoderResult = AndroidAacSegmentEncoder.create(directory, "pipeline-instrumented")
        assertTrue(sourceResult is PcmCaptureSourceCreateResult.Success)
        assertTrue(encoderResult is RecordingEncoderCreateResult.Success)
        val pipeline =
            RecordingCapturePipeline(
                source = (sourceResult as PcmCaptureSourceCreateResult.Success).source,
                encoder =
                    AndroidCanonicalPcmEncoder(
                        (encoderResult as RecordingEncoderCreateResult.Success).encoder,
                    ),
            )

        assertEquals(RecordingCaptureCommandResult.Success, pipeline.start())
        Thread.sleep(750)
        assertEquals(RecordingCaptureCommandResult.Success, pipeline.pause())
        val pausedFrames = pipeline.snapshot().fanOut.canonicalProcessedFrames
        Thread.sleep(250)
        assertEquals(pausedFrames, pipeline.snapshot().fanOut.canonicalProcessedFrames)
        assertEquals(RecordingCaptureCommandResult.Success, pipeline.resume())
        Thread.sleep(750)
        assertEquals(RecordingCaptureCommandResult.Success, pipeline.finish())

        val snapshot = pipeline.snapshot()
        assertEquals(RecordingCapturePipelineState.finished, snapshot.state)
        assertNull(snapshot.failureCode)
        assertTrue(snapshot.inputHealth.pcmBytes > 0)
        assertTrue(snapshot.fanOut.canonicalProcessedFrames > 0)
        assertEquals(0L, snapshot.fanOut.canonicalRejectedFrames)
        assertTrue(snapshot.bytesWritten > 0)
        val manifest = AtomicRecordingSegmentManifestStore(directory).load()
        assertTrue(manifest is RecordingSegmentManifestDecodeResult.Success)
        directory.deleteRecursively()
    }
}
