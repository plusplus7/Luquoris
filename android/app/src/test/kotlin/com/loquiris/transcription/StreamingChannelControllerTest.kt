package com.loquiris.transcription

import java.util.ArrayDeque
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CompletionStage
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import org.junit.Assert.*
import org.junit.Test

class StreamingChannelControllerTest {
    @Test fun cancellationReachesLeaseWhileStopReleaseIsPending() {
        val h = Harness()
        h.openReady(request())
        h.controller.handle("close", close("stopped"), h.replies::add)
        h.controller.handle("close", close("cancelled"), h.replies::add)
        assertEquals(listOf(StreamingPlatformCloseReason.STOPPED, StreamingPlatformCloseReason.CANCELLED), h.lease.closeReasons)
        h.events(h.text(0).copy(finalized = true))
        h.delivery.drain()
        assertTrue(h.published.isEmpty())
        assertEquals(1, h.replies.size)
        h.lease.released.complete(Unit)
        h.delivery.drain()
        assertEquals(3, h.replies.size)
        assertTrue(h.replies.drop(1).all { it["released"] == true })
    }

    private val owner = StreamingPlatformOwner("meeting", "live", 7)
    private fun header(value: StreamingPlatformOwner = owner) = StreamingChannelContract.header(value)
    private fun request(value: StreamingPlatformOwner = owner) = header(value) + mapOf("modelId" to "debug-zipformer",
        "bundleSha256" to "a".repeat(64), "parameterVersion" to 1)
    private fun close(reason: String = "cancelled", value: StreamingPlatformOwner = owner) = header(value) + ("reason" to reason)

    @Test fun disabledAndMalformedRequestsNeverAllocate() {
        val disabled = Harness(false)
        disabled.controller.handle("open", request(), disabled.replies::add)
        disabled.creation.drain()
        disabled.delivery.drain()
        assertEquals(0, disabled.creations)
        assertEquals(1, disabled.replies.size)
        assertEquals("modelUnavailable", disabled.replies.single()["reason"])
        assertEquals(true, disabled.replies.single()["released"])
        val enabled = Harness()
        enabled.controller.handle("open", request() + ("path" to "/private"), enabled.replies::add)
        enabled.creation.drain()
        enabled.delivery.drain()
        assertEquals(0, enabled.creations)
        assertEquals(1, enabled.replies.size)
        assertEquals(false, enabled.replies.single()["ok"])
    }

    @Test fun pendingAcquisitionReservesMeetingAndCloseWaitsForRealRelease() {
        val h = Harness()
        h.controller.handle("open", request(), h.replies::add)
        h.controller.handle("open", request(owner.copy(runId = "next")), h.replies::add)
        h.controller.handle("close", close(), h.replies::add)
        h.delivery.drain()
        assertEquals(1, h.replies.size)
        assertEquals("alreadyOwned", h.replies.single()["reason"])
        h.creation.drain()
        assertEquals(listOf(StreamingPlatformCloseReason.CANCELLED), h.lease.closeReasons)
        assertEquals(0, h.lease.starts)
        h.delivery.drain()
        assertEquals(1, h.replies.size)
        h.lease.released.complete(Unit)
        h.delivery.drain()
        assertEquals(3, h.replies.size)
        assertEquals("closed", h.replies[1]["reason"])
        assertEquals(true, h.replies[2]["released"])
        assertEquals(true, h.replies[2]["ok"])
    }

    @Test fun readyAndCallbacksRequireCurrentBindingAndIncreasingSequence() {
        val h = Harness()
        h.controller.handle("open", request(), h.replies::add)
        h.creation.drain()
        assertEquals(1, h.creations)
        h.delivery.drain()
        assertTrue(h.replies.isEmpty())
        h.lease.ready.complete(null)
        h.delivery.drain()
        assertEquals(false, h.replies.single()["released"])
        h.events(h.text(0).copy(owner = h.identity.copy(epoch = "old")))
        h.events(h.text(1))
        h.events(h.text(1))
        h.events(h.text(0))
        h.delivery.drain()
        assertEquals(1, h.published.size)
        assertEquals("中文 API", h.published.single()["rawText"])
        assertEquals(3200L, h.published.single()["startSample"])
    }

