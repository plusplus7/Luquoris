package com.loquiris.transcription

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Message
import android.os.Messenger
import android.os.Process
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.CompletionStage
import java.util.concurrent.Executor
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/** A fresh instance per run/binding; no reconnect can revive the old session. */
class StreamingMessengerBinding(
    context: Context,
    identity: StreamingRemoteIdentity,
    private val bundleDigest: String,
    private val serviceClassName: String = "com.loquiris.transcription.StreamingInferenceService",
    onFailure: (StreamingStopCause) -> Unit = {},
    private val onReply: (StreamingRemoteReply, Int) -> Unit = { _, _ -> },
) {
    private val appContext = context.applicationContext
    private val control = HandlerThread("streaming-client-ipc").apply { start() }
    private val handler = Handler(control.looper)
    private val outbound = ThreadPoolExecutor(1, 1, 0L, TimeUnit.MILLISECONDS, ArrayBlockingQueue(2))
    private val target = AtomicReference<Messenger?>()
    private val requested = AtomicBoolean()
    private val connected = AtomicBoolean()
    private val disposed = AtomicBoolean()
    private val bindingLock = Any()
    private var bound = false
    private val serviceDeath: IBinder.DeathRecipient = IBinder.DeathRecipient { session.remoteProcessDied() }
    private val inbox: Messenger = Messenger(Handler(control.looper) { message ->
        if (!disposed.get() && message.what == 1 && message.sendingUid == Process.myUid()) {
            try {
                val fields = StreamingRemoteBundle.fromRemoteBundle(message.data)
                val reply = fields?.let(StreamingRemoteWire::decodeRemoteReply)
                if (reply == null) session.remoteTransportFailed() else if (reply.owner == identity) {
                    session.receiveRemote(reply)
                    runCatching { onReply(reply, message.arg1) }
                }
            } catch (_: OutOfMemoryError) { session.remoteTransportFailed(StreamingStopCause.MEMORY) }
            catch (_: Throwable) { session.remoteTransportFailed() }
        }
        true
    })
    val session: StreamingRemoteSession = StreamingRemoteSession(identity, { command ->
        val destination = target.get() ?: error("streaming_link_unavailable")
        destination.send(Message.obtain().apply {
            what = 1
            replyTo = inbox
            data = StreamingRemoteBundle.toRemoteBundle(StreamingRemoteWire.encodeRemoteCommand(command))
        })
    }, outbound, onFailure)

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, service: IBinder) {
            if (disposed.get() || !connected.compareAndSet(false, true)) return
            try {
                target.set(Messenger(service))
                service.linkToDeath(serviceDeath, 0)
                session.startRemote(bundleDigest)
            } catch (_: Throwable) {
                if (!service.isBinderAlive) session.remoteProcessDied() else session.remoteTransportFailed()
            }
        }
        override fun onServiceDisconnected(name: ComponentName) {
            val binder = target.get()?.binder
            if (binder != null && !binder.isBinderAlive) session.remoteProcessDied()
            else session.remoteTransportFailed()
        }
        override fun onBindingDied(name: ComponentName) = onServiceDisconnected(name)
        override fun onNullBinding(name: ComponentName) {
            // No Open was sent, so local closure is safe; no runtime existed.
            session.remoteTransportFailed()
            session.closeRemote()
        }
    }

    init {
        require(bundleDigest.matches(Regex("[a-f0-9]{64}")))
        session.releaseAcknowledgement.whenComplete { _, _ ->
            // Unbinding is cleanup AFTER acknowledgement, never its evidence.
            if (!handler.post(::disposeReleasedBinding)) disposeReleasedBinding()
        }
    }

    fun bindRemote(): Boolean {
        if (!requested.compareAndSet(false, true) || disposed.get()) return false
        val accepted = try {
            synchronized(bindingLock) {
                if (disposed.get()) return false
                appContext.bindService(
                    Intent().setClassName(appContext.packageName, serviceClassName), Context.BIND_AUTO_CREATE,
                    Executor { task -> if (!handler.post(task)) throw RejectedExecutionException() }, connection,
                ).also { bound = it }
            }
        } catch (_: Throwable) { false }
        if (!accepted) session.closeRemote()
        return accepted
    }

    fun closeBinding(): CompletionStage<Unit> = session.closeRemote()

    private fun disposeReleasedBinding() {
        if (!disposed.compareAndSet(false, true)) return
        synchronized(bindingLock) {
            if (bound) { runCatching { appContext.unbindService(connection) }; bound = false }
        }
        target.getAndSet(null)?.binder?.let { runCatching { it.unlinkToDeath(serviceDeath, 0) } }
        outbound.shutdown()
        control.quitSafely()
    }
}
