package com.loquiris.recording

import java.io.Closeable
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

class PcmCaptureFrame(
    val sequence: Long,
    bytes: ByteArray,
) {
    private val payload = bytes.copyOf()

    init {
        require(sequence >= 0) { "PCM sequence must be non-negative" }
        require(bytes.isNotEmpty()) { "PCM payload must not be empty" }
    }

    fun copyBytes(): ByteArray = payload.copyOf()

    internal fun isolatedCopy(): PcmCaptureFrame = PcmCaptureFrame(sequence, payload)
}

enum class PcmFanOutPublishResult {
    accepted,
    canonicalQueueFull,
    canonicalSinkFailed,
    closed,
}

data class PriorityPcmFanOutMetrics(
    val canonicalAcceptedFrames: Long,
    val canonicalProcessedFrames: Long,
    val canonicalRejectedFrames: Long,
    val canonicalSinkFailures: Long,
    val canonicalQueueHighWaterMark: Int,
    val inferenceAcceptedFrames: Long,
    val inferenceDroppedFrames: Long,
    val inferenceProcessedFrames: Long,
    val inferenceConsumerFailures: Long,
)

fun interface PcmInferenceConsumer {
    fun consume(frame: PcmCaptureFrame)

    fun onBacklog(
        queuedFrames: Int,
        droppedFrames: Long,
    ) = Unit

    fun onFailure(code: String) = Unit
}

