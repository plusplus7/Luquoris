package com.loquiris.transcription

data class DraftHypothesis(
    val startMilliseconds: Long,
    val endMilliseconds: Long,
    val rawText: String,
    val displayText: String,
) {
    init {
        require(startMilliseconds >= 0)
        require(endMilliseconds >= startMilliseconds)
    }
}

data class ReconciledDraftSegment(
    val id: String,
    val startMilliseconds: Long,
    val endMilliseconds: Long,
    val rawText: String,
    val displayText: String,
    val stable: Boolean,
)

data class DraftReconciliation(
    val segments: List<ReconciledDraftSegment>,
    val incomplete: Boolean,
)

class DraftHypothesisReconciler(
    private val stableHorizonMilliseconds: Long,
    private val gapToleranceMilliseconds: Long = DEFAULT_GAP_TOLERANCE_MILLISECONDS,
) {
    private var stableSegments = emptyList<ReconciledDraftSegment>()
    private var incomplete = false

    init {
        require(stableHorizonMilliseconds >= 0)
        require(gapToleranceMilliseconds >= 0)
    }

    @Synchronized
    fun reconcile(
        windowEndMilliseconds: Long,
        hypotheses: List<DraftHypothesis>,
    ): DraftReconciliation {
        require(windowEndMilliseconds >= 0)
        val stableCutoff = (windowEndMilliseconds - stableHorizonMilliseconds).coerceAtLeast(0)
        val reconciled = stableSegments.toMutableList()
        var previousEnd = reconciled.lastOrNull()?.endMilliseconds ?: 0L
        var previousText = reconciled.lastOrNull()?.displayText.orEmpty()

        hypotheses
            .sortedWith(compareBy(DraftHypothesis::startMilliseconds, DraftHypothesis::endMilliseconds))
            .forEach { hypothesis ->
                if (hypothesis.endMilliseconds <= previousEnd) return@forEach
                val start = maxOf(previousEnd, hypothesis.startMilliseconds)
                val end = maxOf(start, hypothesis.endMilliseconds)
                if (start - previousEnd > gapToleranceMilliseconds && previousEnd > 0) incomplete = true
                val displayText = removeDuplicatePrefix(previousText, hypothesis.displayText.trim())
                if (displayText.isEmpty()) return@forEach
                val segment =
                    ReconciledDraftSegment(
                        id = "draft-$start-$end-${reconciled.size}",
                        startMilliseconds = start,
                        endMilliseconds = end,
                        rawText = hypothesis.rawText,
                        displayText = displayText,
                        stable = end <= stableCutoff,
                    )
                reconciled += segment
                previousEnd = end
                previousText = displayText
            }

        val bounded = reconciled.takeLast(MAX_RETAINED_SEGMENTS)
        stableSegments = bounded.filter(ReconciledDraftSegment::stable)
        return DraftReconciliation(
            segments = bounded,
            incomplete = incomplete,
        )
    }

    private fun removeDuplicatePrefix(
        previous: String,
        current: String,
    ): String {
        if (previous.isBlank() || current.isBlank()) return current
        val previousTokens = previous.split(WHITESPACE).filter(String::isNotEmpty)
        val currentTokens = current.split(WHITESPACE).filter(String::isNotEmpty)
        val maximum = minOf(previousTokens.size, currentTokens.size)
        val duplicateCount =
            (maximum downTo 1).firstOrNull { count ->
                previousTokens.takeLast(count) == currentTokens.take(count)
            } ?: 0
        return currentTokens.drop(duplicateCount).joinToString(" ")
    }

    private companion object {
        const val DEFAULT_GAP_TOLERANCE_MILLISECONDS = 400L
        const val MAX_RETAINED_SEGMENTS = 64
        val WHITESPACE = Regex("\\s+")
    }
}
