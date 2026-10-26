package com.loquiris.recording

import java.io.Closeable
import java.util.Collections
import java.util.IdentityHashMap
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CompletionStage
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
    /** Offset in canonical mono PCM16 samples, never sequence-derived or wall time. */
    val canonicalStartSample: Long? = null,
    /** Successful pause/resume generation; not a recognizer owner epoch. */
    val captureEpoch: Long = 0,
) {
    private val payload = bytes.copyOf()
    val canonicalEndSampleExclusive: Long?

    init {
        require(sequence >= 0) { "PCM sequence must be non-negative" }
        require(bytes.isNotEmpty()) { "PCM payload must not be empty" }
        require(captureEpoch >= 0) { "capture epoch must be non-negative" }
        canonicalEndSampleExclusive = canonicalStartSample?.let { start ->
            require(start >= 0) { "canonical sample offset must be non-negative" }
            require(payload.size % 2 == 0) { "canonical PCM16 must contain complete samples" }
            Math.addExact(start, payload.size.toLong() / 2)
        }
    }

    fun copyBytes(): ByteArray = payload.copyOf()

    internal fun isolatedCopy(): PcmCaptureFrame =
        PcmCaptureFrame(sequence, payload, canonicalStartSample, captureEpoch)
}

enum class PcmFanOutPublishResult {
    accepted,
    canonicalQueueFull,
    canonicalSinkFailed,
    closed,
}

/** Ordered worker completion only, never evidence of native resource release. */
enum class PcmInferenceBoundaryResult { completed, detached, queueFull, closed, failed }

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

/** Exact canonical coordinates, including capture discontinuity generation. */
data class CanonicalPcmInterval(val startSample: Long, val endSampleExclusive: Long, val captureEpoch: Long)

/** Immutable metadata only; no PCM is copied into a monitoring snapshot. */
class PcmInferenceBacklog(intervals: List<CanonicalPcmInterval>, val pendingFrames: Int, val hasUnknownPosition: Boolean) {
    val intervals: List<CanonicalPcmInterval> = Collections.unmodifiableList(intervals.toList())
}

