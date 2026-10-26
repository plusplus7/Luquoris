package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CompletionStage
import java.util.concurrent.Executor

/** Unique per binding; never reuse an identity for a restarted process. */
data class StreamingRemoteIdentity(val runId: String, val epoch: String)

sealed interface StreamingRemoteCommand {
    val owner: StreamingRemoteIdentity
    data class Open(override val owner: StreamingRemoteIdentity, val bundleDigest: String) : StreamingRemoteCommand
    data class Pcm(override val owner: StreamingRemoteIdentity, val requestId: Long, val frame: PcmCaptureFrame) : StreamingRemoteCommand
    data class Finish(override val owner: StreamingRemoteIdentity, val requestId: Long) : StreamingRemoteCommand
    data class Close(override val owner: StreamingRemoteIdentity) : StreamingRemoteCommand
}

sealed interface StreamingRemoteReply {
    val owner: StreamingRemoteIdentity
    data class Ready(override val owner: StreamingRemoteIdentity) : StreamingRemoteReply
    data class Text(override val owner: StreamingRemoteIdentity, val requestId: Long, val text: String, val endpoint: Boolean) : StreamingRemoteReply
    data class Released(override val owner: StreamingRemoteIdentity) : StreamingRemoteReply
    data class Failure(override val owner: StreamingRemoteIdentity, val cause: StreamingStopCause) : StreamingRemoteReply
    /** Server positively confirms this owner was never adopted/created. */
    data class Rejected(override val owner: StreamingRemoteIdentity, val cause: StreamingStopCause) : StreamingRemoteReply
}

sealed interface StreamingRemoteResult {
    data class Text(val text: String, val endpoint: Boolean) : StreamingRemoteResult
    data object Cancelled : StreamingRemoteResult
    data class Failed(val cause: StreamingStopCause) : StreamingRemoteResult
}

fun interface StreamingRemoteTransport {
    /** Called on the dedicated outbound executor, never the capture callback. */
    fun send(command: StreamingRemoteCommand)
}

private class StreamingRemoteStage<T>(private val root: CompletableFuture<T>) : CompletionStage<T> by root {
    override fun toCompletableFuture(): CompletableFuture<T> = root.thenApply { it }
}

/**
 * One in-flight PCM or explicit-finish request. No send/timeout proves completion.
 * Outbound must be a dedicated FIFO, asynchronous, nonblocking dispatcher,
 * owned by the adapter until release/death; never use a direct executor.
 * Keep the capture fan-out consumer waiting on the returned stage so its
 * in-flight ledger retains this frame until remote inference actually settles.
 * A finish shares that admission slot but adds no unique captured audio.
 * CompletionStage callbacks can run on the protocol delivery thread: keep them
 * nonblocking or use the async variants with an adapter-owned executor. Release
 * callbacks must not wait for a pending-result callback; release is published
 * first so pending consumers may observe that resources are already settled.
 */
