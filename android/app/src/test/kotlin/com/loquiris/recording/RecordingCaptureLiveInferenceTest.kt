package com.loquiris.recording

import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingCaptureLiveInferenceTest {
    @Test
    fun `replaceable inference consumer observes copies while canonical recording continues`() {
        val source = LiveQueuePcmSource()
        val encoder = LiveCollectingEncoder()
        val inferenceSequences = mutableListOf<Long>()
        val pipeline = RecordingCapturePipeline(source = source, encoder = encoder)
        pipeline.replaceInferenceConsumer { frame ->
            synchronized(inferenceSequences) { inferenceSequences += frame.sequence }
        }

        assertEquals(RecordingCaptureCommandResult.Success, pipeline.start())
        source.offer(ByteArray(640) { 1 })
        source.offer(ByteArray(640) { 2 })
        assertTrue(encoder.awaitFrames(2))
        assertTrue(waitFor { synchronized(inferenceSequences) { inferenceSequences.size == 2 } })

        pipeline.replaceInferenceConsumer(null)
        source.offer(ByteArray(640) { 3 })
        assertTrue(encoder.awaitFrames(3))
        assertEquals(RecordingCaptureCommandResult.Success, pipeline.finish())

        assertEquals(listOf(0L, 1L, 2L), encoder.sequences)
        assertEquals(listOf(0L, 1L), synchronized(inferenceSequences) { inferenceSequences.toList() })
    }
}

private class LiveQueuePcmSource : PcmCaptureSource {
    private val queue = LinkedBlockingQueue<ByteArray>()

    @Volatile
    private var recording = false

    override fun start(): Boolean {
        recording = true
        return true
    }

    override fun read(target: ByteArray): Int {
        while (recording) {
            val bytes = queue.poll(20, TimeUnit.MILLISECONDS) ?: continue
            bytes.copyInto(target)
            return bytes.size
        }
        return PcmCaptureSource.READ_STOPPED
    }

    override fun stop(): Boolean {
        recording = false
        return true
    }

    override fun timestampFramePosition(): Long? = null

    override fun release() = Unit

    fun offer(bytes: ByteArray) = queue.put(bytes)
}

private class LiveCollectingEncoder : CanonicalPcmEncoder {
    val sequences = mutableListOf<Long>()

    override fun appendPcm(frame: PcmCaptureFrame): Boolean {
        synchronized(sequences) { sequences += frame.sequence }
        return true
    }

    override fun finish(): Boolean = true

    override fun abort() = Unit

    override fun bytesWritten(): Long = synchronized(sequences) { sequences.size * 640L }

    fun awaitFrames(count: Int): Boolean = waitFor { synchronized(sequences) { sequences.size >= count } }
}

private fun waitFor(predicate: () -> Boolean): Boolean {
    val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(2)
    while (System.nanoTime() < deadline) {
        if (predicate()) return true
        Thread.sleep(10)
    }
    return false
}
