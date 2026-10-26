package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame
import org.junit.Assert.*
import org.junit.Test

class StreamingCaptureTimelineTest {
    private val owner = StreamingRemoteIdentity("run", "lease")

    @Test fun revisesAndFinalizesOneUtteranceUsingCanonicalSamples() {
        val timeline = StreamingCaptureTimeline(owner)
        assertEquals(listOf(StreamingCaptureText(owner, 0, "utterance-1", 0, 3200, 0, "  中文 API\n", false)),
            timeline.accept(captureFrame(0, 0), StreamingRemoteResult.Text("  中文 API\n", false)))
        assertTrue(timeline.accept(captureFrame(1, 3200), StreamingRemoteResult.Text("  中文 API\n", false)).isEmpty())
        assertEquals(listOf(StreamingCaptureText(owner, 1, "utterance-1", 0, 9600, 0, "中文 API v2", false)),
            timeline.accept(captureFrame(2, 6400), StreamingRemoteResult.Text("中文 API v2", false)))
        assertEquals(listOf(StreamingCaptureText(owner, 2, "utterance-1", 0, 12800, 0, "中文 API v2", true)),
            timeline.accept(captureFrame(3, 9600), StreamingRemoteResult.Text("中文 API v2", true)))
        assertEquals(listOf(StreamingCaptureText(owner, 3, "utterance-2", 12800, 16000, 0, "next", false)),
            timeline.accept(captureFrame(4, 12800), StreamingRemoteResult.Text("next", false)))
    }

    @Test fun emptyHypothesesOnlyRetractAnExistingProvisional() {
        val timeline = StreamingCaptureTimeline(owner)
        assertTrue(timeline.accept(captureFrame(0, 0), StreamingRemoteResult.Text("", false)).isEmpty())
        assertEquals(listOf(StreamingCaptureText(owner, 0, "utterance-1", 0, 6400, 0, "guess", false)),
            timeline.accept(captureFrame(1, 3200), StreamingRemoteResult.Text("guess", false)))
        assertEquals(listOf(StreamingCaptureText(owner, 1, "utterance-1", 0, 9600, 0, "", false)),
            timeline.accept(captureFrame(2, 6400), StreamingRemoteResult.Text("", false)))
        assertEquals(listOf(StreamingCaptureText(owner, 2, "utterance-1", 0, 12800, 0, "", true)),
            timeline.accept(captureFrame(3, 9600), StreamingRemoteResult.Text("", true)))
        assertTrue(timeline.accept(captureFrame(4, 12800), StreamingRemoteResult.Text("", true)).isEmpty())
        assertEquals(listOf(StreamingCaptureText(owner, 3, "utterance-2", 16000, 19200, 0, "real", false)),
            timeline.accept(captureFrame(5, 16000), StreamingRemoteResult.Text("real", false)))
    }

    @Test fun explicitPauseKeepsMediaGapAndStartsNewUtterance() {
        val timeline = StreamingCaptureTimeline(owner)
        timeline.accept(captureFrame(0, 0), StreamingRemoteResult.Text("partial", false))
        assertEquals(listOf(StreamingCaptureText(owner, 1, "utterance-1", 0, 3200, 0, "尾部", true)),
            timeline.finishBoundary(StreamingRemoteResult.Text("尾部", true), StreamingBoundaryReason.PAUSE))
        assertEquals(listOf(
            StreamingCaptureGap(owner, 2, 3200, 6400, 1, StreamingBoundaryReason.PAUSE),
            StreamingCaptureText(owner, 3, "utterance-2", 6400, 9600, 1, "new", false)),
            timeline.accept(captureFrame(1, 6400, 1), StreamingRemoteResult.Text("new", false)))
    }

