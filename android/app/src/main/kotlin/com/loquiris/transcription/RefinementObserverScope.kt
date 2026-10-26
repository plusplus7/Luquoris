package com.loquiris.transcription

import java.util.concurrent.atomic.AtomicBoolean

/** Owns partial Android registrations even when optional native code cannot link. */
class RefinementObserverScope : AutoCloseable {
    private val closed = AtomicBoolean()
    private val unregisters = mutableListOf<() -> Unit>()
    val isClosed: Boolean get() = closed.get()

    fun register(start: () -> Unit, stop: () -> Unit) {
        check(!isClosed)
        // Own cleanup before registration, which may deliver a synchronous callback.
        unregisters += stop
        try {
            start()
        } catch (failure: Throwable) {
            try { close() } catch (_: Throwable) { /* Keep the original registration failure. */ }
            throw failure
        }
    }

    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        var failure: Throwable? = null
        for (index in unregisters.lastIndex downTo 0) {
            try { unregisters[index]() } catch (error: Throwable) { if (failure == null) failure = error }
        }
        unregisters.clear()
        failure?.let { throw it }
    }
}
