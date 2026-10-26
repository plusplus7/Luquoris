package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame
import com.loquiris.recording.PcmFanOutPublishResult
import com.loquiris.recording.PriorityPcmFanOut
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import org.junit.Assert.*
import org.junit.Test

class StreamingRuntimeReadinessTest {
    @Test fun loadingModelCannotHideThreeOverloadObservationsOrForgeRemoteRelease() {
        val dispatch = LinkedBlockingQueue<Runnable>()
        val commands = mutableListOf<StreamingRemoteCommand>()
        val identity = StreamingRemoteIdentity("loading", "binding")
        val remote = StreamingRemoteSession(identity, { commands.add(it) }, { dispatch.add(it) })
        val fanOut = PriorityPcmFanOut(512, 256, {})
        val ticker = ReadinessTicker()
        val cancelled = AtomicBoolean()
        val ready = CompletableFuture<StreamingStopCause?>()
        val worker = Executors.newSingleThreadExecutor()
        val watchdog = StreamingBacklogWatchdog(16000, fanOut::inferenceBacklog,
            StreamingReleaseOwner { remote.closeRemote() }, ticker,
            { _, _ -> cancelled.set(true) })
        try {
            remote.startRemote("a".repeat(64))
            requireNotNull(dispatch.poll(2, TimeUnit.SECONDS)).run()
            // Full 20-ms reads: 256 unique frames = 81,920 samples = 5.12 s.
            repeat(256) { i ->
                assertEquals(PcmFanOutPublishResult.accepted,
                    fanOut.publish(PcmCaptureFrame(i.toLong(), ByteArray(640), i * 320L)))
            }
            val starting = worker.submit<LiveDraftStartResult> {
                awaitStreamingRuntimeReady(ready, cancelled::get, watchdog)
            }
            assertTrue("Observe retained capture before model Ready", ticker.subscribed.await(1, TimeUnit.SECONDS))
            assertFalse(ready.isDone)
            ticker.fire(1000)
            assertNull(watchdog.stopCause)
            ticker.fire(2000)
            assertNull(watchdog.stopCause)
            ticker.fire(3000)
            assertEquals(StreamingStopCause.BACKLOG, watchdog.stopCause)
            assertEquals(81920L, watchdog.latestObservation?.uniqueSamples)
            assertEquals(LiveDraftStartResult.Failure("transcription_live_closed"), starting.get(2, TimeUnit.SECONDS))
            assertFalse(ready.isDone)
            requireNotNull(dispatch.poll(2, TimeUnit.SECONDS)).run()
            assertTrue(commands.last() is StreamingRemoteCommand.Close)
            val released = watchdog.closeAsync().toCompletableFuture()
            assertFalse(released.isDone)
            assertTrue(fanOut.awaitCanonicalProcessed(256, 2000))
            remote.receiveRemote(StreamingRemoteReply.Released(identity))
            released.get(2, TimeUnit.SECONDS)
        } finally {
            cancelled.set(true); ready.complete(null)
            remote.remoteProcessDied(); watchdog.closeAsync()
            worker.shutdownNow(); fanOut.close()
        }
    }

    @Test fun readyRuntimeKeepsMonitoringWithoutChangingItsTypedStartResult() {
        for ((cause, expected) in listOf(
            null to LiveDraftStartResult.Started,
            StreamingStopCause.MEMORY to LiveDraftStartResult.Failure("transcription_live_memory"),
            StreamingStopCause.THERMAL to LiveDraftStartResult.Failure("transcription_live_thermal"),
            StreamingStopCause.MODEL_UNAVAILABLE to LiveDraftStartResult.Failure("transcription_model_unavailable"),
            StreamingStopCause.ENGINE to LiveDraftStartResult.Failure("transcription_live_engine_failed"),
        )) {
            val ticker = ReadinessTicker()
            val watchdog = StreamingBacklogWatchdog(16000,
                { com.loquiris.recording.PcmInferenceBacklog(emptyList(), 0, false) },
                StreamingReleaseOwner { CompletableFuture.completedFuture(Unit) }, ticker)
            try {
                assertEquals(expected, awaitStreamingRuntimeReady(CompletableFuture.completedFuture(cause), { false }, watchdog))
                if (cause == null) {
                    ticker.fire(1000)
                    assertEquals(0L, watchdog.latestObservation?.uniqueSamples)
                    assertNull(watchdog.stopCause)
                }
            } finally { watchdog.closeAsync().toCompletableFuture().get(2, TimeUnit.SECONDS) }
        }
    }
}

private class ReadinessTicker : StreamingSecondTicker {
    val subscribed = CountDownLatch(1)
    @Volatile private var action: ((Long) -> Unit)? = null
    override fun subscribe(observe: (Long) -> Unit): AutoCloseable {
        action = observe; subscribed.countDown()
        return AutoCloseable { action = null }
    }
    fun fire(now: Long) { requireNotNull(action).invoke(now) }
}
