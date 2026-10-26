package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame
import com.loquiris.recording.CanonicalPcmInterval
import com.loquiris.recording.PcmInferenceBacklog
import com.loquiris.recording.PriorityPcmFanOut
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.ScheduledThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference
import org.junit.Assert.*
import org.junit.Test

class StreamingBacklogWatchdogTest {
    @Test
    fun remoteBacklogDegradationWaitsForRemoteReleaseWithoutBlockingCanonicalAudio() {
        val dispatch = java.util.concurrent.LinkedBlockingQueue<Runnable>()
        val sent = java.util.concurrent.CopyOnWriteArrayList<StreamingRemoteCommand>()
        val identity = StreamingRemoteIdentity("remote-backlog", "binding")
        val client = StreamingRemoteSession(identity, { sent.add(it) }, java.util.concurrent.Executor { dispatch.add(it) })
        val fanOut = PriorityPcmFanOut(320, 320, {})
        val ticker = ManualSecondTicker()
        val entered = CountDownLatch(1)
        val settled = CountDownLatch(1)
        val watchdog = StreamingBacklogWatchdog(16000, fanOut::inferenceBacklog,
            StreamingReleaseOwner { client.closeRemote() }, ticker)
        try {
            client.startRemote("a".repeat(64))
            requireNotNull(dispatch.poll(2, TimeUnit.SECONDS)).run()
            client.receiveRemote(StreamingRemoteReply.Ready(identity))
            fanOut.replaceInferenceConsumer { frame ->
                val pending = requireNotNull(client.submitRemote(frame))
                entered.countDown()
                // Dequeue, interruption and a sent Close must not retire this
                // canonical interval before remote inference/release settles.
                try { pending.toCompletableFuture().join() }
                finally { settled.countDown() }
            }
            assertEquals(com.loquiris.recording.PcmFanOutPublishResult.accepted,
                fanOut.publish(PcmCaptureFrame(0, ByteArray(640), 0)))
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            requireNotNull(dispatch.poll(2, TimeUnit.SECONDS)).run()
            for (sequence in 1L..300L) {
                assertEquals(com.loquiris.recording.PcmFanOutPublishResult.accepted,
                    fanOut.publish(PcmCaptureFrame(sequence, ByteArray(640), sequence * 320)))
            }
            watchdog.start()
            ticker.fire(1000); ticker.fire(2000); ticker.fire(3000)
            assertEquals(StreamingStopCause.BACKLOG, watchdog.stopCause)
            assertEquals(96320L, watchdog.latestObservation?.uniqueSamples)
            requireNotNull(dispatch.poll(2, TimeUnit.SECONDS)).run()
            assertTrue(sent.last() is StreamingRemoteCommand.Close)
            assertFalse(watchdog.closeAsync().toCompletableFuture().isDone)
            assertNotNull(client.pendingFrame)
            assertEquals(1L, settled.count)
            assertTrue("canonical writes must finish while remote PCM is stalled",
                fanOut.awaitCanonicalProcessed(301, 2000))
            assertTrue(fanOut.shutdown())
            assertEquals("shutdown drops queued derived work, not the remote in-flight frame",
                1, fanOut.inferenceBacklog().pendingFrames)
            client.receiveRemote(StreamingRemoteReply.Released(identity))
            watchdog.closeAsync().toCompletableFuture().get(2, TimeUnit.SECONDS)
            assertTrue(settled.await(2, TimeUnit.SECONDS))
            assertNull(client.pendingFrame)
        } finally {
            client.remoteProcessDied(); watchdog.closeAsync(); fanOut.close()
        }
    }

    @Test
    fun normalSchedulerJitterCannotPreventSustainedBacklogDegradation() {
        val cleanup = Executors.newSingleThreadExecutor()
        val scheduler = CadenceExecutor()
        val owner = StreamingInferenceOwner(AutoCloseable { }, cleanup)
        val watchdog = StreamingBacklogWatchdog(16000,
            { PcmInferenceBacklog(listOf(CanonicalPcmInterval(0, 96000, 0)), 1, false) },
            owner, ScheduledStreamingSecondTicker(scheduler) { scheduler.nowMs })
        try {
            watchdog.start()
            // Rate deadlines produce 1001/2000/3001, delay deadlines 1001/2001/3002.
            // Expectations use real watchdog/guard behavior, not scheduler call counts.
            scheduler.runNextWithJitter(1)
            scheduler.runNextWithJitter(0)
            scheduler.runNextWithJitter(1)
            assertEquals(StreamingStopCause.BACKLOG, watchdog.stopCause)
            assertEquals(3, watchdog.latestObservation?.consecutiveOverloadObservations)
            watchdog.closeAsync().toCompletableFuture().get(2, TimeUnit.SECONDS)
        } finally { watchdog.closeAsync(); scheduler.shutdownNow(); cleanup.shutdownNow() }
    }

