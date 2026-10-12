package com.loquiris.recording

import android.media.MediaExtractor
import android.media.MediaFormat
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.nio.ByteBuffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RecordingM4aRebuilderInstrumentedTest {
    @Test
    fun authenticSegmentsRebuildIntoOneContinuousM4aTimeline() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val directory = File(context.filesDir, "recording-m4a-rebuilder-instrumented").apply {
            deleteRecursively()
        }
        val created =
            AndroidAacSegmentEncoder.create(
                directory = directory,
                sessionId = "instrumented-m4a-rebuild",
                segmentationPolicy = RecordingSegmentationPolicy(commitFrames = 3, commitGroupsPerSegment = 2),
            ) as RecordingEncoderCreateResult.Success
        repeat(100) { frameIndex ->
            val pcm = ByteArray(640) { byteIndex -> ((frameIndex * 17 + byteIndex) and 0xff).toByte() }
            assertTrue(created.encoder.appendPcm(pcm) is RecordingEncoderCommandResult.Success)
        }
        assertTrue(created.encoder.finish() is RecordingEncoderCommandResult.Success)

        val rebuilt = RecordingM4aRebuilder().rebuild(directory)

        assertTrue("rebuild result was $rebuilt", rebuilt is RecordingM4aRebuildResult.Success)
        rebuilt as RecordingM4aRebuildResult.Success
        assertTrue(rebuilt.accessUnitCount > 1)
        assertTrue(rebuilt.bytesWritten > 0L)
        val output = File(directory, rebuilt.fileName)
        val sampleTimes = extractSampleTimes(output)
        assertEquals(rebuilt.accessUnitCount, sampleTimes.size)
        assertEquals(0L, sampleTimes.first())
        assertTrue(sampleTimes.zipWithNext().all { (first, second) -> second > first })
        assertTrue(
            sampleTimes.withIndex().all { (index, timestamp) -> timestamp == index * 64_000L },
        )
        directory.deleteRecursively()
    }

    private fun extractSampleTimes(output: File): List<Long> {
        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(output.absolutePath)
            val track =
                (0 until extractor.trackCount).first { index ->
                    extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME) ==
                        MediaFormat.MIMETYPE_AUDIO_AAC
                }
            extractor.selectTrack(track)
            val buffer = ByteBuffer.allocate(64 * 1_024)
            buildList {
                while (true) {
                    buffer.clear()
                    if (extractor.readSampleData(buffer, 0) < 0) break
                    add(extractor.sampleTime)
                    extractor.advance()
                }
            }
        } finally {
            extractor.release()
        }
    }
}
