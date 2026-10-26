package com.loquiris.transcription

import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Message
import android.os.Messenger
import android.os.Process
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.Executors
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/** Debug-only Android glue; native ownership remains in the plain tested worker. */
class StreamingMessengerHost(
    private val registerPeerDeath: (IBinder, IBinder.DeathRecipient) -> Unit = { binder, recipient -> binder.linkToDeath(recipient, 0) },
    create: (String) -> StreamingRemoteKernel,
) {
    private companion object {
        val processLease = StreamingProcessLease()
    }
    private val lifecycleLock = Any()
    private val heldLease = AtomicReference<AutoCloseable?>()
    private val control = HandlerThread("streaming-ipc").apply { start() }
    private val inference = ThreadPoolExecutor(1, 1, 0L, TimeUnit.MILLISECONDS, ArrayBlockingQueue(1))
    private val cleanup = Executors.newSingleThreadExecutor()
    private val disposed = AtomicBoolean()
    private val releaseObserved = AtomicBoolean()
    private var peer: Messenger? = null
    private var peerOwner: StreamingRemoteIdentity? = null
    private val peerDeath = IBinder.DeathRecipient {
        // This host is constructed only in the asserted private service process.
        // Confirmed client death must not leave an uninterruptible orphan engine.
        if (!releaseObserved.get()) Process.killProcess(Process.myPid())
    }
    private val worker = StreamingRemoteWorker(inference, cleanup, create, ::sendRemoteMessage)
    private val inbox = Messenger(Handler(control.looper) { message -> handleRemoteMessage(message); true })
    val binder: IBinder get() = inbox.binder

    private fun handleRemoteMessage(message: Message) {
        synchronized(lifecycleLock) { dispatchRemoteMessage(message) }
    }

    private fun dispatchRemoteMessage(message: Message) {
        if (disposed.get() || message.what != 1 || message.sendingUid != Process.myUid()) return
        val sender = message.replyTo ?: return
        try {
            val fields = StreamingRemoteBundle.fromRemoteBundle(message.data)
            val command = fields?.let(StreamingRemoteWire::decodeRemoteCommand)
            if (command == null) {
                if (sender.binder == peer?.binder) {
                    peerOwner?.let { sendRemoteMessage(StreamingRemoteReply.Failure(it, StreamingStopCause.INVALID_PCM)) }
                    worker.closeRemoteWorker()
                }
                return
            }
            if (peer == null) {
                if (command !is StreamingRemoteCommand.Open) return
                val admission = processLease.acquireProcessLease()
                if (admission == null) {
                    runCatching { sendRemoteTo(sender, StreamingRemoteReply.Rejected(command.owner, StreamingStopCause.ENGINE)) }
                    return
                }
                heldLease.set(admission)
                try { registerPeerDeath(sender.binder, peerDeath) } catch (failure: Throwable) {
                    releaseProcessLease() // No worker/model was adopted.
                    if (sender.binder.isBinderAlive) {
                        val cause = if (failure is OutOfMemoryError) StreamingStopCause.MEMORY else StreamingStopCause.ENGINE
                        try { sendRemoteTo(sender, StreamingRemoteReply.Rejected(command.owner, cause)) }
                        catch (_: Throwable) { Process.killProcess(Process.myPid()) }
                    }
                    return
                }
                peer = sender
                peerOwner = command.owner
            }
            if (sender.binder != peer?.binder || command.owner != peerOwner) {
                if (command is StreamingRemoteCommand.Open) runCatching {
                    sendRemoteTo(sender, StreamingRemoteReply.Rejected(command.owner, StreamingStopCause.ENGINE))
                }
                return
            }
            worker.handleRemoteCommand(command)
        } catch (_: OutOfMemoryError) {
            peerOwner?.let { runCatching { sendRemoteMessage(StreamingRemoteReply.Failure(it, StreamingStopCause.MEMORY)) } }
            worker.closeRemoteWorker()
        } catch (_: Throwable) { worker.closeRemoteWorker() }
    }

    private fun sendRemoteMessage(value: StreamingRemoteReply) {
        if (value is StreamingRemoteReply.Released) {
            releaseObserved.set(true)
            releaseProcessLease()
        }
        if (disposed.get()) {
            if (releaseObserved.get()) cleanup.shutdown()
            return
        }
        val target = peer ?: error("streaming_peer_unavailable")
        try { sendRemoteTo(target, value) } catch (failure: Throwable) {
            // A lost/malformed acknowledgement must not strand a live client's
            // ownership indefinitely. Confirmed death will settle it instead.
            if (!disposed.get()) Process.killProcess(Process.myPid())
            throw failure
        }
    }

    private fun sendRemoteTo(target: Messenger, value: StreamingRemoteReply) {
        target.send(Message.obtain().apply {
            what = 1
            arg1 = Process.myPid() // Diagnostic only; never used to select a PID to kill.
            data = StreamingRemoteBundle.toRemoteBundle(StreamingRemoteWire.encodeRemoteReply(value))
        })
    }

    /** Retire this host, not the process that may already host the next service. */
    fun disposeRemoteHost() {
        synchronized(lifecycleLock) {
            disposed.set(true)
            worker.closeRemoteWorker()
            runCatching { peer?.binder?.unlinkToDeath(peerDeath, 0) }
            control.quitSafely()
            inference.shutdown()
            // Never release the process lease because a Service was destroyed.
            // A busy/uncertain owner blocks model creation in replacement hosts.
            if (releaseObserved.get()) cleanup.shutdown()
        }
    }

    private fun releaseProcessLease() { heldLease.getAndSet(null)?.close() }
}