    @Test
    fun actualClockCanDegradeWhileInferenceIsStalled() {
        val cleanup = Executors.newSingleThreadExecutor()
        val clock = Executors.newSingleThreadScheduledExecutor()
        val fanOut = PriorityPcmFanOut(4, 4, {})
        val entered = CountDownLatch(1)
        val allowExit = CountDownLatch(1)
        val degraded = CountDownLatch(1)
        val releases = AtomicInteger()
        val decoderThread = AtomicReference<Thread>()
        val owner = StreamingInferenceOwner(AutoCloseable { releases.incrementAndGet() }, cleanup)
        val origin = System.nanoTime()
        val watchdog = StreamingBacklogWatchdog(16000, {
            assertNotSame(decoderThread.get(), Thread.currentThread())
            fanOut.inferenceBacklog()
        }, owner, ScheduledStreamingSecondTicker(clock) { (System.nanoTime() - origin) / 1000000 },
            { _, _ -> degraded.countDown() })
        try {
            fanOut.replaceInferenceConsumer {
                owner.runInference {
                    decoderThread.set(Thread.currentThread())
                    entered.countDown()
                    while (allowExit.count > 0) {
                        try { allowExit.await(20, TimeUnit.MILLISECONDS) } catch (_: InterruptedException) { }
                    }
                    1
                }
            }
            fanOut.publish(PcmCaptureFrame(0, ByteArray(192000), 0))
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            watchdog.start()
            assertTrue(degraded.await(6, TimeUnit.SECONDS))
            assertEquals(StreamingStopCause.BACKLOG, watchdog.stopCause)
            assertEquals(3, watchdog.latestObservation?.consecutiveOverloadObservations)
            assertFalse(watchdog.closeAsync().toCompletableFuture().isDone)
            assertEquals(0, releases.get())
            assertTrue(fanOut.awaitCanonicalProcessed(1, 2000))
            assertTrue(fanOut.shutdown())
            allowExit.countDown()
            watchdog.closeAsync().toCompletableFuture().get(2, TimeUnit.SECONDS)
            assertEquals(1, releases.get())
        } finally {
            allowExit.countDown(); watchdog.closeAsync(); fanOut.close()
            clock.shutdownNow(); cleanup.shutdownNow()
        }
    }

    @Test
    fun lateTicksAndExplicitPressureReleaseOnce() {
        val cleanup = Executors.newSingleThreadExecutor()
        try {
            for (cause in listOf(StreamingStopCause.THERMAL, StreamingStopCause.MEMORY,
                                  StreamingStopCause.ENGINE, StreamingStopCause.MODEL_UNAVAILABLE)) {
                val ticker = ManualSecondTicker()
                val releases = AtomicInteger()
                val notifications = AtomicInteger()
                val owner = StreamingInferenceOwner(AutoCloseable { releases.incrementAndGet() }, cleanup)
                val watchdog = StreamingBacklogWatchdog(16000, { PcmInferenceBacklog(emptyList(), 0, false) },
                    owner, ticker, { _, _ -> notifications.incrementAndGet() })
                watchdog.start(); watchdog.start(); ticker.fire(1000)
                watchdog.degrade(cause).toCompletableFuture().get(2, TimeUnit.SECONDS)
                ticker.fire(2000); watchdog.start(); watchdog.degrade(StreamingStopCause.ENGINE)
                watchdog.closeAsync().toCompletableFuture().get(2, TimeUnit.SECONDS)
                assertEquals(cause, watchdog.stopCause)
                assertEquals(1, releases.get()); assertEquals(1, notifications.get())
                assertEquals(1, ticker.subscriptions); assertEquals(1, ticker.cancellations)
            }
        } finally { cleanup.shutdownNow() }
    }

    @Test
    fun snapshotAndNotificationFailuresStillRelease() {
        val cleanup = Executors.newSingleThreadExecutor()
        try {
            for (memoryFailure in listOf(false, true)) {
                val ticker = ManualSecondTicker()
                val releases = AtomicInteger()
                val owner = StreamingInferenceOwner(AutoCloseable { releases.incrementAndGet() }, cleanup)
                val watchdog = StreamingBacklogWatchdog(16000, {
                    if (memoryFailure) throw OutOfMemoryError("native memory") else error("snapshot failed")
                }, owner, ticker, { _, _ -> error("notification failed") })
                watchdog.start(); ticker.fire(1000)
                watchdog.closeAsync().toCompletableFuture().get(2, TimeUnit.SECONDS)
                assertEquals(if (memoryFailure) StreamingStopCause.MEMORY else StreamingStopCause.ENGINE,
                    watchdog.stopCause)
                assertEquals(1, releases.get())
            }
        } finally { cleanup.shutdownNow() }
    }

