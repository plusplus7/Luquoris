"""Hand-derived vectors and an independent recursive minimum-distance oracle."""

import itertools
import unittest
from fractions import Fraction
from functools import lru_cache

from token_alignment import ThreeStratumScores, TokenErrors, compare_accuracy, score_tokens


class TokenAlignmentTest(unittest.TestCase):
    def test_counts_have_fixed_substitution_first_ties(self):
        self.assertEqual(score_tokens(['a', 'b'], ['b', 'a']), TokenErrors(2, 2, 0, 2, 0, 0))

    def test_hand_derived_vectors(self):
        for reference, hypothesis, expected in [
            ([], [], TokenErrors(0, 0, 0, 0, 0, 0)),
            ([], ['noise', 'noise'], TokenErrors(0, 2, 0, 0, 0, 2)),
            (['名', '字'], [], TokenErrors(2, 0, 0, 0, 2, 0)),
            (['刘', '国', '梁'], ['刘', '国', '良'], TokenErrors(3, 3, 2, 1, 0, 0)),
            (['use', 'ONNX', '模', '型'], ['use', '模型'], TokenErrors(4, 2, 1, 1, 2, 0)),
            (["don't"], ['do', 'not'], TokenErrors(1, 2, 0, 1, 0, 1)),
            (['🎙️'], ['🎙️'], TokenErrors(1, 1, 1, 0, 0, 0)),
        ]:
            with self.subTest(reference=reference, hypothesis=hypothesis):
                self.assertEqual(score_tokens(reference, hypothesis), expected)

    def test_never_normalizes_away_lexical_errors(self):
        self.assertEqual(score_tokens(['臺', '灣'], ['台', '湾']).errors, 2)
        self.assertEqual(score_tokens(['one'], ['1']).errors, 1)
        self.assertEqual(score_tokens(['中文'], ['Chinese']).errors, 1)
        self.assertEqual(score_tokens(['ONNX'], ['onnx']).errors, 1)

    def test_rejects_implicit_or_invalid_tokenization(self):
        for value in ['abc', b'abc', [''], [None], [1]]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                score_tokens(value, [])

    def test_empty_reference_is_undefined_and_insertion_rate_is_not_capped(self):
        self.assertIsNone(score_tokens([], ['noise']).rate)
        self.assertEqual(score_tokens(['x'], ['x', 'y', 'z']).rate, Fraction(2))

    def test_exhaustive_small_sequences_against_independent_oracle(self):
        @lru_cache(None)
        def oracle(a, b):
            if not a or not b:
                return len(a) + len(b)
            return min(oracle(a[1:], b) + 1, oracle(a, b[1:]) + 1,
                       oracle(a[1:], b[1:]) + (a[0] != b[0]))

        sequences = [s for length in range(5) for s in itertools.product(('a', '中'), repeat=length)]
        for a, b in itertools.product(sequences, repeat=2):
            result = score_tokens(a, b)
            self.assertEqual(result.errors, oracle(a, b), (a, b))
            self.assertEqual(result.correct + result.substitutions + result.deletions, len(a))
            self.assertEqual(result.correct + result.substitutions + result.insertions, len(b))
            self.assertEqual(result, score_tokens(a, b))

    def test_pool_counts_before_rates(self):
        pooled = score_tokens(['a'], ['b']) + score_tokens(['a'] * 9, ['a'] * 9)
        self.assertEqual(pooled.rate, Fraction(1, 10))

    def test_invalid_counts_cannot_manufacture_a_passing_rate(self):
        for values in [(1, 1, 2, -1, 0, 0), (1, 1, 0, 0, 0, 0),
                       (True, 1, 1, 0, 0, 0), (1.0, 1, 1, 0, 0, 0)]:
            with self.subTest(values=values), self.assertRaises(ValueError):
                TokenErrors(*values)


def counts(errors, total=100):
    return TokenErrors(total, total, total - errors, errors, 0, 0)


class AccuracyComparisonTest(unittest.TestCase):
    def test_exact_ceiling_and_relative_improvement_boundaries(self):
        live = ThreeStratumScores(counts(20), counts(25), counts(25))
        refined = ThreeStratumScores(counts(15), counts(20), counts(20))
        self.assertTrue(compare_accuracy(live, refined).passed)
        equal = ThreeStratumScores(counts(100, 1000), counts(100, 1000), counts(100, 1000))
        exact = ThreeStratumScores(counts(85, 1000), counts(85, 1000), counts(85, 1000))
        self.assertTrue(compare_accuracy(equal, exact).relative_improvement_pass)
        below = ThreeStratumScores(counts(86, 1000), counts(85, 1000), counts(85, 1000))
        self.assertFalse(compare_accuracy(equal, below).relative_improvement_pass)

    def test_strata_are_equally_weighted_not_duration_or_token_weighted(self):
        scores = ThreeStratumScores(counts(1, 10), counts(40, 100), counts(3, 10))
        self.assertEqual(scores.equally_weighted_rate, Fraction(4, 15))

    def test_per_language_regression_cannot_hide_in_mean(self):
        live = ThreeStratumScores(counts(10), counts(20), counts(20))
        boundary = ThreeStratumScores(counts(12), counts(10), counts(10))
        over = ThreeStratumScores(counts(13), counts(10), counts(10))
        self.assertTrue(compare_accuracy(live, boundary).per_language_regression_pass)
        result = compare_accuracy(live, over)
        self.assertTrue(result.relative_improvement_pass)
        self.assertFalse(result.per_language_regression_pass)
        self.assertFalse(result.passed)

    def test_zero_baseline_and_missing_strata_are_not_qualified(self):
        perfect = ThreeStratumScores(counts(0), counts(0), counts(0))
        self.assertFalse(compare_accuracy(perfect, perfect).relative_improvement_pass)
        absent = ThreeStratumScores(score_tokens([], []), counts(0), counts(0))
        with self.assertRaises(ValueError):
            compare_accuracy(absent, perfect)

    def test_different_reference_totals_are_not_a_comparable_pair(self):
        before = ThreeStratumScores(counts(10), counts(10), counts(10))
        after = ThreeStratumScores(counts(1, 10), counts(1, 10), counts(1, 10))
        with self.assertRaises(ValueError):
            compare_accuracy(before, after)

    def test_each_ceiling_is_independently_enforced(self):
        live = ThreeStratumScores(counts(20), counts(25), counts(25))
        refined = ThreeStratumScores(counts(15), counts(20), counts(20))
        for index in range(3):
            values = [counts(20), counts(25), counts(25)]
            values[index] = counts((20, 25, 25)[index] + 1)
            self.assertFalse(compare_accuracy(ThreeStratumScores(*values), refined).live_ceilings_pass)
            values = [counts(15), counts(20), counts(20)]
            values[index] = counts((15, 20, 20)[index] + 1)
            self.assertFalse(compare_accuracy(live, ThreeStratumScores(*values)).refined_ceilings_pass)


if __name__ == '__main__':
    unittest.main()
