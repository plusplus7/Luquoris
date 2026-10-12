package com.loquiris.recording

import org.junit.Assert.assertEquals
import org.junit.Test

class MonotonicRecordingTimerTest {
    @Test
    fun `paused wall time is excluded from media duration`() {
        var now = 1_000L
        val timer = MonotonicRecordingTimer(elapsedRealtimeMillis = { now })

        timer.resume()
        now = 3_500L
        assertEquals(2_500L, timer.snapshot(bytesWritten = 10).elapsedMilliseconds)

        timer.pause()
        now = 10_000L
        assertEquals(2_500L, timer.snapshot(bytesWritten = 20).elapsedMilliseconds)

        timer.resume()
        now = 11_000L
        assertEquals(3_500L, timer.snapshot(bytesWritten = 30).elapsedMilliseconds)
    }

    @Test
    fun `reported duration never regresses if clock source moves backward`() {
        var now = 5_000L
        val timer =
            MonotonicRecordingTimer(
                initialElapsedMilliseconds = 2_000L,
                elapsedRealtimeMillis = { now },
            )
        timer.resume()
        now = 6_000L
        assertEquals(3_000L, timer.snapshot(bytesWritten = 0).elapsedMilliseconds)

        now = 4_000L

        assertEquals(3_000L, timer.snapshot(bytesWritten = 0).elapsedMilliseconds)
    }

    @Test
    fun `snapshot carries authoritative byte count`() {
        val timer = MonotonicRecordingTimer(elapsedRealtimeMillis = { 0L })

        assertEquals(123_456L, timer.snapshot(bytesWritten = 123_456L).bytesWritten)
    }

    @Test
    fun `explicit capture boundaries exclude delayed stop and resume plumbing`() {
        var now = 1_000L
        val timer = MonotonicRecordingTimer(elapsedRealtimeMillis = { now })

        timer.resumeAt(1_000L)
        now = 8_000L
        timer.pauseAt(3_500L)
        assertEquals(2_500L, timer.snapshot(bytesWritten = 0).elapsedMilliseconds)

        timer.resumeAt(10_000L)
        now = 11_000L
        assertEquals(3_500L, timer.snapshot(bytesWritten = 0).elapsedMilliseconds)
    }
}
