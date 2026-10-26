package com.loquiris.transcription

import java.util.concurrent.CompletionStage
import java.util.concurrent.Executor

/** A nonblocking native lease; only a completed close proves release. */
interface StreamingPlatformLease {
    fun start(): CompletionStage<StreamingStopCause?>
    fun close(reason: StreamingPlatformCloseReason): CompletionStage<Unit>
}

/** Construction must return an owned lease, or throw without retaining resources. */
fun interface StreamingPlatformLeaseFactory {
    fun create(request: StreamingPlatformStart, identity: StreamingRemoteIdentity,
        events: (StreamingCaptureEvent) -> Unit, failure: (StreamingStopCause) -> Unit): StreamingPlatformLease
}

/**
 * Plain controller; model/PCM work belongs to the factory's native workers.
 * Creation uses a dedicated asynchronous executor. Replies/events use one FIFO
 * executor; callbacks and lease start/close must never wait for native work.
 */
class StreamingChannelController(
    private val enabled: Boolean,
    private val factory: StreamingPlatformLeaseFactory,
    private val creationExecutor: Executor,
    private val replyExecutor: Executor,
    private val emit: (Map<String, Any>) -> Unit,
    private val bindingEpoch: () -> String,
) {
    private class Entry(val request: StreamingPlatformStart, val identity: StreamingRemoteIdentity,
        val openReply: (Map<String, Any>) -> Unit) {
        var lease: StreamingPlatformLease? = null
        var openAnswered = false
        var closeReason: StreamingPlatformCloseReason? = null
        var closeInFlight = false
        var sentCloseReason: StreamingPlatformCloseReason? = null
        var released = false
        var discardEvents = false
        var failure: StreamingStopCause? = null
        var lastSequence = -1L
        val closeReplies = mutableListOf<(Map<String, Any>) -> Unit>()
    }
    private val lock = Any()
    private val entries = mutableMapOf<StreamingPlatformOwner, Entry>()
    private val retired = mutableSetOf<StreamingPlatformOwner>()
    private val confirmedReleased = mutableSetOf<StreamingPlatformOwner>()
    private var disposed = false

    fun handle(method: String, arguments: Any?, reply: (Map<String, Any>) -> Unit) {
        when (method) {
            "open" -> {
                val request = StreamingChannelContract.decodeStart(arguments)
                if (request == null) answer(null, reply, false, true, "engine")
                else open(request, reply)
            }
            "close" -> {
                val request = StreamingChannelContract.decodeClose(arguments)
                if (request == null) answer(null, reply, false, true, "engine")
                else close(request, reply)
            }
            else -> answer(null, reply, false, true, "engine")
        }
    }

    private fun open(request: StreamingPlatformStart, reply: (Map<String, Any>) -> Unit) {
        val entry = synchronized(lock) {
            val owner = request.owner
            val rejection = when {
                disposed -> "closed"
                !enabled -> "modelUnavailable"
                entries.keys.any { it.meetingId == owner.meetingId } -> "alreadyOwned"
                owner in retired -> "closed"
                else -> null
            }
            if (rejection != null) {
                val releaseKnown = !entries.containsKey(owner) && (owner !in retired || owner in confirmedReleased)
                answer(owner, reply, false, releaseKnown, rejection)
                return
            }
            Entry(request, StreamingRemoteIdentity(owner.runId, bindingEpoch()), reply).also {
                entries[owner] = it
                retired.add(owner)
            }
        }
        try { creationExecutor.execute { createLease(entry) } }
        catch (_: Throwable) {
            synchronized(lock) { entry.failure = StreamingStopCause.ENGINE; released(entry) }
        }
    }

    private fun createLease(entry: Entry) {
        val lease = try {
            factory.create(entry.request, entry.identity, { receive(entry, it) }, { degrade(entry, it) })
        } catch (_: OutOfMemoryError) {
            synchronized(lock) { entry.failure = StreamingStopCause.MEMORY; released(entry) }
            return
        } catch (_: Throwable) {
            synchronized(lock) { entry.failure = StreamingStopCause.ENGINE; released(entry) }
            return
        }
        val closing = synchronized(lock) {
            entry.lease = lease
            entry.closeReason != null
        }
        if (closing) requestClose(entry) else startLease(entry, lease)
    }

    private fun startLease(entry: Entry, lease: StreamingPlatformLease): Unit = synchronized(lock) {
        // The nonblocking start invocation and close admission share arbitration.
        // A stale closing=false snapshot must never restart an acknowledged lease.
        if (entry.released) return
        if (entry.closeReason != null) {
            requestClose(entry)
            return
        }
        try {
            lease.start().whenComplete { cause, failure ->
                if (failure != null) degrade(entry, StreamingStopCause.ENGINE)
                else if (cause != null) degrade(entry, cause)
                else synchronized(lock) {
                    if (!entry.released && entry.closeReason == null) answerOpen(entry, true, false)
                }
            }
        } catch (_: OutOfMemoryError) { degrade(entry, StreamingStopCause.MEMORY) }
        catch (_: Throwable) { degrade(entry, StreamingStopCause.ENGINE) }
        Unit
    }

    private fun receive(entry: Entry, event: StreamingCaptureEvent) {
        synchronized(lock) {
            if (entry.released || entry.discardEvents || entry.failure != null || event.owner != entry.identity ||
                event.sequence <= entry.lastSequence) return
            val encoded = StreamingChannelContract.encodeCapture(entry.request.owner, entry.identity, event)
            if (encoded == null) {
                degrade(entry, StreamingStopCause.ENGINE)
                return
            }
            entry.lastSequence = event.sequence
            replyExecutor.execute {
                synchronized(lock) {
                    if (!entry.discardEvents) emit(encoded)
                }
            }
        }
    }

    private fun degrade(entry: Entry, cause: StreamingStopCause) {
        synchronized(lock) {
            if (entry.released) return
            if (entry.failure == null) entry.failure = cause
            entry.closeReason = StreamingPlatformCloseReason.CANCELLED
        }
        requestClose(entry)
    }

    private fun close(request: StreamingPlatformClose, reply: ((Map<String, Any>) -> Unit)?) {
        val entry = synchronized(lock) {
            val current = entries[request.owner]
            if (current == null) {
                retired.add(request.owner)
                val known = request.owner in confirmedReleased
                if (reply != null) answer(request.owner, reply, known, known, if (known) null else "closed")
                return
            }
            if (reply != null) current.closeReplies.add(reply)
            if (request.reason != StreamingPlatformCloseReason.STOPPED) current.discardEvents = true
            if (current.closeReason == null || request.reason != StreamingPlatformCloseReason.STOPPED) {
                current.closeReason = request.reason
            }
            current
        }
        requestClose(entry)
    }

    private fun requestClose(entry: Entry) {
        val (lease, reason, primary) = synchronized(lock) {
            if (entry.released) return
            val owned = entry.lease ?: return
            val closing = entry.closeReason ?: return
            val first = !entry.closeInFlight
            if (!first && !(entry.sentCloseReason == StreamingPlatformCloseReason.STOPPED && closing != StreamingPlatformCloseReason.STOPPED)) return
            entry.closeInFlight = true
            entry.sentCloseReason = closing
            Triple(owned, closing, first)
        }
        try {
            lease.close(reason).whenComplete { _, failure ->
                synchronized(lock) {
                    if (entry.released) return@whenComplete
                    if (failure == null) released(entry)
                    else {
                        if (!primary) return@whenComplete // Original close still owns the pending ACK.
                        entry.closeInFlight = false
                        answerOpen(entry, false, false, "engine")
                        val replies = entry.closeReplies.toList()
                        entry.closeReplies.clear()
                        replies.forEach { answer(entry.request.owner, it, false, false, "engine") }
                    }
                }
            }
        } catch (_: Throwable) {
            synchronized(lock) {
                if (!primary || entry.released) return
                entry.closeInFlight = false
                answerOpen(entry, false, false, "engine")
                val replies = entry.closeReplies.toList()
                entry.closeReplies.clear()
                replies.forEach { answer(entry.request.owner, it, false, false, "engine") }
            }
        }
    }

    /** Called with lock held only after actual release, or before any lease existed. */
    private fun released(entry: Entry) {
        if (entry.released) return
        entry.released = true
        confirmedReleased.add(entry.request.owner)
        entries.remove(entry.request.owner)
        val cause = entry.failure
        if (entry.openAnswered && cause != null && !entry.discardEvents) {
            val terminal = StreamingChannelContract.header(entry.request.owner) + mapOf(
                "type" to "failure", "sequence" to entry.lastSequence + 1,
                "reason" to failureReason(cause), "released" to true)
            replyExecutor.execute { synchronized(lock) { if (!entry.discardEvents) emit(terminal) } }
        }
        answerOpen(entry, false, true, cause?.let(::failureReason) ?: "closed")
        val replies = entry.closeReplies.toList()
        entry.closeReplies.clear()
        replies.forEach { answer(entry.request.owner, it, true, true) }
    }

    private fun answerOpen(entry: Entry, ok: Boolean, released: Boolean, reason: String? = null) {
        if (entry.openAnswered) return
        entry.openAnswered = true
        answer(entry.request.owner, entry.openReply, ok, released, reason)
    }

    private fun answer(owner: StreamingPlatformOwner?, reply: (Map<String, Any>) -> Unit,
        ok: Boolean, released: Boolean, reason: String? = null) {
        val fields = (owner?.let(StreamingChannelContract::header) ?: mapOf("v" to 1)) +
            mapOf("ok" to ok, "released" to released) + (if (ok) emptyMap() else mapOf("reason" to (reason ?: "engine")))
        replyExecutor.execute { reply(fields) }
    }

    private fun failureReason(cause: StreamingStopCause): String = when (cause) {
        StreamingStopCause.BACKLOG -> "backlog"
        StreamingStopCause.INVALID_PCM, StreamingStopCause.ENGINE -> "engine"
        StreamingStopCause.MEMORY -> "memory"
        StreamingStopCause.THERMAL -> "thermal"
        StreamingStopCause.MODEL_UNAVAILABLE -> "modelUnavailable"
    }

    /** Nonblocking cancellation; executor/transport owners outlive real release. */
    fun closeOwner() {
        val owners = synchronized(lock) { disposed = true; entries.keys.toList() }
        owners.forEach { close(StreamingPlatformClose(it, StreamingPlatformCloseReason.CANCELLED), null) }
    }
}
