package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame
import org.junit.Assert.*
import org.junit.Test

class StreamingPcmKernelTest {
    @Test fun finishesBeforeExplicitGapWithoutReplayingMedia() {
        val native = RecordingNativeSession()
        val kernel = StreamingPcmKernel(native)
        kernel.decode(PcmCaptureFrame(0, ByteArray(4), 100, 3))
        assertEquals(StreamingRemoteResult.Text("尾部 API", true), kernel.finishUtterance())
        assertEquals(1, native.finishes)
        assertEquals(0, native.closes) // Same recognizer remains owned.
        for ((start, epoch) in listOf(101L to 4L, 200L to 2L)) {
            assertThrows(IllegalArgumentException::class.java) {
                kernel.decode(PcmCaptureFrame(1, ByteArray(4), start, epoch))
            }
        }
        kernel.decode(PcmCaptureFrame(9, ByteArray(4), 200, 4))
        assertEquals(2, native.accepted.size) // No silence fabricated for the media gap.
        assertEquals(StreamingRemoteResult.Text("尾部 API", true), kernel.finishUtterance())
        assertEquals(2, native.finishes)
        kernel.close()
    }

    @Test fun emptyBoundaryDoesNotInventNativeAudio() {
        val native = RecordingNativeSession()
        val kernel = StreamingPcmKernel(native)
        assertEquals(StreamingRemoteResult.Text("", true), kernel.finishUtterance())
        assertEquals(0, native.finishes)
        kernel.decode(PcmCaptureFrame(0, ByteArray(2), 500))
        assertEquals(StreamingRemoteResult.Text("尾部 API", true), kernel.finishUtterance())
        assertEquals(StreamingRemoteResult.Text("", true), kernel.finishUtterance())
        assertEquals(1, native.finishes)
        assertEquals(1, native.accepted.size)
        kernel.close()
        assertThrows(IllegalStateException::class.java) { kernel.finishUtterance() }
        assertEquals(1, native.finishes)
    }

    @Test fun failedFinishPoisonsFurtherInferenceButStillCloses() {
        val native = RecordingNativeSession(finishFailure = IllegalStateException("partially flushed"))
        val kernel = StreamingPcmKernel(native)
        kernel.decode(PcmCaptureFrame(0, ByteArray(2), 0))
        val first = assertThrows(IllegalStateException::class.java) { kernel.finishUtterance() }
        assertSame(first, assertThrows(IllegalStateException::class.java) { kernel.finishUtterance() })
        assertSame(first, assertThrows(IllegalStateException::class.java) {
            kernel.decode(PcmCaptureFrame(1, ByteArray(2), 1))
        })
        assertEquals(1, native.finishes)
        assertEquals(1, native.accepted.size)
        kernel.close()
        assertEquals(1, native.closes)
    }

    @Test fun convertsLittleEndianPcmWithoutChangingAmplitude() {
        val native = RecordingNativeSession()
        val kernel = StreamingPcmKernel(native)
        val result = kernel.decode(PcmCaptureFrame(0,
            byteArrayOf(0, -128, 0, -64, 0, 0, 0, 64, -1, 127), 100))
        assertEquals(1, native.accepted.size)
        assertArrayEquals(floatArrayOf(-1f, -.5f, 0f, .5f, .9999695f), native.accepted.single(), 0f)
        assertEquals(StreamingRemoteResult.Text("中文 API", true), result)
        // Sequence is diagnostic; canonical positions, not sequence deltas, join audio.
        kernel.decode(PcmCaptureFrame(99, byteArrayOf(0, 0), 105))
        assertEquals(2, native.accepted.size)
        kernel.close()
    }

    @Test fun rejectsDiscontinuityBeforeCallingNative() {
        for ((start, epoch) in listOf(103L to 0L, 101L to 0L, 102L to 1L)) {
            val native = RecordingNativeSession()
            val kernel = StreamingPcmKernel(native)
            kernel.decode(PcmCaptureFrame(0, ByteArray(4), 100))
            assertThrows(IllegalArgumentException::class.java) {
                kernel.decode(PcmCaptureFrame(1, ByteArray(4), start, epoch))
            }
            assertEquals(1, native.accepted.size)
            kernel.close()
        }
    }

    @Test fun rejectsInvalidCanonicalPayload() {
        for (frame in listOf(PcmCaptureFrame(0, ByteArray(2)),
            PcmCaptureFrame(0, ByteArray(32002), 0))) {
            val native = RecordingNativeSession()
            val kernel = StreamingPcmKernel(native)
            assertThrows(IllegalArgumentException::class.java) { kernel.decode(frame) }
            assertTrue(native.accepted.isEmpty())
            kernel.close()
        }
    }

    @Test fun closeIsIdempotentAndPreventsFurtherDecode() {
        val native = RecordingNativeSession()
        val kernel = StreamingPcmKernel(native)
        kernel.close()
        kernel.close()
        assertEquals(1, native.closes)
        assertThrows(IllegalStateException::class.java) {
            kernel.decode(PcmCaptureFrame(0, ByteArray(2), 0))
        }
        assertTrue(native.accepted.isEmpty())
    }

    @Test fun failedCloseIsNotReportedAsReleased() {
        val native = RecordingNativeSession(closeFailure = IllegalStateException("uncertain native close"))
        val kernel = StreamingPcmKernel(native)
        val first = assertThrows(IllegalStateException::class.java) { kernel.close() }
        val second = assertThrows(IllegalStateException::class.java) { kernel.close() }
        assertSame(first, second)
        assertEquals(1, native.closes) // No unsafe second native destroy.
        assertThrows(IllegalStateException::class.java) {
            kernel.decode(PcmCaptureFrame(0, ByteArray(2), 0))
        }
        assertTrue(native.accepted.isEmpty())
    }

    @Test fun failedInferenceCannotAcceptTheSameAudioAgain() {
        val native = RecordingNativeSession(acceptFailure = IllegalStateException("partially accepted"))
        val kernel = StreamingPcmKernel(native)
        val frame = PcmCaptureFrame(0, ByteArray(2), 0)
        val first = assertThrows(IllegalStateException::class.java) { kernel.decode(frame) }
        val second = assertThrows(IllegalStateException::class.java) { kernel.decode(frame) }
        assertSame(first, second)
        assertEquals(1, native.accepted.size)
        kernel.close()
        assertEquals(1, native.closes)
    }

    private class RecordingNativeSession(
        private val closeFailure: Throwable? = null,
        private val acceptFailure: Throwable? = null,
        private val finishFailure: Throwable? = null,
    ) : StreamingNativeSession {
        val accepted = mutableListOf<FloatArray>()
        var closes = 0
        var finishes = 0
        override fun finishUtterance(): StreamingRemoteResult.Text {
            check(closes == 0)
            finishes++
            finishFailure?.let { throw it }
            return StreamingRemoteResult.Text("尾部 API", true)
        }
        override fun accept(samples: FloatArray): StreamingRemoteResult.Text {
            check(closes == 0)
            accepted.add(samples.copyOf())
            acceptFailure?.let { throw it }
            return StreamingRemoteResult.Text("中文 API", true)
        }
        override fun close() {
            closes++
            closeFailure?.let { throw it }
        }
    }
}
