package com.loquiris.recording

import java.io.Closeable
import java.util.concurrent.Executors

/** Keeps best-effort failure receipts from blocking queued service starts. */
class RecordingRejectedCommandDispatcher : Closeable {
    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "loquiris-rejected-command-receipts")
    }

    fun reject(stopRejectedStart: () -> Int, persistReceipt: () -> Unit): Int {
        val result = stopRejectedStart()
        // submit isolates writer failures; the existing receipt protocol remains
        // best effort (a failed persistence leaves the pending receipt intact).
        executor.submit(persistReceipt)
        return result
    }

    /** Drain accepted receipts rather than cancelling them with service teardown. */
    override fun close() {
        executor.shutdown()
    }
}