    @Test fun duplicateExactOwnerDoesNotFalselyConfirmReleaseOfExistingLease() {
        val h = Harness()
        h.openReady(request())
        h.controller.handle("open", request(), h.replies::add)
        h.delivery.drain()
        assertEquals("alreadyOwned", h.replies.last()["reason"])
        assertEquals(false, h.replies.last()["released"])
        assertTrue(h.lease.closeReasons.isEmpty())
        h.events(h.text(0))
        h.delivery.drain()
        assertEquals(1, h.published.size)
    }

    @Test fun unknownOwnerOnNewControllerCannotProveOldControllerReleasedIt() {
        val old = Harness()
        old.openReady(request())
        old.controller.closeOwner()
        assertFalse(old.lease.released.isDone)
        val replacement = Harness()
        replacement.controller.handle("close", close(), replacement.replies::add)
        replacement.delivery.drain()
        assertEquals(false, replacement.replies.single()["released"])
        assertEquals("closed", replacement.replies.single()["reason"])
    }

    @Test fun cancellationFencesQueuedTextButDoesNotAcknowledgeBeforeRelease() {
        val h = Harness()
        h.openReady(request())
        h.events(h.text(0))
        h.controller.handle("close", close(), h.replies::add)
        h.delivery.drain()
        assertTrue(h.published.isEmpty())
        assertEquals(1, h.replies.size)
        h.lease.released.complete(Unit)
        h.delivery.drain()
        assertEquals(true, h.replies.last()["released"])
        h.events(h.text(1))
        h.delivery.drain()
        assertTrue(h.published.isEmpty())
    }

    @Test fun stopAllowsFinalTextAndCloseIsIdempotentAfterAcknowledgement() {
        val h = Harness()
        h.openReady(request())
        h.controller.handle("close", close("stopped"), h.replies::add)
        h.events(h.text(0).copy(finalized = true))
        h.delivery.drain()
        assertEquals(true, h.published.single()["finalized"])
        h.lease.released.complete(Unit)
        h.delivery.drain()
        h.controller.handle("close", close("stopped"), h.replies::add)
        h.delivery.drain()
        assertEquals(1, h.lease.closeReasons.size)
        assertEquals(true, h.replies.last()["released"])
    }

    @Test fun degradationIsPublishedOnlyAfterReleaseAndRetainsOriginalCause() {
        val h = Harness()
        h.openReady(request())
        h.failure(StreamingStopCause.MEMORY)
        h.delivery.drain()
        assertTrue(h.published.isEmpty())
        assertEquals(1, h.lease.closeReasons.size)
        h.lease.released.complete(Unit)
        h.delivery.drain()
        assertEquals("failure", h.published.single()["type"])
        assertEquals("memory", h.published.single()["reason"])
        assertEquals(true, h.published.single()["released"])
    }

    @Test fun failedCloseRetainsLeaseAndCanBeRetriedWithoutRecreating() {
        val h = Harness()
        h.openReady(request())
        h.controller.handle("close", close(), h.replies::add)
        h.lease.released.completeExceptionally(IllegalStateException("private failure"))
        h.delivery.drain()
        assertEquals(false, h.replies.last()["released"])
        h.controller.handle("open", request(owner.copy(runId = "next")), h.replies::add)
        h.delivery.drain()
        assertEquals("alreadyOwned", h.replies.last()["reason"])
        h.lease.released = CompletableFuture()
        h.controller.handle("close", close(), h.replies::add)
        h.lease.released.complete(Unit)
        h.delivery.drain()
        assertEquals(true, h.replies.last()["released"])
        assertEquals(1, h.creations)
        assertEquals(2, h.lease.closeReasons.size)
    }

