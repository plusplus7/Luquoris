package com.loquiris.recording

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidAacSegmentEncoderInstrumentedTest {
    @Test
    fun authenticAacIsCommittedBehindPublishedManifest() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val directory = File(context.filesDir, "recording-encoder-instrumented").apply { deleteRecursively() }
        val created =
            AndroidAacSegmentEncoder.create(
                directory = directory,
                sessionId = "instrumented-encoder",
                segmentationPolicy = RecordingSegmentationPolicy(commitFrames = 3, commitGroupsPerSegment = 2),
            )
        assertTrue(created is RecordingEncoderCreateResult.Success)
        val encoder = (created as RecordingEncoderCreateResult.Success).encoder

        repeat(50) { frameIndex ->
            val pcm =
                ByteArray(640) { byteIndex ->
                    ((frameIndex * 17 + byteIndex) and 0xff).toByte()
                }
            assertTrue(encoder.appendPcm(pcm) is RecordingEncoderCommandResult.Success)
        }
        assertTrue(encoder.finish() is RecordingEncoderCommandResult.Success)

        val snapshot = encoder.snapshot()
        assertEquals(16_000L, snapshot.inputSamples)
        assertTrue(snapshot.encodedAccessUnits > 0)
        assertTrue(snapshot.bytesWritten > 0)
        assertTrue(snapshot.codecName.isNotBlank())

        val manifest =
            (AtomicRecordingSegmentManifestStore(directory).load() as RecordingSegmentManifestDecodeResult.Success)
                .manifest
        assertTrue(manifest.codecSpecificData.isNotEmpty())
        assertTrue(manifest.segments.isNotEmpty())
        val recovered =
            manifest.segments.map { segment ->
                RecordingCommittedPrefixRecovery.recover(
                    File(directory, segment.dataFileName).readBytes(),
                    File(directory, segment.journalFileName).readBytes(),
                )
            }
        assertEquals(snapshot.encodedAccessUnits, recovered.sumOf(RecordingCommittedPrefix::committedFrames))
        assertTrue(recovered.all { it.committedSamples == it.committedFrames.toLong() * 1_024L })
        directory.deleteRecursively()
    }
}
