package com.loquiris.recording

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RecordingFailedMergeRecoveryInstrumentedTest {
    @Test
    fun failedMergeLeavesAuthenticCommittedSegmentsRecoverable() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val recordings = File(context.filesDir, "recording-failed-merge-instrumented").apply {
            deleteRecursively()
            check(mkdirs())
        }
        val sessionDirectory = File(recordings, "opaque-session")
        val created =
            AndroidAacSegmentEncoder.create(
                directory = sessionDirectory,
                sessionId = "instrumented-failed-merge",
                segmentationPolicy =
                    RecordingSegmentationPolicy(
                        commitFrames = 3,
                        commitGroupsPerSegment = 2,
                    ),
            ) as RecordingEncoderCreateResult.Success
        repeat(100) { frameIndex ->
            val pcm = ByteArray(640) { byteIndex -> ((frameIndex * 29 + byteIndex) and 0xff).toByte() }
            assertTrue(created.encoder.appendPcm(pcm) is RecordingEncoderCommandResult.Success)
        }
        assertTrue(created.encoder.finish() is RecordingEncoderCommandResult.Success)

        val manifest =
            (
                AtomicRecordingSegmentManifestStore(sessionDirectory).load()
                    as RecordingSegmentManifestDecodeResult.Success
            ).manifest
        val authoritativeFiles =
            buildList {
                add(File(sessionDirectory, AtomicRecordingSegmentManifestStore.MANIFEST_FILE_NAME))
                manifest.segments.forEach { segment ->
                    add(File(sessionDirectory, segment.dataFileName))
                    add(File(sessionDirectory, segment.journalFileName))
                }
            }
        val beforeFailure = authoritativeFiles.associateWith(File::readBytes)
        val rebuilder =
            RecordingM4aRebuilder(
                muxerFactory =
                    RecordingM4aMuxerFactory { output ->
                        FailingInstrumentedMuxer(output)
                    },
            )

        val failed = rebuilder.rebuild(sessionDirectory)

        assertEquals(
            RecordingM4aRebuildResult.Failure("recording_m4a_mux_failed"),
            failed,
        )
        assertFalse(File(sessionDirectory, "${RecordingM4aRebuilder.OUTPUT_FILE_NAME}.tmp").exists())
        beforeFailure.forEach { (file, bytes) ->
            assertTrue("authoritative file disappeared: ${file.name}", file.isFile)
            assertArrayEquals("authoritative file changed: ${file.name}", bytes, file.readBytes())
        }

        val inventory = RecordingStartupReconciler(recordings).scan()
        val recovered = inventory.sessions.single()
        assertEquals(RecordingRecoveryIntegrityState.complete, recovered.integrityState)
        assertTrue(recovered.diagnostics.isEmpty())
        assertTrue(recovered.rawExportSegments.isNotEmpty())
        assertEquals(
            recovered.segments.filter { it.state == RecordingRecoverySegmentState.committed }.sumOf {
                it.committedBytes
            },
            recovered.rawExportSegments.sumOf(RecordingRawSegmentExportEntry::committedBytes),
        )
        assertTrue(RecordingM4aRebuilder().rebuild(sessionDirectory) is RecordingM4aRebuildResult.Success)
        recordings.deleteRecursively()
    }
}

private class FailingInstrumentedMuxer(
    private val output: File,
) : RecordingM4aMuxer {
    override fun start(format: RecordingM4aFormat) {
        output.writeBytes(byteArrayOf(0x4c, 0x51))
    }

    override fun writeSample(
        accessUnit: ByteArray,
        presentationTimeMicroseconds: Long,
    ) {
        output.appendBytes(accessUnit.take(4).toByteArray())
        error("injected instrumented mux failure")
    }

    override fun finish() = Unit

    override fun close() = Unit
}
