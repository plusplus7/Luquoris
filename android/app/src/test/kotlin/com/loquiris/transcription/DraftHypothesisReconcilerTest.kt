package com.loquiris.transcription

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DraftHypothesisReconcilerTest {
    @Test
    fun `long recordings retain a bounded recent draft history`() {
        val reconciler = DraftHypothesisReconciler(stableHorizonMilliseconds = 0)
        var latest: DraftReconciliation? = null
        repeat(200) { index ->
            latest = reconciler.reconcile(
                (index + 1) * 1_000L,
                listOf(hypothesis(index * 1_000L, (index + 1) * 1_000L, "word-$index")),
            )
        }
        assertTrue(checkNotNull(latest).segments.size <= 64)
        assertEquals("word-199", checkNotNull(latest).segments.last().displayText)
    }

    @Test
    fun `overlapping windows preserve stable text and replace only the unstable tail`() {
        val reconciler = DraftHypothesisReconciler(stableHorizonMilliseconds = 1_000)

        val first =
            reconciler.reconcile(
                windowEndMilliseconds = 4_000,
                hypotheses =
                    listOf(
                        hypothesis(0, 2_000, "hello world"),
                        hypothesis(2_000, 3_600, "draft tail"),
                    ),
            )
        val second =
            reconciler.reconcile(
                windowEndMilliseconds = 5_000,
                hypotheses =
                    listOf(
                        hypothesis(1_800, 3_400, "world corrected"),
                        hypothesis(3_400, 4_800, "new tail"),
                    ),
            )

        assertEquals(listOf("hello world", "corrected", "new tail"), second.segments.map { it.displayText })
        assertTrue(first.segments.first().stable)
        assertTrue(second.segments.take(2).all { it.stable })
        assertFalse(second.segments.last().stable)
    }

    @Test
    fun `timestamps remain monotonic and duplicate overlap tokens are removed`() {
        val reconciler = DraftHypothesisReconciler(stableHorizonMilliseconds = 500)

        val result =
            reconciler.reconcile(
                windowEndMilliseconds = 4_000,
                hypotheses =
                    listOf(
                        hypothesis(0, 2_100, "one two three"),
                        hypothesis(1_900, 3_800, "two three four"),
                    ),
            )

        assertEquals(listOf("one two three", "four"), result.segments.map { it.displayText })
        assertEquals(2_100, result.segments[1].startMilliseconds)
        assertTrue(result.segments.zipWithNext().all { (left, right) -> left.endMilliseconds <= right.startMilliseconds })
    }

    @Test
    fun `stable horizon promotion is monotonic and incomplete gaps stay visible`() {
        val reconciler =
            DraftHypothesisReconciler(
                stableHorizonMilliseconds = 1_000,
                gapToleranceMilliseconds = 250,
            )

        val first =
            reconciler.reconcile(
                windowEndMilliseconds = 3_000,
                hypotheses = listOf(hypothesis(0, 2_600, "still changing")),
            )
        val second =
            reconciler.reconcile(
                windowEndMilliseconds = 5_000,
                hypotheses =
                    listOf(
                        hypothesis(0, 2_600, "still changing"),
                        hypothesis(3_200, 4_700, "after gap"),
                    ),
            )

        assertFalse(first.segments.single().stable)
        assertTrue(second.segments.first().stable)
        assertTrue(second.incomplete)
    }
}

private fun hypothesis(
    startMilliseconds: Long,
    endMilliseconds: Long,
    text: String,
) = DraftHypothesis(
    startMilliseconds = startMilliseconds,
    endMilliseconds = endMilliseconds,
    rawText = text,
    displayText = text,
)
