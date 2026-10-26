package com.loquiris.transcription

import java.util.concurrent.CompletableFuture
import java.util.concurrent.CompletionStage
import java.util.concurrent.Executor

/** Stable release failure; never leaks a native exception or filesystem path. */
class StreamingReleaseException : RuntimeException("streaming_resource_release_failed")

/** Read-only stage using API-24 operations, rather than API-31 minimalCompletionStage. */
private class StreamingReleaseStage(private val delegate: CompletableFuture<Unit>) : CompletionStage<Unit> by delegate {
    override fun toCompletableFuture(): CompletableFuture<Unit> = delegate.thenApply { it }
}

/** Nonblocking release request; success requires actual release or confirmed process death. */
fun interface StreamingReleaseOwner {
    fun closeAsync(): CompletionStage<Unit>
}

/**
 * Owns an already-created resource for a single inference worker.
 * Cleanup must use an asynchronously dispatching executor whose lifetime extends
 * through the close acknowledgement; never pass a direct/caller-runs executor.
 * Resource creation and event delivery/owner filtering belong to the adapter.
 */
class StreamingInferenceOwner<T : AutoCloseable>(private val resource: T, private val cleanupExecutor: Executor) : StreamingReleaseOwner {
    private val lock = Any()
    private val completion = CompletableFuture<Unit>()
    private val acknowledgement: CompletionStage<Unit> = StreamingReleaseStage(completion)
    private var closing = false
    private var inFlight = false
    private var releaseClaimed = false

    /** Reject closed work and discard a result if closure won during inference. */
    fun <R : Any> runInference(operation: (T) -> R): R? {
        synchronized(lock) {
            if (closing) return null
            check(!inFlight) { "streaming_owner_requires_single_worker" }
            inFlight = true
        }
        try {
            val result = operation(resource)
            return synchronized(lock) { if (closing) null else result }
        } catch (failure: Throwable) {
            closeAsync()
            throw failure
        } finally {
            synchronized(lock) { inFlight = false }
            releaseIfIdle()
        }
    }

    /** Nonblocking request; success acknowledges actual release, not cancellation. */
    override fun closeAsync(): CompletionStage<Unit> {
        synchronized(lock) { closing = true }
        releaseIfIdle()
        return acknowledgement
    }

    private fun releaseIfIdle() {
        val shouldRelease = synchronized(lock) {
            if (!closing || inFlight || releaseClaimed) false else {
                releaseClaimed = true
                true
            }
        }
        if (!shouldRelease) return
        try {
            cleanupExecutor.execute(::releaseResource)
        } catch (_: Throwable) {
            completion.completeExceptionally(StreamingReleaseException())
        }
    }

    private fun releaseResource() {
        try {
            resource.close()
            completion.complete(Unit)
        } catch (_: Throwable) {
            completion.completeExceptionally(StreamingReleaseException())
        }
    }
}