class PriorityPcmFanOut(
    canonicalCapacity: Int,
    inferenceCapacity: Int,
    private val canonicalSink: (PcmCaptureFrame) -> Unit,
    private val workerJoinTimeoutMillis: Long = WORKER_JOIN_TIMEOUT_MILLISECONDS,
    private val workerInterruptJoinTimeoutMillis: Long = WORKER_INTERRUPT_JOIN_TIMEOUT_MILLISECONDS,
) : Closeable {
    /** Cancel only derived work; notification is nonblocking and never joins a worker. */
    fun abortInference(failed: Boolean = false) {
        val result = if (failed) PcmInferenceBoundaryResult.failed else PcmInferenceBoundaryResult.closed
        val (discarded, consumer) = synchronized(inferenceBacklogLock) {
            inferenceAdmissionClosed = true
            // A completed worker STOP is not a native release acknowledgement.
            val previous = (inferenceConsumer.getAndSet(null) ?: inferenceTerminalOwner) as? PcmCaptureBoundaryConsumer
            val (frames, boundaries) = drainQueuedInferenceLocked()
            inferenceDropped.addAndGet(frames.size.toLong())
            inferenceBacklogLock.notifyAll()
            boundaries to previous
        }
        discarded.forEach { it.completion.complete(result) }
        if (consumer != null) runCatching { consumer.onBoundaryRejected(result) }
    }

    fun notifyCaptureBoundary(boundary: PcmCaptureBoundary): CompletionStage<PcmInferenceBoundaryResult> {
        val consumer = inferenceConsumer.get() as? PcmCaptureBoundaryConsumer
            ?: return CompletableFuture.completedFuture(PcmInferenceBoundaryResult.detached)
        val stage = if (boundary == PcmCaptureBoundary.STOP) {
            finishInference(consumer) { consumer.onCaptureBoundary(boundary) }
        } else enqueueInferenceBoundary(consumer) { consumer.onCaptureBoundary(boundary) }
        stage.whenComplete { outcome, _ ->
            if (outcome != PcmInferenceBoundaryResult.completed) {
                runCatching { consumer.onBoundaryRejected(outcome ?: PcmInferenceBoundaryResult.failed) }
            }
        }
        return stage
    }

    /** Seal derived input and enqueue final work; canonical recording is unaffected. */
    fun finishInference(consumer: PcmInferenceConsumer, action: () -> Unit): CompletionStage<PcmInferenceBoundaryResult> =
        admitInferenceBoundary(consumer, action, terminal = true)

    /**
     * At most sixteen queued controls; native work never runs on the caller.
     * Completion listeners may run synchronously on the worker or detaching
     * caller. They may enqueue, but must never wait for this worker's work.
     */
    fun enqueueInferenceBoundary(consumer: PcmInferenceConsumer, action: () -> Unit): CompletionStage<PcmInferenceBoundaryResult> =
        admitInferenceBoundary(consumer, action, terminal = false)

    private fun admitInferenceBoundary(consumer: PcmInferenceConsumer, action: () -> Unit,
        terminal: Boolean): CompletionStage<PcmInferenceBoundaryResult> {
        val completion = CompletableFuture<PcmInferenceBoundaryResult>()
        val rejected = synchronized(inferenceBacklogLock) {
            if (terminal && inferenceTerminalOwner === consumer) {
                inferenceTerminalCompletion?.let { return InferenceBoundaryStage(it) }
            }
            when {
                closed.get() || inferenceAdmissionClosed -> PcmInferenceBoundaryResult.closed
                inferenceConsumer.get() !== consumer -> PcmInferenceBoundaryResult.detached
                inferenceBoundaries.size >= MAX_PENDING_INFERENCE_BOUNDARIES -> PcmInferenceBoundaryResult.queueFull
                else -> {
                    val marker = InferenceBoundary(consumer, nextInferenceOrdinal, action, completion, terminal)
                    inferenceBoundaries.addLast(marker)
                    if (terminal) {
                        inferenceTerminal = marker
                        inferenceTerminalOwner = consumer
                        inferenceTerminalCompletion = completion
                        inferenceAdmissionClosed = true
                    }
                    inferenceBacklogLock.notifyAll()
                    null
                }
            }
        }
        if (rejected != null) completion.complete(rejected)
        return InferenceBoundaryStage(completion)
    }

    private class InferenceBoundary(val consumer: PcmInferenceConsumer, val beforeOrdinal: Long,
        val action: () -> Unit, val completion: CompletableFuture<PcmInferenceBoundaryResult>, val terminal: Boolean)
    private sealed interface InferenceWork {
        class Frame(val consumer: PcmInferenceConsumer, val frame: PcmCaptureFrame) : InferenceWork
        class Boundary(val boundary: InferenceBoundary) : InferenceWork
    }

    /** Queued plus in-flight ownership; dequeue alone never reduces backlog. */
    fun inferenceBacklog(): PcmInferenceBacklog {
        val intervals = synchronized(inferenceBacklogLock) {
            inferencePending.map { frame ->
                val start = frame.canonicalStartSample
                val end = frame.canonicalEndSampleExclusive
                if (start == null || end == null) null else CanonicalPcmInterval(start, end, frame.captureEpoch)
            }
        }
        return PcmInferenceBacklog(
            intervals.filterNotNull().sortedWith(compareBy({ it.startSample }, { it.endSampleExclusive }, { it.captureEpoch })),
            intervals.size,
            intervals.any { it == null },
        )
    }

    @Suppress("PLATFORM_CLASS_MAPPED_TO_KOTLIN")
    private val inferenceBacklogLock = java.lang.Object()
    // The same frame identities already owned by the queue/worker, not PCM copies.
    // At most inferenceCapacity queued frames plus the single worker's frame.
    private val inferencePending = Collections.newSetFromMap(IdentityHashMap<PcmCaptureFrame, Boolean>())
    // Ordinals are internal admission order, never caller sequence or media time.
    private val inferenceOrdinals = IdentityHashMap<PcmCaptureFrame, Long>()
    private val inferenceBoundaries = java.util.ArrayDeque<InferenceBoundary>()
    private var nextInferenceOrdinal = 0L
    private var inferenceTerminal: InferenceBoundary? = null
    private var inferenceTerminalOwner: PcmInferenceConsumer? = null
    private var inferenceTerminalCompletion: CompletableFuture<PcmInferenceBoundaryResult>? = null
    private var inferenceAdmissionClosed = false
    private var inferenceClosed = false
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
        synchronized(inferenceBacklogLock) {
            // shutdown may follow canonical admission but precede derived work.
            if (closed.get() || inferenceAdmissionClosed) return PcmFanOutPublishResult.accepted
            inferencePending.add(inferenceFrame)
            if (inferenceQueue.offer(inferenceFrame)) {
                inferenceAccepted.incrementAndGet()
                inferenceOrdinals[inferenceFrame] = nextInferenceOrdinal++
            }
            else if (inferenceConsumer.get() != null) {
                inferenceQueue.poll()?.let { inferencePending.remove(it); inferenceOrdinals.remove(it) }
                inferenceDropped.incrementAndGet()
                if (inferenceQueue.offer(inferenceFrame)) {
                    inferenceAccepted.incrementAndGet()
                    inferenceOrdinals[inferenceFrame] = nextInferenceOrdinal++
                }
                else inferencePending.remove(inferenceFrame)
            } else {
                inferencePending.remove(inferenceFrame)
                inferenceDropped.incrementAndGet()
            }
            inferenceBacklogLock.notifyAll()
        }
        return PcmFanOutPublishResult.accepted
    }

    fun replaceInferenceConsumer(consumer: PcmInferenceConsumer?) {
        val discarded = synchronized(inferenceBacklogLock) {
            val previous = inferenceConsumer.getAndSet(consumer)
            val removed = if (consumer == null || previous != null && previous !== consumer) {
                drainQueuedInferenceLocked().also { inferenceDropped.addAndGet(it.first.size.toLong()) }.second
            } else emptyList()
            if (consumer != null && previous !== consumer) {
                inferenceAdmissionClosed = false
                inferenceTerminalOwner = null
                inferenceTerminalCompletion = null
            }
            inferenceBacklogLock.notifyAll()
            removed
        }
        discarded.forEach { it.completion.complete(PcmInferenceBoundaryResult.detached) }
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

    /**
     * Transfer queued derived frames to the caller, removing ledger ownership.
     * Work pending in that external caller is no longer part of inferenceBacklog.
     * Streaming observers must not use this manual-drain path as a decoder queue.
     */
    fun drainInference(): List<PcmCaptureFrame> {
        val (frames, boundaries) = synchronized(inferenceBacklogLock) { drainQueuedInferenceLocked() }
        boundaries.forEach { it.completion.complete(PcmInferenceBoundaryResult.detached) }
        return frames
    }

    /** Caller holds the metadata lock; never completes caller callbacks here. */
    private fun drainQueuedInferenceLocked(): Pair<List<PcmCaptureFrame>, List<InferenceBoundary>> {
        val frames = mutableListOf<PcmCaptureFrame>()
        inferenceQueue.drainTo(frames)
        frames.forEach { inferencePending.remove(it); inferenceOrdinals.remove(it) }
        val boundaries = inferenceBoundaries.toList()
        inferenceBoundaries.clear()
        inferenceTerminal = null
        return frames to boundaries
    }

    private fun forgetInferenceFrame(frame: PcmCaptureFrame) {
        synchronized(inferenceBacklogLock) { inferencePending.remove(frame); inferenceOrdinals.remove(frame) }
    }

    override fun close() {
        shutdown()
    }

    fun shutdown(preserveInferenceBoundary: Boolean = false): Boolean {
        val newlyClosed = synchronized(lifecycleLock) { closed.compareAndSet(false, true) }
        if (newlyClosed) canonicalQueueLock.withLock { canonicalQueueChanged.signalAll() }
        val (discarded, preserve, abortedConsumer) = synchronized(inferenceBacklogLock) {
            inferenceClosed = true
            val keepFinal = preserveInferenceBoundary && inferenceTerminal != null && inferenceConsumer.get() != null
            val aborted = if (keepFinal) null else inferenceConsumer.get() as? PcmCaptureBoundaryConsumer
            val boundaries = if (keepFinal) emptyList() else {
                inferenceConsumer.set(null)
                val (frames, removed) = drainQueuedInferenceLocked()
                inferenceDropped.addAndGet(frames.size.toLong())
                removed
            }
            inferenceBacklogLock.notifyAll()
            Triple(boundaries, keepFinal, aborted)
        }
        discarded.forEach { it.completion.complete(PcmInferenceBoundaryResult.closed) }
        if (abortedConsumer != null) runCatching { abortedConsumer.onBoundaryRejected(PcmInferenceBoundaryResult.closed) }
        if (!preserve) inferenceWorker.interrupt()
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
        while (true) {
            when (val work = takeInferenceWork() ?: return) {
                is InferenceWork.Frame -> {
                    try {
                        work.consumer.onBacklog(inferenceQueue.size, inferenceDropped.get())
                        work.consumer.consume(work.frame)
                        inferenceProcessed.incrementAndGet()
                    } catch (_: Throwable) {
                        failInferenceConsumer(work.consumer, "transcription_live_consumer_failed")
                    } finally { forgetInferenceFrame(work.frame) }
                }
                is InferenceWork.Boundary -> {
                    val marker = work.boundary
                    val aborted = synchronized(inferenceBacklogLock) { inferenceClosed && inferenceTerminal == null }
                    val outcome = if (aborted) PcmInferenceBoundaryResult.closed
                        else if (inferenceConsumer.get() !== marker.consumer) PcmInferenceBoundaryResult.detached
                        else try {
                            marker.action()
                            PcmInferenceBoundaryResult.completed
                        } catch (_: Throwable) {
                            failInferenceConsumer(marker.consumer, "transcription_live_boundary_failed")
                            PcmInferenceBoundaryResult.failed
                        }
                    if (marker.terminal) synchronized(inferenceBacklogLock) {
                        if (inferenceTerminal === marker) {
                            inferenceTerminal = null
                            inferenceConsumer.compareAndSet(marker.consumer, null)
                            inferenceBacklogLock.notifyAll()
                        }
                    }
                    marker.completion.complete(outcome)
                }
            }
        }
    }

    private fun takeInferenceWork(): InferenceWork? = synchronized(inferenceBacklogLock) {
        while (!inferenceClosed || inferenceTerminal != null) {
            val consumer = inferenceConsumer.get()
            if (consumer != null) {
                val marker = inferenceBoundaries.peekFirst()
                val frame = inferenceQueue.peek()
                if (marker != null && (frame == null || checkNotNull(inferenceOrdinals[frame]) >= marker.beforeOrdinal)) {
                    inferenceBoundaries.removeFirst()
                    return@synchronized InferenceWork.Boundary(marker)
                }
                if (frame != null) {
                    inferenceQueue.poll()
                    return@synchronized InferenceWork.Frame(consumer, frame)
                }
            }
            try { inferenceBacklogLock.wait(WORKER_POLL_MILLISECONDS) }
            catch (_: InterruptedException) { if (inferenceClosed && inferenceTerminal == null) return@synchronized null }
        }
        null
    }

    private fun failInferenceConsumer(consumer: PcmInferenceConsumer, code: String) {
        val discarded = synchronized(inferenceBacklogLock) {
            if (!inferenceConsumer.compareAndSet(consumer, null)) return
            val (frames, boundaries) = drainQueuedInferenceLocked()
            inferenceDropped.addAndGet(frames.size.toLong())
            inferenceConsumerFailures.incrementAndGet()
            boundaries
        }
        discarded.forEach { it.completion.complete(PcmInferenceBoundaryResult.detached) }
        runCatching { consumer.onFailure(code) }
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
        const val MAX_PENDING_INFERENCE_BOUNDARIES = 16
        const val WORKER_POLL_MILLISECONDS = 50L
        const val WORKER_JOIN_TIMEOUT_MILLISECONDS = 5_000L
        const val WORKER_INTERRUPT_JOIN_TIMEOUT_MILLISECONDS = 1_000L
    }
}

private class InferenceBoundaryStage<T>(private val root: CompletableFuture<T>) : CompletionStage<T> by root {
    override fun toCompletableFuture(): CompletableFuture<T> = root.thenApply { it }
}
