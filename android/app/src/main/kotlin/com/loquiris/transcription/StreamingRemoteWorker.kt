package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame
import java.util.concurrent.Executor

/** Creation failure must clean partial native handles before throwing. */
interface StreamingRemoteKernel : AutoCloseable {
    fun decode(frame: PcmCaptureFrame): StreamingRemoteResult.Text
    /** Flush and reset utterance state, without releasing the recognizer. */
    fun finishUtterance(): StreamingRemoteResult.Text
}

class StreamingRemoteModelUnavailable : RuntimeException("streaming_model_unavailable")

/** Remote-process owner; control never waits for model creation or inference. */
class StreamingRemoteWorker(
    private val inference: Executor,
    private val cleanup: Executor,
    private val create: (String) -> StreamingRemoteKernel,
    private val reply: (StreamingRemoteReply) -> Unit,
    private val wrapOwner: (StreamingRemoteKernel, Executor) -> StreamingInferenceOwner<StreamingRemoteKernel> = { kernel, executor -> StreamingInferenceOwner(kernel, executor) },
) {
    private val lock = Any()
    private var identity: StreamingRemoteIdentity? = null
    private var owner: StreamingInferenceOwner<StreamingRemoteKernel>? = null
    private var creating = false
    private var busy = false
    private var closing = false
    private var releaseRequested = false
    private var releaseUncertain = false
    private var released = false
    private var lastRequestId = -1L

    fun handleRemoteCommand(command: StreamingRemoteCommand) {
        when (command) {
            is StreamingRemoteCommand.Open -> beginRemoteOpen(command)
            is StreamingRemoteCommand.Pcm -> beginRemotePcm(command)
            is StreamingRemoteCommand.Finish -> beginRemoteFinish(command)
            is StreamingRemoteCommand.Close -> {
                if (synchronized(lock) { identity == command.owner }) closeRemoteWorker()
            }
        }
    }

    private fun beginRemoteOpen(command: StreamingRemoteCommand.Open) {
        synchronized(lock) {
            if (identity != null || closing) return
            identity = command.owner
            creating = true
        }
        try {
            inference.execute {
                try {
                    if (!command.bundleDigest.matches(Regex("[a-f0-9]{64}"))) throw StreamingRemoteModelUnavailable()
                    val kernel = create(command.bundleDigest)
                    val createdOwner = try { wrapOwner(kernel, cleanup) } catch (failure: Throwable) {
                        try { kernel.close() } catch (_: Throwable) {
                            // Creation succeeded; losing its wrapper does not
                            // mean a failed native close released its handles.
                            synchronized(lock) { releaseUncertain = true }
                        }
                        throw failure
                    }
                    finishRemoteOpen(createdOwner, null)
                } catch (_: OutOfMemoryError) { finishRemoteOpen(null, StreamingStopCause.MEMORY) }
                catch (_: StreamingRemoteModelUnavailable) { finishRemoteOpen(null, StreamingStopCause.MODEL_UNAVAILABLE) }
                catch (_: Throwable) { finishRemoteOpen(null, StreamingStopCause.ENGINE) }
            }
        } catch (_: OutOfMemoryError) { finishRemoteOpen(null, StreamingStopCause.MEMORY) }
        catch (_: Throwable) { finishRemoteOpen(null, StreamingStopCause.ENGINE) }
    }

    private fun finishRemoteOpen(created: StreamingInferenceOwner<StreamingRemoteKernel>?, failure: StreamingStopCause?) {
        val active: StreamingRemoteIdentity
        val shouldClose: Boolean
        synchronized(lock) {
            active = identity ?: return
            creating = false
            owner = created
            if (failure != null) closing = true
            shouldClose = closing
        }
        if (failure != null) emitRemote(StreamingRemoteReply.Failure(active, failure))
        if (shouldClose) closeRemoteWorker() else emitRemote(StreamingRemoteReply.Ready(active))
    }

    private fun beginRemotePcm(command: StreamingRemoteCommand.Pcm) {
        val start = command.frame.canonicalStartSample
        val end = command.frame.canonicalEndSampleExclusive
        val invalid = start == null || end == null || end - start !in 1..16000L
        beginRemoteInference(command.owner, command.requestId, invalid) { it.decode(command.frame) }
    }

    private fun beginRemoteFinish(command: StreamingRemoteCommand.Finish) {
        beginRemoteInference(command.owner, command.requestId, false) {
            it.finishUtterance().also { result -> check(result.endpoint) { "streaming_finish_not_final" } }
        }
    }

    private fun beginRemoteInference(
        identity: StreamingRemoteIdentity,
        requestId: Long,
        invalidInput: Boolean,
        operation: (StreamingRemoteKernel) -> StreamingRemoteResult.Text,
    ) {
        val activeOwner: StreamingInferenceOwner<StreamingRemoteKernel>?
        val invalid: Boolean
        synchronized(lock) {
            if (identity != this.identity || closing || creating || released) return
            invalid = busy || requestId <= lastRequestId || invalidInput
            activeOwner = owner
            if (!invalid && activeOwner != null) {
                busy = true
                lastRequestId = requestId
            }
        }
        if (invalid || activeOwner == null) {
            emitRemote(StreamingRemoteReply.Failure(identity, StreamingStopCause.INVALID_PCM))
            closeRemoteWorker()
            return
        }
        try {
            inference.execute {
                try {
                    val result = activeOwner.runInference(operation)
                    val publish = synchronized(lock) {
                        busy = false
                        !closing
                    }
                    if (result != null && publish) {
                        emitRemote(StreamingRemoteReply.Text(identity, requestId, result.text, result.endpoint))
                    }
                } catch (_: OutOfMemoryError) {
                    emitRemote(StreamingRemoteReply.Failure(identity, StreamingStopCause.MEMORY))
                    closeRemoteWorker()
                } catch (_: Throwable) {
                    emitRemote(StreamingRemoteReply.Failure(identity, StreamingStopCause.ENGINE))
                    closeRemoteWorker()
                } finally {
                    synchronized(lock) {
                        // Reply delivery may admit the next request. Do not
                        // erase that new request's reservation on this exit.
                        if (lastRequestId == requestId) busy = false
                    }
                }
            }
        } catch (_: Throwable) {
            synchronized(lock) { busy = false }
            emitRemote(StreamingRemoteReply.Failure(identity, StreamingStopCause.ENGINE))
            closeRemoteWorker()
        }
    }

    fun closeRemoteWorker() {
        val active: StreamingRemoteIdentity
        val activeOwner: StreamingInferenceOwner<StreamingRemoteKernel>?
        synchronized(lock) {
            closing = true
            active = identity ?: return
            if (creating || releaseRequested || releaseUncertain) return
            releaseRequested = true
            activeOwner = owner
        }
        if (activeOwner == null) {
            synchronized(lock) { released = true }
            emitRemote(StreamingRemoteReply.Released(active))
        } else watchRemoteRelease(active, activeOwner)
    }

    private fun watchRemoteRelease(active: StreamingRemoteIdentity, activeOwner: StreamingInferenceOwner<StreamingRemoteKernel>) {
        activeOwner.closeAsync().whenComplete { _, failure ->
            if (failure == null) {
                synchronized(lock) { released = true }
                emitRemote(StreamingRemoteReply.Released(active))
            } else emitRemote(StreamingRemoteReply.Failure(active, StreamingStopCause.ENGINE))
        }
    }

    private fun emitRemote(value: StreamingRemoteReply) {
        try { reply(value) } catch (_: Throwable) {
            // Lost client cannot strand native handles. Do not recurse after a
            // failed release/failure notification while closure is underway.
            if (!synchronized(lock) { closing }) closeRemoteWorker()
        }
    }
}
