package com.loquiris.transcription

import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/** Serializes native inference; a live reservation pauses post-session windows. */
class WhisperInferenceArbiter {
    private val lock = ReentrantLock(true)
    private val changed = lock.newCondition()
    private var liveReserved = false
    private var postActive = false

    fun acquireLive(cancelled: () -> Boolean): AutoCloseable? = lock.withLock {
        if (liveReserved || cancelled()) return null
        liveReserved = true
        try {
            while (postActive && !cancelled()) changed.awaitNanos(50_000_000)
            if (cancelled()) {
                liveReserved = false
                changed.signalAll()
                return null
            }
        } catch (failure: InterruptedException) {
            liveReserved = false
            changed.signalAll()
            Thread.currentThread().interrupt()
            return null
        }
        lease {
            liveReserved = false
        }
    }

    fun acquirePostSession(cancelled: () -> Boolean): AutoCloseable? = lock.withLock {
        try {
            while ((liveReserved || postActive) && !cancelled()) changed.awaitNanos(50_000_000)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            return null
        }
        if (cancelled()) return null
        postActive = true
        lease { postActive = false }
    }

    private fun lease(release: () -> Unit): AutoCloseable {
        val closed = AtomicBoolean()
        return AutoCloseable {
            if (closed.compareAndSet(false, true)) lock.withLock {
                release()
                changed.signalAll()
            }
        }
    }

    companion object {
        val process = WhisperInferenceArbiter()
    }
}