class PriorityPcmFanOut(
    canonicalCapacity: Int,
    inferenceCapacity: Int,
    private val canonicalSink: (PcmCaptureFrame) -> Unit,
    private val workerJoinTimeoutMillis: Long = WORKER_JOIN_TIMEOUT_MILLISECONDS,
    private val workerInterruptJoinTimeoutMillis: Long = WORKER_INTERRUPT_JOIN_TIMEOUT_MILLISECONDS,
) : Closeable {
    private val canonicalQueue: ArrayBlockingQueue<PcmCaptureFrame>
    private val inferenceQueue: ArrayBlockingQueue<PcmCaptureFrame>
    private val closed = AtomicBoolean()
    private val canonicalFailed = AtomicBoolean()
    private val canonicalAccepted = AtomicLong()
    private val canonicalProcessed = AtomicLong()
    private val canonicalRejected = AtomicLong()
    private val canonicalSinkFailures = AtomicLong()
    private val canonicalQueueHighWater = AtomicInteger()
    private val inferenceAccepted = AtomicLong()
    private val inferenceDropped = AtomicLong()
    private val inferenceProcessed = AtomicLong()
    private val inferenceConsumerFailures = AtomicLong()
    private val inferenceConsumer = AtomicReference<PcmInferenceConsumer?>()
    private val lifecycleLock = Any()
    private val canonicalQueueLock = ReentrantLock()
    private val canonicalQueueChanged = canonicalQueueLock.newCondition()
    private val progressLock = ReentrantLock()
    private val progressChanged = progressLock.newCondition()
    private val worker: Thread
    private val inferenceWorker: Thread

    init {
        require(canonicalCapacity > 0) { "canonical capacity must be positive" }
        require(inferenceCapacity > 0) { "inference capacity must be positive" }
        require(workerJoinTimeoutMillis >= 0) { "worker join timeout must not be negative" }
        require(workerInterruptJoinTimeoutMillis >= 0) { "worker interrupt timeout must not be negative" }
        canonicalQueue = ArrayBlockingQueue(canonicalCapacity)
        inferenceQueue = ArrayBlockingQueue(inferenceCapacity)
        worker =
            Thread(::drainCanonical, "loquiris-canonical-encoder").apply {
                priority = Thread.MAX_PRIORITY
                isDaemon = true
                start()
            }
        inferenceWorker =
            Thread(::drainInferenceConsumer, "loquiris-live-inference").apply {
                priority = Thread.MIN_PRIORITY
                isDaemon = true
                start()
            }
    }

    val metrics: PriorityPcmFanOutMetrics
        get() =
            PriorityPcmFanOutMetrics(
                canonicalAcceptedFrames = canonicalAccepted.get(),
                canonicalProcessedFrames = canonicalProcessed.get(),
                canonicalRejectedFrames = canonicalRejected.get(),
                canonicalSinkFailures = canonicalSinkFailures.get(),
                canonicalQueueHighWaterMark = canonicalQueueHighWater.get(),
                inferenceAcceptedFrames = inferenceAccepted.get(),
                inferenceDroppedFrames = inferenceDropped.get(),
                inferenceProcessedFrames = inferenceProcessed.get(),
                inferenceConsumerFailures = inferenceConsumerFailures.get(),
            )

    fun publish(frame: PcmCaptureFrame): PcmFanOutPublishResult {
        synchronized(lifecycleLock) {
            if (closed.get()) return PcmFanOutPublishResult.closed
            if (canonicalFailed.get()) return PcmFanOutPublishResult.canonicalSinkFailed
            canonicalQueueLock.withLock {
                if (!canonicalQueue.offer(frame.isolatedCopy())) {
                    canonicalRejected.incrementAndGet()
                    return PcmFanOutPublishResult.canonicalQueueFull
                }
                canonicalAccepted.incrementAndGet()
                canonicalQueueHighWater.accumulateAndGet(canonicalQueue.size, ::maxOf)
                canonicalQueueChanged.signal()
            }
        }
        val inferenceFrame = frame.isolatedCopy()
        if (inferenceQueue.offer(inferenceFrame)) {
            inferenceAccepted.incrementAndGet()
        } else if (inferenceConsumer.get() != null) {
            inferenceQueue.poll()
            inferenceDropped.incrementAndGet()
            if (inferenceQueue.offer(inferenceFrame)) inferenceAccepted.incrementAndGet()
        } else {
            inferenceDropped.incrementAndGet()
        }
        return PcmFanOutPublishResult.accepted
    }

    fun replaceInferenceConsumer(consumer: PcmInferenceConsumer?) {
        val previous = inferenceConsumer.getAndSet(consumer)
        if (consumer == null || previous != null && previous !== consumer) {
            inferenceDropped.addAndGet(inferenceQueue.size.toLong())
            inferenceQueue.clear()
        }
        inferenceWorker.interrupt()
    }

    fun awaitCanonicalProcessed(
        atLeast: Long,
        timeoutMillis: Long,
    ): Boolean {
        require(atLeast >= 0)
        require(timeoutMillis >= 0)
        val deadline = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(timeoutMillis)
        progressLock.withLock {
            while (canonicalProcessed.get() < atLeast) {
                val remaining = deadline - System.nanoTime()
                if (remaining <= 0) return false
                progressChanged.awaitNanos(remaining)
            }
        }
        return true
    }

    fun drainInference(): List<PcmCaptureFrame> {
        val frames = mutableListOf<PcmCaptureFrame>()
        inferenceQueue.drainTo(frames)
        return frames
    }

    override fun close() {
        shutdown()
    }

    fun shutdown(): Boolean {
        val newlyClosed = synchronized(lifecycleLock) { closed.compareAndSet(false, true) }
        if (newlyClosed) canonicalQueueLock.withLock { canonicalQueueChanged.signalAll() }
        inferenceConsumer.set(null)
        inferenceDropped.addAndGet(inferenceQueue.size.toLong())
        inferenceQueue.clear()
        inferenceWorker.interrupt()
        worker.join(workerJoinTimeoutMillis)
        if (worker.isAlive) {
            worker.interrupt()
            worker.join(workerInterruptJoinTimeoutMillis)
        }
        return !worker.isAlive
    }

    fun awaitQuiescence() = worker.join()

    private fun drainCanonical() {
        while (true) {
            val frame = takeCanonicalFrame() ?: return
            try {
                canonicalSink(frame)
            } catch (_: Exception) {
                canonicalFailed.set(true)
                canonicalSinkFailures.incrementAndGet()
                markProcessed()
                return
            }
            markProcessed()
        }
    }

    private fun drainInferenceConsumer() {
        while (!closed.get()) {
            val consumer = inferenceConsumer.get()
            if (consumer == null) {
                try {
                    Thread.sleep(WORKER_POLL_MILLISECONDS)
                } catch (_: InterruptedException) {
                    continue
                }
                continue
            }
            val frame =
                try {
                    inferenceQueue.poll(WORKER_POLL_MILLISECONDS, TimeUnit.MILLISECONDS)
                } catch (_: InterruptedException) {
                    continue
                } ?: continue
            try {
                consumer.onBacklog(inferenceQueue.size, inferenceDropped.get())
                consumer.consume(frame)
                inferenceProcessed.incrementAndGet()
            } catch (_: Exception) {
                if (closed.get()) return
                inferenceConsumer.compareAndSet(consumer, null)
                inferenceConsumerFailures.incrementAndGet()
                runCatching { consumer.onFailure("transcription_live_consumer_failed") }
            }
        }
    }

    private fun markProcessed() {
        canonicalProcessed.incrementAndGet()
        progressLock.withLock { progressChanged.signalAll() }
    }

    private fun takeCanonicalFrame(): PcmCaptureFrame? =
        canonicalQueueLock.withLock {
            while (canonicalQueue.isEmpty() && !closed.get()) {
                try {
                    canonicalQueueChanged.await(WORKER_POLL_MILLISECONDS, TimeUnit.MILLISECONDS)
                } catch (_: InterruptedException) {
                    if (closed.get()) return@withLock null
                }
            }
            canonicalQueue.poll()
        }

    private companion object {
        const val WORKER_POLL_MILLISECONDS = 50L
        const val WORKER_JOIN_TIMEOUT_MILLISECONDS = 5_000L
        const val WORKER_INTERRUPT_JOIN_TIMEOUT_MILLISECONDS = 1_000L
    }
}
