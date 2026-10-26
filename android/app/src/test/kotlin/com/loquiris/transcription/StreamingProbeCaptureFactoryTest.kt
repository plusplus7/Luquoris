package com.loquiris.transcription

import com.loquiris.recording.*
import org.junit.Assert.*
import org.junit.Test

class StreamingProbeCaptureFactoryTest {
    @Test fun throwingSourceCreatorCannotProveItReleasedAnUnreturnedNativeObject() {
        val factory = StreamingProbeCaptureFactory({ throw OutOfMemoryError("after native allocation") }, { Encoder() })
        assertTrue(runCatching { factory.create() }.isFailure)
        assertTrue(factory.releaseUncertain)
    }
    @Test fun throwingEncoderCreatorStillReleasesKnownSourceButRetainsUnknownAllocation() {
        val source = Source()
        val factory = StreamingProbeCaptureFactory({ source }, { throw LinkageError("after encoder allocation") })
        assertTrue(runCatching { factory.create() }.isFailure)
        assertTrue(source.released)
        assertTrue(factory.releaseUncertain)
    }
    @Test fun successfulPipelineAdoptionTransfersCleanupResponsibility() {
        val source = Source()
        val encoder = Encoder()
        val factory = StreamingProbeCaptureFactory({ source }, { encoder })
        val pipeline = runCatching { factory.create() }.getOrNull()
        try {
            assertNotNull(pipeline)
            assertFalse(factory.releaseUncertain)
            assertFalse(source.released)
            assertFalse(encoder.aborted)
        } finally { pipeline?.close() }
        assertTrue(source.released)
        assertTrue(encoder.aborted)
    }
    private class Source : PcmCaptureSource {
        var released = false
        override fun start() = true
        override fun stop() = true
        override fun read(target: ByteArray) = PcmCaptureSource.READ_STOPPED
        override fun timestampFramePosition(): Long? = null
        override fun release() { released = true }
    }
    private class Encoder : CanonicalPcmEncoder {
        var aborted = false
        override fun appendPcm(frame: PcmCaptureFrame) = true
        override fun finish() = true
        override fun abort() { aborted = true }
        override fun bytesWritten() = 0L
    }
}