    @Test
    fun closeDuringLateSnapshotDoesNotEmitFailure() {
        val cleanup = Executors.newSingleThreadExecutor()
        val sampler = Executors.newSingleThreadExecutor()
        val entered = CountDownLatch(1)
        val allowSnapshot = CountDownLatch(1)
        val ticker = ManualSecondTicker()
        val notifications = AtomicInteger()
        val releases = AtomicInteger()
        val owner = StreamingInferenceOwner(AutoCloseable { releases.incrementAndGet() }, cleanup)
        val watchdog = StreamingBacklogWatchdog(16000, {
            entered.countDown(); check(allowSnapshot.await(3, TimeUnit.SECONDS))
            PcmInferenceBacklog(emptyList(), 1, true)
        }, owner, ticker, { _, _ -> notifications.incrementAndGet() })
        try {
            watchdog.start()
            val sampling = sampler.submit { ticker.fire(1000) }
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            watchdog.closeAsync().toCompletableFuture().get(2, TimeUnit.SECONDS)
            assertEquals(1, releases.get())
            allowSnapshot.countDown(); sampling.get(2, TimeUnit.SECONDS)
            ticker.fire(2000)
            assertEquals(0, notifications.get()); assertNull(watchdog.stopCause)
        } finally {
            allowSnapshot.countDown(); watchdog.closeAsync()
            sampler.shutdownNow(); cleanup.shutdownNow()
        }
    }

    @Test
    fun subscribeFailureClosesOwnerAndRepeatedStartIsHarmless() {
        val cleanup = Executors.newSingleThreadExecutor()
        val releases = AtomicInteger()
        try {
            val owner = StreamingInferenceOwner(AutoCloseable { releases.incrementAndGet() }, cleanup)
            val watchdog = StreamingBacklogWatchdog(16000, { PcmInferenceBacklog(emptyList(), 0, false) },
                owner, StreamingSecondTicker { throw RejectedExecutionException() })
            watchdog.start(); watchdog.start()
            watchdog.closeAsync().toCompletableFuture().get(2, TimeUnit.SECONDS)
            assertEquals(StreamingStopCause.ENGINE, watchdog.stopCause)
            assertEquals(1, releases.get())
        } finally { cleanup.shutdownNow() }
    }
}

private class ManualSecondTicker : StreamingSecondTicker {
    private var action: ((Long) -> Unit)? = null
    var subscriptions = 0
    var cancellations = 0
    override fun subscribe(observe: (Long) -> Unit): AutoCloseable {
        subscriptions += 1; action = observe
        return AutoCloseable { cancellations += 1 }
    }
    fun fire(now: Long) { action?.invoke(now) }
}

/** Virtual scheduled-executor semantics, with caller-chosen real-start jitter. */
private class CadenceExecutor : ScheduledThreadPoolExecutor(1) {
    var nowMs = 0L
        private set
    private var dueMs = 0L
    private var periodMs = 0L
    private var fixedDelay = false
    private var action: Runnable? = null
    private var scheduled: ScheduledFuture<*>? = null

    override fun scheduleAtFixedRate(command: Runnable, initialDelay: Long, period: Long, unit: TimeUnit): ScheduledFuture<*> =
        register(command, initialDelay, period, unit, false)

    override fun scheduleWithFixedDelay(command: Runnable, initialDelay: Long, delay: Long, unit: TimeUnit): ScheduledFuture<*> =
        register(command, initialDelay, delay, unit, true)

    private fun register(command: Runnable, initialDelay: Long, period: Long, unit: TimeUnit, delay: Boolean): ScheduledFuture<*> {
        action = command; dueMs = nowMs + unit.toMillis(initialDelay)
        periodMs = unit.toMillis(period); fixedDelay = delay
        return super.schedule({}, 365, TimeUnit.DAYS).also { scheduled = it }
    }

    fun runNextWithJitter(jitterMs: Long) {
        if (scheduled?.isCancelled == true) return
        nowMs = dueMs + jitterMs
        action?.run()
        dueMs = (if (fixedDelay) nowMs else dueMs) + periodMs
    }
}
