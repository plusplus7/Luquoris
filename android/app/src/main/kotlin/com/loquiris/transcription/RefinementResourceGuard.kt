package com.loquiris.transcription

/** Worker-side bounded polling plus immediate, allocation-free unsafe notifications. */
class RefinementResourceGuard(
    private val readSnapshot: () -> RefinementResourceSnapshot,
    private val observeUnsafe: ((String) -> Unit) -> AutoCloseable,
    private val monotonicMs: () -> Long,
) {
    @Volatile private var checkedAt: Long? = null
    private var cachedReason: String? = null

    fun pauseReason(): String? {
        val now = monotonicMs()
        val previous = checkedAt
        if (previous == null || now < previous || now - previous >= 1000) {
            cachedReason = try {
                RefinementResourcePolicy.pauseReason(readSnapshot())
            } catch (_: RuntimeException) {
                "refinement_resources_unavailable"
            }
            checkedAt = now
        }
        return cachedReason
    }

    fun observe(listener: (String) -> Unit): AutoCloseable {
        checkedAt = null
        return observeUnsafe { reason ->
            checkedAt = null
            listener(reason)
        }
    }
}
