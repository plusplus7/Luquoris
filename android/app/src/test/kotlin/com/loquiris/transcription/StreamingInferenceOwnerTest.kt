package com.loquiris.transcription

import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.*
import org.junit.Test

class StreamingInferenceOwnerTest {
    @Test
    fun closeWaitsForNativeWorkWithoutBlockingCaller() {
        val cleanup = Executors.newSingleThreadExecutor()
        val worker = Executors.newSingleThreadExecutor()
        val entered = CountDownLatch(1)
        val allowExit = CountDownLatch(1)
        val released = AtomicInteger()
        val owner = StreamingInferenceOwner(AutoCloseable { released.incrementAndGet() }, cleanup)
        try {
            val result = worker.submit<Int?> {
                owner.runInference { entered.countDown(); check(allowExit.await(3, TimeUnit.SECONDS)); 42 }
            }
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            val closing = owner.closeAsync()
            assertFalse(closing.toCompletableFuture().isDone)
            assertEquals(0, released.get())
            assertNull(owner.runInference { error("closed owner must not run another operation") })
            allowExit.countDown()
            assertNull(result.get(2, TimeUnit.SECONDS))
            closing.toCompletableFuture().get(2, TimeUnit.SECONDS)
            assertEquals(1, released.get())
            assertSame(closing, owner.closeAsync())
        } finally {
            allowExit.countDown(); worker.shutdownNow(); cleanup.shutdownNow()
        }
    }

    @Test
    fun operationFailureClosesResourcesAndRejectsLaterWork() {
        val cleanup = Executors.newSingleThreadExecutor()
        try {
            for (failure in listOf(IllegalStateException("engine"), OutOfMemoryError("memory"))) {
                val releases = AtomicInteger()
                val owner = StreamingInferenceOwner(AutoCloseable { releases.incrementAndGet() }, cleanup)
                val caught = assertThrows(Throwable::class.java) { owner.runInference<Int> { throw failure } }
                assertSame(failure, caught)
                assertNull(owner.runInference { error("failed owner must reject new input") })
                owner.closeAsync().toCompletableFuture().get(2, TimeUnit.SECONDS)
                assertEquals(1, releases.get())
            }
        } finally { cleanup.shutdownNow() }
    }

    @Test
    fun releaseFailureNeverAcknowledgesSuccess() {
        val cleanup = Executors.newSingleThreadExecutor()
        try {
            for (executor in listOf<Executor>(cleanup, Executor { throw RejectedExecutionException("private path") })) {
                val owner = StreamingInferenceOwner(AutoCloseable { error("sensitive native details") }, executor)
                val failure = assertThrows(ExecutionException::class.java) {
                    owner.closeAsync().toCompletableFuture().get(2, TimeUnit.SECONDS)
                }
                assertTrue(failure.cause is StreamingReleaseException)
                assertEquals("streaming_resource_release_failed", failure.cause?.message)
                assertNull(failure.cause?.cause)
                assertNull(owner.runInference { 1 })
            }
        } finally { cleanup.shutdownNow() }
    }

    @Test
    fun idleCloseAndRepeatedCloseFreeExactlyOnce() {
        val cleanup = Executors.newSingleThreadExecutor()
        val entered = CountDownLatch(1)
        val allowClose = CountDownLatch(1)
        val releases = AtomicInteger()
        val owner = StreamingInferenceOwner(AutoCloseable {
            entered.countDown(); check(allowClose.await(3, TimeUnit.SECONDS)); releases.incrementAndGet()
        }, cleanup)
        try {
            assertEquals(7, owner.runInference { 7 })
            val closing = owner.closeAsync()
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            // A caller can complete its own view, but cannot forge native release.
            closing.toCompletableFuture().complete(Unit)
            assertFalse(owner.closeAsync().toCompletableFuture().isDone)
            allowClose.countDown()
            owner.closeAsync().toCompletableFuture().get(2, TimeUnit.SECONDS)
            owner.closeAsync().toCompletableFuture().get(2, TimeUnit.SECONDS)
            assertEquals(1, releases.get())
        } finally { allowClose.countDown(); cleanup.shutdownNow() }
    }
}
