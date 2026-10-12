package com.loquiris.spike

import java.io.Closeable
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

class PcmFrame(
    val sequence: Long,
    bytes: ByteArray,
) {
    private val payload = bytes.copyOf()

    fun copyBytes(): ByteArray = payload.copyOf()

    internal fun isolatedCopy(): PcmFrame = PcmFrame(sequence, payload)
}

enum class PcmPublishResult {
    accepted,
    canonicalQueueFull,
    canonicalSinkFailed,
    closed,
}

data class PcmFanOutMetrics(
    val canonicalAcceptedFrames: Long,
    val canonicalProcessedFrames: Long,
    val canonicalRejectedFrames: Long,
    val canonicalSinkFailures: Long,
    val canonicalQueueHighWaterMark: Int,
    val inferenceAcceptedFrames: Long,
    val inferenceDroppedFrames: Long,
)

class BoundedPcmFanOut(
    canonicalCapacity: Int,
    inferenceCapacity: Int,
    private val canonicalSink: (PcmFrame) -> Unit,
) : Closeable {
    private val canonicalQueue: ArrayBlockingQueue<PcmFrame>
    private val inferenceQueue: ArrayBlockingQueue<PcmFrame>
    private val closed = AtomicBoolean()
    private val canonicalFailed = AtomicBoolean()
    private val canonicalAcceptedFrameCount = AtomicLong()
    private val canonicalProcessedFrameCount = AtomicLong()
    private val canonicalRejectedFrameCount = AtomicLong()
    private val canonicalSinkFailureCount = AtomicLong()
    private val canonicalQueueHighWaterMark = AtomicInteger()
    private val inferenceAcceptedFrameCount = AtomicLong()
    private val inferenceDroppedFrameCount = AtomicLong()
    private val lifecycleLock = Any()
    private val canonicalQueueLock = ReentrantLock()
    private val canonicalQueueChanged = canonicalQueueLock.newCondition()
    private val progressLock = ReentrantLock()
    private val progressChanged = progressLock.newCondition()
    private val canonicalWorker: Thread

    init {
        require(canonicalCapacity > 0) { "canonicalCapacity must be positive" }
        require(inferenceCapacity > 0) { "inferenceCapacity must be positive" }
        canonicalQueue = ArrayBlockingQueue(canonicalCapacity)
        inferenceQueue = ArrayBlockingQueue(inferenceCapacity)
        canonicalWorker =
            Thread(::drainCanonical, "loquiris-canonical-spike").apply {
                isDaemon = true
                start()
            }
    }

    val metrics: PcmFanOutMetrics
        get() =
            PcmFanOutMetrics(
                canonicalAcceptedFrames = canonicalAcceptedFrameCount.get(),
                canonicalProcessedFrames = canonicalProcessedFrameCount.get(),
                canonicalRejectedFrames = canonicalRejectedFrameCount.get(),
                canonicalSinkFailures = canonicalSinkFailureCount.get(),
                canonicalQueueHighWaterMark = canonicalQueueHighWaterMark.get(),
                inferenceAcceptedFrames = inferenceAcceptedFrameCount.get(),
                inferenceDroppedFrames = inferenceDroppedFrameCount.get(),
            )

    fun publish(frame: PcmFrame): PcmPublishResult {
        synchronized(lifecycleLock) {
            if (closed.get()) {
                return PcmPublishResult.closed
            }
            if (canonicalFailed.get()) {
                return PcmPublishResult.canonicalSinkFailed
            }
            canonicalQueueLock.withLock {
                if (!canonicalQueue.offer(frame.isolatedCopy())) {
                    canonicalRejectedFrameCount.incrementAndGet()
                    return PcmPublishResult.canonicalQueueFull
                }
                canonicalAcceptedFrameCount.incrementAndGet()
                canonicalQueueHighWaterMark.accumulateAndGet(canonicalQueue.size, ::maxOf)
                canonicalQueueChanged.signal()
            }
        }

        if (inferenceQueue.remainingCapacity() > 0 && inferenceQueue.offer(frame.isolatedCopy())) {
            inferenceAcceptedFrameCount.incrementAndGet()
        } else {
            inferenceDroppedFrameCount.incrementAndGet()
        }
        return PcmPublishResult.accepted
    }

    fun awaitCanonicalProcessed(
        atLeast: Long,
        timeoutMillis: Long,
    ): Boolean {
        require(atLeast >= 0) { "atLeast must be non-negative" }
        require(timeoutMillis >= 0) { "timeoutMillis must be non-negative" }
        val deadlineNanos = System.nanoTime() + TimeUnit.MILLISECONDS.toNanos(timeoutMillis)
        progressLock.withLock {
            while (canonicalProcessedFrameCount.get() < atLeast) {
                val remainingNanos = deadlineNanos - System.nanoTime()
                if (remainingNanos <= 0) {
                    return false
                }
                progressChanged.awaitNanos(remainingNanos)
            }
        }
        return true
    }

    fun drainInference(): List<PcmFrame> {
        val drained = mutableListOf<PcmFrame>()
        inferenceQueue.drainTo(drained)
        return drained
    }

    override fun close() {
        val shouldClose =
            synchronized(lifecycleLock) {
                closed.compareAndSet(false, true)
            }
        if (shouldClose) {
            canonicalQueueLock.withLock { canonicalQueueChanged.signalAll() }
            canonicalWorker.interrupt()
            canonicalWorker.join(WORKER_JOIN_TIMEOUT_MILLIS)
        }
    }

    private fun drainCanonical() {
        while (true) {
            val frame = takeCanonicalFrame() ?: return
            try {
                canonicalSink(frame)
            } catch (_: Exception) {
                canonicalFailed.set(true)
                canonicalSinkFailureCount.incrementAndGet()
            } finally {
                canonicalProcessedFrameCount.incrementAndGet()
                progressLock.withLock {
                    progressChanged.signalAll()
                }
            }
        }
    }

    private fun takeCanonicalFrame(): PcmFrame? =
        canonicalQueueLock.withLock {
            while (canonicalQueue.isEmpty() && !closed.get()) {
                try {
                    canonicalQueueChanged.await(WORKER_POLL_MILLIS, TimeUnit.MILLISECONDS)
                } catch (_: InterruptedException) {
                    if (closed.get()) return@withLock null
                }
            }
            canonicalQueue.poll()
        }

    companion object {
        private const val WORKER_POLL_MILLIS = 50L
        private const val WORKER_JOIN_TIMEOUT_MILLIS = 2_000L
    }
}