    @Test fun controllerClosureCancelsAllOwnersBeforeAnyRelease() {
        val h = Harness()
        h.openReady(request())
        h.controller.handle("open", request(owner.copy(meetingId = "second", runId = "other")), h.replies::add)
        h.creation.drain()
        h.controller.closeOwner()
        val reasons = h.leases.flatMap { it.closeReasons }
        assertEquals(2, reasons.size)
        assertTrue(reasons.all { it == StreamingPlatformCloseReason.CANCELLED })
        h.controller.handle("open", request(owner.copy(meetingId = "third")), h.replies::add)
        h.delivery.drain()
        assertEquals("closed", h.replies.last()["reason"])
    }

    @Test fun concurrentCloseCannotAcknowledgeReleaseBeforeStartAllocatesAgain() {
        val creation = Executors.newSingleThreadExecutor()
        val closing = Executors.newSingleThreadExecutor()
        var resurrected = 0
        try {
            repeat(300) {
                val enteredStart = CountDownLatch(1)
                val live = AtomicBoolean()
                val lease = object : StreamingPlatformLease {
                    override fun start(): CompletionStage<StreamingStopCause?> {
                        enteredStart.countDown()
                        // Real scheduler preemption during a short, nonblocking start.
                        repeat(32) { Thread.yield() }
                        live.set(true)
                        return CompletableFuture.completedFuture(null)
                    }
                    override fun close(reason: StreamingPlatformCloseReason): CompletionStage<Unit> {
                        live.set(false)
                        return CompletableFuture.completedFuture(Unit)
                    }
                }
                val controller = StreamingChannelController(true,
                    StreamingPlatformLeaseFactory { _, _, _, _ -> lease }, creation,
                    Executor { it.run() }, {}, { "fresh-$it" })
                controller.handle("open", request()) { }
                closing.submit {
                    assertTrue(enteredStart.await(2, TimeUnit.SECONDS))
                    controller.handle("close", close()) { }
                }.get(3, TimeUnit.SECONDS)
                creation.submit { }.get(3, TimeUnit.SECONDS)
                if (live.get()) resurrected++
            }
            assertEquals("native allocations observed after acknowledged close", 0, resurrected)
        } finally {
            creation.shutdownNow()
            closing.shutdownNow()
        }
    }

    private class Queue : Executor {
        private val tasks = ArrayDeque<Runnable>()
        override fun execute(command: Runnable) { tasks.add(command) }
        fun drain() { while (tasks.isNotEmpty()) tasks.removeFirst().run() }
    }
    private class Lease : StreamingPlatformLease {
        val ready = CompletableFuture<StreamingStopCause?>()
        var released = CompletableFuture<Unit>()
        var starts = 0
        val closeReasons = mutableListOf<StreamingPlatformCloseReason>()
        override fun start(): CompletionStage<StreamingStopCause?> { starts++; return ready }
        override fun close(reason: StreamingPlatformCloseReason): CompletionStage<Unit> {
            closeReasons.add(reason)
            return released
        }
    }
    private class Harness(enabled: Boolean = true) {
        val creation = Queue()
        val delivery = Queue()
        val lease = Lease()
        val leases = mutableListOf(lease)
        val replies = mutableListOf<Map<String, Any>>()
        val published = mutableListOf<Map<String, Any>>()
        var creations = 0
        lateinit var identity: StreamingRemoteIdentity
        lateinit var events: (StreamingCaptureEvent) -> Unit
        lateinit var failure: (StreamingStopCause) -> Unit
        val controller = StreamingChannelController(enabled, StreamingPlatformLeaseFactory { _, remote, event, degraded ->
            val created = if (creations == 0) lease else Lease().also { leases.add(it) }
            creations++; identity = remote; events = event; failure = degraded; created
        }, creation, delivery, published::add, { "binding-$creations" })
        fun text(sequence: Long) = StreamingCaptureText(identity, sequence, "utterance-1", 3200, 6400, 0, "中文 API", false)
        fun openReady(request: Map<String, Any>) {
            controller.handle("open", request, replies::add)
            creation.drain()
            assertEquals(1, creations)
            assertEquals(1, lease.starts)
            lease.ready.complete(null)
            delivery.drain()
        }
    }
}
