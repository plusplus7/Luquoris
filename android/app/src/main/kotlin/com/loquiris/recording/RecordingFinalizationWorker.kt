package com.loquiris.recording

import java.io.Closeable
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

class RecordingFinalizationWorker : Closeable {
    private val executor =
        Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "loquiris-recording-finalizer").apply { isDaemon = true }
        }

    fun submit(work: () -> Unit): Boolean =
        try {
            executor.execute(work)
            true
        } catch (_: RejectedExecutionException) {
            false
        }

    override fun close() {
        executor.shutdownNow()
    }
}
