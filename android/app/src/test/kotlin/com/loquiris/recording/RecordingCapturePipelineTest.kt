package com.loquiris.recording

import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingCapturePipelineTest {
    @Test
    fun `encoder storage is prepared before microphone starts`() {
        val events = mutableListOf<String>()
        val source = QueuePcmSource(onStart = { events += "microphone-start" })
        val encoder = PreparingCanonicalEncoder { events += "encoder-prepare" }
        val pipeline = RecordingCapturePipeline(source = source, encoder = encoder)

        assertEquals(RecordingCaptureCommandResult.Success, pipeline.start())

        assertEquals(listOf("encoder-prepare", "microphone-start"), events)
        pipeline.close()
    }

    @Test
    fun `failed encoder preparation never starts microphone`() {
        val events = mutableListOf<String>()
        val source = QueuePcmSource(onStart = { events += "microphone-start" })
        val encoder = PreparingCanonicalEncoder(prepareResult = false) { events += "encoder-prepare" }
        val pipeline = RecordingCapturePipeline(source = source, encoder = encoder)

        assertEquals(
            RecordingCaptureCommandResult.Failure("recording_encoder_prepare_failed"),
            pipeline.start(),
        )

        assertEquals(listOf("encoder-prepare"), events)
        assertTrue(source.released)
        pipeline.close()
    }

    @Test
    fun `capture reads flow to canonical encoder with health and priority metrics`() {
        val source = QueuePcmSource()
        val encoder = CollectingCanonicalEncoder()
        val pipeline = RecordingCapturePipeline(source = source, encoder = encoder)

        assertEquals(RecordingCaptureCommandResult.Success, pipeline.start())
        source.offer(ByteArray(640) { 1 })
        source.offer(ByteArray(640) { 2 })
        source.offer(ByteArray(640) { 3 })
        assertTrue(encoder.awaitFrames(3))
        assertEquals(RecordingCaptureCommandResult.Success, pipeline.finish())

        val snapshot = pipeline.snapshot()
        assertEquals(3L, snapshot.inputHealth.readCalls)
        assertEquals(1_920L, snapshot.inputHealth.pcmBytes)
        assertEquals(3L, snapshot.fanOut.canonicalProcessedFrames)
        assertEquals(0L, snapshot.fanOut.canonicalRejectedFrames)
        assertTrue(encoder.finished)
        assertTrue(source.released)
    }

    @Test
    fun `pause stops microphone reads and resume restarts without sequence reset`() {
        val source = QueuePcmSource()
        val encoder = CollectingCanonicalEncoder()
        val pipeline = RecordingCapturePipeline(source = source, encoder = encoder)

        assertEquals(RecordingCaptureCommandResult.Success, pipeline.start())
        source.offer(ByteArray(640) { 1 })
        assertTrue(encoder.awaitFrames(1))
        assertEquals(RecordingCaptureCommandResult.Success, pipeline.pause())
        source.offer(ByteArray(640) { 2 })
        Thread.sleep(100)
        assertEquals(1, encoder.sequences.size)

        assertEquals(RecordingCaptureCommandResult.Success, pipeline.resume())
        assertTrue(encoder.awaitFrames(2))
        assertEquals(listOf(0L, 1L), encoder.sequences)
        assertEquals(RecordingCaptureCommandResult.Success, pipeline.finish())
        assertEquals(2, source.startCount)
        assertTrue(source.stopCount >= 2)
    }

    @Test
    fun `capture boundary is recorded before a delayed stop and after start completes`() {
        var nowNanos = 1_000_000_000L
        val source =
            QueuePcmSource(
                onStart = { nowNanos += 100_000_000L },
                onStop = { nowNanos += 5_000_000_000L },
            )
        val pipeline =
            RecordingCapturePipeline(
                source = source,
                encoder = CollectingCanonicalEncoder(),
                elapsedRealtimeNanos = { nowNanos },
            )

        assertEquals(RecordingCaptureCommandResult.Success, pipeline.start())
        assertEquals(1_100_000_000L, pipeline.captureBoundaryElapsedRealtimeNanos())
        nowNanos = 3_500_000_000L

        assertEquals(RecordingCaptureCommandResult.Success, pipeline.pause())
        assertEquals(3_500_000_000L, pipeline.captureBoundaryElapsedRealtimeNanos())
        assertEquals(8_500_000_000L, nowNanos)

        nowNanos = 10_000_000_000L
        assertEquals(RecordingCaptureCommandResult.Success, pipeline.resume())
        assertEquals(10_100_000_000L, pipeline.captureBoundaryElapsedRealtimeNanos())
        pipeline.close()
    }

    @Test
    fun `source exception becomes sticky failure and shutdown still releases resources`() {
        val source = ThrowingPcmSource()
        val encoder = CollectingCanonicalEncoder()
        val pipeline = RecordingCapturePipeline(source = source, encoder = encoder)

        assertEquals(RecordingCaptureCommandResult.Success, pipeline.start())
        assertTrue(source.readAttempted.await(2, TimeUnit.SECONDS))
        assertTrue(waitUntil { pipeline.snapshot().state == RecordingCapturePipelineState.failed })
        pipeline.close()

        assertEquals("recording_input_read_failed", pipeline.snapshot().failureCode)
        assertTrue(source.released)
    }

    @Test
    fun `shutdown defers encoder release until an uninterruptible canonical sink exits`() {
        val source = QueuePcmSource()
        val encoder = BlockingCanonicalEncoder()
        val pipeline =
            RecordingCapturePipeline(
                source = source,
                encoder = encoder,
                canonicalWorkerJoinTimeoutMillis = 20,
                canonicalWorkerInterruptJoinTimeoutMillis = 20,
            )
        assertEquals(RecordingCaptureCommandResult.Success, pipeline.start())
        source.offer(ByteArray(640) { 1 })
        assertTrue(encoder.entered.await(2, TimeUnit.SECONDS))

        pipeline.close()

        assertFalse(encoder.aborted)
        encoder.release.countDown()
        assertTrue(encoder.abortObserved.await(2, TimeUnit.SECONDS))
    }

    private fun waitUntil(predicate: () -> Boolean): Boolean {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(2)
        while (System.nanoTime() < deadline) {
            if (predicate()) return true
            Thread.sleep(10)
        }
        return false
    }
}