    @Test fun rejectsUnannouncedGapsOrBackwardMediaAndEpochs() {
        for ((start, epoch) in listOf(3201L to 3L, 3199L to 3L, 3200L to 4L)) {
            val timeline = StreamingCaptureTimeline(owner)
            timeline.accept(captureFrame(0, 0, 3), StreamingRemoteResult.Text("old", false))
            assertThrows(IllegalArgumentException::class.java) {
                timeline.accept(captureFrame(1, start, epoch), StreamingRemoteResult.Text("invalid", false))
            }
            assertEquals(listOf(StreamingCaptureText(owner, 1, "utterance-1", 0, 6400, 3, "valid", false)),
                timeline.accept(captureFrame(1, 3200, 3), StreamingRemoteResult.Text("valid", false)))
            timeline.finishBoundary(StreamingRemoteResult.Text("final", true), StreamingBoundaryReason.PAUSE)
            for ((afterStart, afterEpoch) in listOf(6399L to 4L, 7000L to 2L)) {
                assertThrows(IllegalArgumentException::class.java) {
                    timeline.accept(captureFrame(2, afterStart, afterEpoch), StreamingRemoteResult.Text("invalid", false))
                }
            }
            assertEquals(listOf(StreamingCaptureGap(owner, 3, 6400, 7000, 4, StreamingBoundaryReason.PAUSE)),
                timeline.accept(captureFrame(2, 7000, 4), StreamingRemoteResult.Text("", false)))
        }
    }

    @Test fun closingAndStoppingNeverInventFinalOrAcceptLateEvents() {
        val cancelled = StreamingCaptureTimeline(owner)
        cancelled.accept(captureFrame(0, 0), StreamingRemoteResult.Text("partial", false))
        cancelled.close()
        assertTrue(cancelled.accept(captureFrame(1, 3200), StreamingRemoteResult.Text("late", true)).isEmpty())
        assertTrue(cancelled.finishBoundary(StreamingRemoteResult.Text("late", true), StreamingBoundaryReason.STOP).isEmpty())
        val stopped = StreamingCaptureTimeline(owner)
        stopped.accept(captureFrame(0, 0), StreamingRemoteResult.Text("partial", false))
        assertEquals(listOf(StreamingCaptureText(owner, 1, "utterance-1", 0, 3200, 0, "final", true)),
            stopped.finishBoundary(StreamingRemoteResult.Text("final", true), StreamingBoundaryReason.STOP))
        assertTrue(stopped.accept(captureFrame(1, 3200), StreamingRemoteResult.Text("late", false)).isEmpty())
    }

    @Test fun lateStartRecordsMissingCanonicalPrefixWithoutInventedText() {
        val timeline = StreamingCaptureTimeline(owner)
        assertEquals(listOf(StreamingCaptureGap(owner, 0, 0, 3200, 2, StreamingBoundaryReason.DISCONTINUITY)),
            timeline.accept(captureFrame(0, 3200, 2), StreamingRemoteResult.Text("", false)))
        assertEquals(listOf(StreamingCaptureText(owner, 1, "utterance-1", 3200, 9600, 2, "first", false)),
            timeline.accept(captureFrame(1, 6400, 2), StreamingRemoteResult.Text("first", false)))
    }

    @Test fun rejectsNonfinalBoundaryAndKeepsPriorCoordinates() {
        val timeline = StreamingCaptureTimeline(owner)
        timeline.accept(captureFrame(0, 0), StreamingRemoteResult.Text("old", false))
        assertThrows(IllegalArgumentException::class.java) {
            timeline.finishBoundary(StreamingRemoteResult.Text("not final", false), StreamingBoundaryReason.PAUSE)
        }
        assertEquals(listOf(StreamingCaptureText(owner, 1, "utterance-1", 0, 6400, 0, "valid", false)),
            timeline.accept(captureFrame(1, 3200), StreamingRemoteResult.Text("valid", false)))
    }

    private fun captureFrame(sequence: Long, start: Long, epoch: Long = 0): PcmCaptureFrame =
        PcmCaptureFrame(sequence, ByteArray(6400), start, epoch)
}
