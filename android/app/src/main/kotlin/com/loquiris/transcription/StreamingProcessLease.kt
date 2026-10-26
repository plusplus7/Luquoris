package com.loquiris.transcription

import java.util.concurrent.atomic.AtomicReference

/** Share one instance per OS process, not per Service or binding. */
class StreamingProcessLease {
    private val holder = AtomicReference<Ticket?>()

    private class Ticket(private val holder: AtomicReference<Ticket?>) : AutoCloseable {
        override fun close() { holder.compareAndSet(this, null) }
    }

    fun acquireProcessLease(): AutoCloseable? {
        // Allocate before claiming: failed allocation must not strand a lease
        // for which the caller never received a release capability.
        val ticket = Ticket(holder)
        return if (holder.compareAndSet(null, ticket)) ticket else null
    }
}
