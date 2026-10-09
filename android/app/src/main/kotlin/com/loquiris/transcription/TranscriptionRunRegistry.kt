package com.loquiris.transcription

enum class TranscriptionRunRegistration {
    registered,
    duplicate,
    closed,
}

class TranscriptionRunRegistry : AutoCloseable {
    private val cancellations = LinkedHashMap<String, TranscriptionCancellation>()
    private var closed = false

    @Synchronized
    fun register(
        runId: String,
        cancellation: TranscriptionCancellation,
    ): TranscriptionRunRegistration =
        when {
            closed -> TranscriptionRunRegistration.closed
            cancellations.containsKey(runId) -> TranscriptionRunRegistration.duplicate
            else -> {
                cancellations[runId] = cancellation
                TranscriptionRunRegistration.registered
            }
        }

    @Synchronized
    fun cancel(runId: String) {
        cancellations[runId]?.cancel()
    }

    @Synchronized
    fun finish(runId: String) {
        cancellations.remove(runId)
    }

    val activeCount: Int
        @Synchronized get() = cancellations.size

    @Synchronized
    override fun close() {
        if (closed) return
        closed = true
        cancellations.values.forEach(TranscriptionCancellation::cancel)
        cancellations.clear()
    }
}