class StreamingRemoteSession(
    private val identity: StreamingRemoteIdentity,
    private val transport: StreamingRemoteTransport,
    private val outbound: Executor,
    private val onFailure: (StreamingStopCause) -> Unit = {},
) {
    private data class Pending(val id: Long, val frame: PcmCaptureFrame?, val result: CompletableFuture<StreamingRemoteResult>)
    private val lock = Any()
    private val release = CompletableFuture<Unit>()
    private val releaseStage = StreamingRemoteStage(release)
    private var started = false
    private var ready = false
    private var closing = false
    private var released = false
    private var nextId = 0L
    private var pending: Pending? = null
    private var failure: StreamingStopCause? = null

    init {
        require(identity.runId.isNotBlank() && identity.runId.length <= 256)
        require(identity.epoch.isNotBlank() && identity.epoch.length <= 256)
    }

    val ownerIdentity: StreamingRemoteIdentity get() = identity
    val pendingFrame: PcmCaptureFrame? get() = synchronized(lock) { pending?.frame }
    val releaseAcknowledgement: CompletionStage<Unit> get() = releaseStage

    /** No media samples are attributed to this flush/reset request. */
    fun finishRemoteUtterance(): CompletionStage<StreamingRemoteResult>? {
        val admitted: Pending
        val dispatchFailure = synchronized(lock) {
            if (!ready || closing || released || pending != null || nextId == Long.MAX_VALUE) return null
            admitted = Pending(nextId++, null, CompletableFuture())
            pending = admitted
            dispatchRemote(StreamingRemoteCommand.Finish(identity, admitted.id))
        }
        dispatchFailure?.let(::failRemote)
        return StreamingRemoteStage(admitted.result)
    }

    /** A broken link requests degradation but is not proof the process died. */
    fun remoteTransportFailed(cause: StreamingStopCause = StreamingStopCause.ENGINE) = failRemote(cause)

    fun startRemote(bundleDigest: String) {
        require(bundleDigest.matches(Regex("[a-f0-9]{64}")))
        val dispatchFailure = synchronized(lock) {
            if (started || closing || released) return
            started = true
            dispatchRemote(StreamingRemoteCommand.Open(identity, bundleDigest))
        }
        dispatchFailure?.let(::failRemote)
    }

    /** Null is admission rejection, not completed inference. Bound payload to 1s. */
    fun submitRemote(frame: PcmCaptureFrame): CompletionStage<StreamingRemoteResult>? {
        val start = frame.canonicalStartSample ?: return null
        val end = frame.canonicalEndSampleExclusive ?: return null
        if (end - start !in 1..16000L) return null
        val admitted: Pending
        val dispatchFailure = synchronized(lock) {
            if (!ready || closing || released || pending != null || nextId == Long.MAX_VALUE) return null
            admitted = Pending(nextId++, frame, CompletableFuture())
            pending = admitted
            dispatchRemote(StreamingRemoteCommand.Pcm(identity, admitted.id, frame))
        }
        dispatchFailure?.let(::failRemote)
        return StreamingRemoteStage(admitted.result)
    }

    fun receiveRemote(reply: StreamingRemoteReply) {
        if (reply.owner != identity) return
        var completed: Pending? = null
        var result: StreamingRemoteResult? = null
        var didRelease = false
        var remoteFailure: StreamingStopCause? = null
        var rejectedFailure: StreamingStopCause? = null
        synchronized(lock) {
            if (released) return
            when (reply) {
                is StreamingRemoteReply.Ready -> if (started && !closing) ready = true
                is StreamingRemoteReply.Text -> {
                    val active = pending ?: return
                    if (reply.requestId != active.id) return
                    if (active.frame == null && !reply.endpoint && !closing && failure == null) {
                        // A matching but nonfinal flush reply violates the contract.
                        // Retain ownership until release/death, not this malformed ACK.
                        remoteFailure = StreamingStopCause.ENGINE
                    } else {
                        completed = active
                        pending = null
                        result = when {
                            failure != null -> StreamingRemoteResult.Failed(requireNotNull(failure))
                            closing -> StreamingRemoteResult.Cancelled
                            else -> StreamingRemoteResult.Text(reply.text, reply.endpoint)
                        }
                    }
                }
                is StreamingRemoteReply.Released -> {
                    if (!closing) return
                    released = true
                    completed = pending
                    pending = null
                    result = failure?.let { StreamingRemoteResult.Failed(it) } ?: StreamingRemoteResult.Cancelled
                    didRelease = true
                }
                is StreamingRemoteReply.Failure -> remoteFailure = reply.cause
                is StreamingRemoteReply.Rejected -> {
                    if (!started || ready || pending != null) return
                    if (failure == null) rejectedFailure = reply.cause
                    failure = failure ?: reply.cause
                    closing = true
                    released = true
                    didRelease = true
                }
            }
        }
        // Completion callbacks and notifications run outside the state lock.
        if (didRelease) release.complete(Unit)
        completed?.result?.complete(requireNotNull(result))
        remoteFailure?.let(::failRemote)
        rejectedFailure?.let { runCatching { onFailure(it) } }
    }

    /** Only the adapter's confirmed death callback may call this, never timeout. */
    fun remoteProcessDied() {
        val active: Pending?
        val cause: StreamingStopCause
        val notify: Boolean
        synchronized(lock) {
            if (released) return
            notify = failure == null && started
            cause = failure ?: StreamingStopCause.ENGINE
            failure = cause
            closing = true
            released = true
            active = pending
            pending = null
        }
        release.complete(Unit)
        active?.result?.complete(StreamingRemoteResult.Failed(cause))
        if (notify) runCatching { onFailure(cause) }
    }

    fun closeRemote(): CompletionStage<Unit> {
        var localRelease = false
        val dispatchFailure = synchronized(lock) {
            if (closing || released) return releaseStage
            closing = true
            if (!started) {
                released = true
                localRelease = true
                null
            } else dispatchRemote(StreamingRemoteCommand.Close(identity))
        }
        if (localRelease) release.complete(Unit)
        dispatchFailure?.let(::failRemote)
        return releaseStage
    }

    /** Called under lock: dispatch admission is FIFO with state admission. */
    private fun dispatchRemote(command: StreamingRemoteCommand): StreamingStopCause? = try {
        outbound.execute {
            if (!synchronized(lock) { released }) {
                try { transport.send(command) } catch (_: OutOfMemoryError) {
                    failRemote(StreamingStopCause.MEMORY)
                } catch (_: Throwable) { failRemote(StreamingStopCause.ENGINE) }
            }
        }
        null
    } catch (_: OutOfMemoryError) {
        StreamingStopCause.MEMORY
    } catch (_: Throwable) {
        StreamingStopCause.ENGINE
    }

    private fun failRemote(cause: StreamingStopCause) {
        var localRelease = false
        synchronized(lock) {
            if (released || failure != null) return
            failure = cause
            if (!started) {
                closing = true
                released = true
                localRelease = true
            } else if (!closing) {
                closing = true
                // Even a failed close send must not acknowledge release.
                dispatchRemote(StreamingRemoteCommand.Close(identity))
            }
        }
        if (localRelease) release.complete(Unit)
        runCatching { onFailure(cause) }
    }
}