private class QueuePcmSource(
    private val onStart: () -> Unit = {},
    private val onStop: () -> Unit = {},
) : PcmCaptureSource {
    private val queue = LinkedBlockingQueue<ByteArray>()

    @Volatile
    private var recording = false

    var startCount = 0
        private set
    var stopCount = 0
        private set
    var released = false
        private set

    override fun start(): Boolean {
        onStart()
        startCount += 1
        recording = true
        return true
    }

    override fun read(target: ByteArray): Int {
        while (recording) {
            val value = queue.poll(20, TimeUnit.MILLISECONDS) ?: continue
            value.copyInto(target)
            return value.size
        }
        return PcmCaptureSource.READ_STOPPED
    }

    override fun stop(): Boolean {
        onStop()
        stopCount += 1
        recording = false
        return true
    }

    override fun timestampFramePosition(): Long? = null

    override fun release() {
        released = true
    }

    fun offer(bytes: ByteArray) {
        queue.put(bytes)
    }
}

private class CollectingCanonicalEncoder : CanonicalPcmEncoder {
    val sequences = mutableListOf<Long>()

    @Volatile
    var finished = false
        private set

    override fun appendPcm(frame: PcmCaptureFrame): Boolean {
        synchronized(sequences) { sequences += frame.sequence }
        return true
    }

    override fun finish(): Boolean {
        finished = true
        return true
    }

    override fun abort() = Unit

    override fun bytesWritten(): Long = sequences.size * 640L

    fun awaitFrames(count: Int): Boolean {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(2)
        while (System.nanoTime() < deadline) {
            if (synchronized(sequences) { sequences.size >= count }) return true
            Thread.sleep(10)
        }
        return false
    }
}

private class PreparingCanonicalEncoder(
    private val prepareResult: Boolean = true,
    private val onPrepare: () -> Unit,
) : CanonicalPcmEncoder {
    override fun prepare(): Boolean {
        onPrepare()
        return prepareResult
    }

    override fun appendPcm(frame: PcmCaptureFrame): Boolean = true

    override fun finish(): Boolean = true

    override fun abort() = Unit

    override fun bytesWritten(): Long = 0
}

private class ThrowingPcmSource : PcmCaptureSource {
    val readAttempted = java.util.concurrent.CountDownLatch(1)
    var released = false
        private set

    override fun start(): Boolean = true

    override fun read(target: ByteArray): Int {
        readAttempted.countDown()
        throw IllegalStateException("injected read failure")
    }

    override fun stop(): Boolean = true

    override fun timestampFramePosition(): Long? = null

    override fun release() {
        released = true
    }
}

private class BlockingCanonicalEncoder : CanonicalPcmEncoder {
    val entered = java.util.concurrent.CountDownLatch(1)
    val release = java.util.concurrent.CountDownLatch(1)
    val abortObserved = java.util.concurrent.CountDownLatch(1)

    @Volatile
    var aborted = false
        private set

    override fun appendPcm(frame: PcmCaptureFrame): Boolean {
        entered.countDown()
        while (release.count > 0) {
            try {
                release.await(20, TimeUnit.MILLISECONDS)
            } catch (_: InterruptedException) {
                // Deliberately model a platform call that does not honor interruption.
            }
        }
        return true
    }

    override fun finish(): Boolean = true

    override fun abort() {
        aborted = true
        abortObserved.countDown()
    }

    override fun bytesWritten(): Long = 0
}
