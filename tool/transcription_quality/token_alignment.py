"""Deterministic token errors, without implicit lexical normalization.

Callers must freeze separate raw/normalized tokens per utterance: characters for
CER, words for WER, annotated Chinese characters/English words for mixed MER.
This core cannot establish corpus rights, coverage, or release qualification.
"""

from dataclasses import dataclass
from fractions import Fraction
from typing import Sequence


@dataclass(frozen=True)
class TokenErrors:
    """Exact additive counts; preserve precision through threshold checks."""

    reference_tokens: int
    hypothesis_tokens: int
    correct: int
    substitutions: int
    deletions: int
    insertions: int

    def __post_init__(self) -> None:
        """Reject invalid or non-conserving externally supplied counts."""
        values = (self.reference_tokens, self.hypothesis_tokens, self.correct,
                  self.substitutions, self.deletions, self.insertions)
        if any(type(value) is not int or value < 0 for value in values):
            raise ValueError("counts must be nonnegative integers")
        if (self.correct + self.substitutions + self.deletions != self.reference_tokens
                or self.correct + self.substitutions + self.insertions != self.hypothesis_tokens):
            raise ValueError("counts must conserve reference and hypothesis lengths")

    @property
    def errors(self) -> int:
        """Unit-cost edit count, which may exceed reference length."""
        return self.substitutions + self.deletions + self.insertions

    @property
    def rate(self) -> Fraction | None:
        """Error/reference ratio, undefined when the reference is empty."""
        return Fraction(self.errors, self.reference_tokens) if self.reference_tokens else None

    def __add__(self, other: "TokenErrors") -> "TokenErrors":
        """Pool utterance counts before computing any percentage."""
        return TokenErrors(
            self.reference_tokens + other.reference_tokens,
            self.hypothesis_tokens + other.hypothesis_tokens,
            self.correct + other.correct,
            self.substitutions + other.substitutions,
            self.deletions + other.deletions,
            self.insertions + other.insertions,
        )


def score_tokens(reference: Sequence[str], hypothesis: Sequence[str]) -> TokenErrors:
    """Levenshtein counts in O(R*H) time/O(H) memory, without changing tokens.

    Ties prefer the diagonal (match/substitution), then deletion, then insertion.
    Empty lexical tokens and implicit string-as-character input are rejected.
    """
    for tokens in (reference, hypothesis):
        if isinstance(tokens, (str, bytes)) or any(
            not isinstance(token, str) or not token for token in tokens
        ):
            raise ValueError("expected explicit nonempty string tokens")
    # Cell: (distance, correct, substitutions, deletions, insertions).
    previous = [(j, 0, 0, 0, j) for j in range(len(hypothesis) + 1)]
    for i, expected in enumerate(reference, start=1):
        current = [(i, 0, 0, i, 0)]
        for j, actual in enumerate(hypothesis, start=1):
            diagonal, above, left = previous[j - 1], previous[j], current[j - 1]
            matches = expected == actual
            candidates = [
                (diagonal[0] + int(not matches), diagonal[1] + int(matches),
                 diagonal[2] + int(not matches), diagonal[3], diagonal[4]),
                (above[0] + 1, above[1], above[2], above[3] + 1, above[4]),
                (left[0] + 1, left[1], left[2], left[3], left[4] + 1),
            ]
            current.append(min(candidates, key=lambda candidate: candidate[0]))
        previous = current
    distance, correct, substitutions, deletions, insertions = previous[-1]
    result = TokenErrors(len(reference), len(hypothesis), correct,
                         substitutions, deletions, insertions)
    assert result.errors == distance
    assert correct + substitutions + deletions == len(reference)
    assert correct + substitutions + insertions == len(hypothesis)
    return result


@dataclass(frozen=True)
class ThreeStratumScores:
    """Independently pooled Chinese CER, English WER, and mixed MER counts."""

    chinese: TokenErrors
    english: TokenErrors
    mixed: TokenErrors

    @property
    def rates(self) -> tuple[Fraction, Fraction, Fraction]:
        """Missing strata cannot dilute an average."""
        chinese, english, mixed = self.chinese.rate, self.english.rate, self.mixed.rate
        if chinese is None or english is None or mixed is None:
            raise ValueError("all three strata require nonempty references")
        return chinese, english, mixed

    @property
    def equally_weighted_rate(self) -> Fraction:
        """Mean of three language rates, not a cross-language micro-average."""
        return sum(self.rates, Fraction(0)) / 3


@dataclass(frozen=True)
class AccuracyGate:
    """Normalized numeric conditions only, never an overall release approval."""

    live_ceilings_pass: bool
    refined_ceilings_pass: bool
    relative_improvement_pass: bool
    per_language_regression_pass: bool

    @property
    def passed(self) -> bool:
        """Whether every numeric condition passed for the supplied scores."""
        return all((self.live_ceilings_pass, self.refined_ceilings_pass,
                    self.relative_improvement_pass, self.per_language_regression_pass))


def compare_accuracy(live: ThreeStratumScores, refined: ThreeStratumScores) -> AccuracyGate:
    """Apply spec thresholds exactly; zero-baseline reduction is undefined.

    A perfect live baseline cannot demonstrate 15% relative improvement. Corpus
    comparability, frozen annotation and raw reporting remain caller duties.
    """
    for before, after in zip((live.chinese, live.english, live.mixed),
                             (refined.chinese, refined.english, refined.mixed)):
        if before.reference_tokens != after.reference_tokens:
            raise ValueError("paired scores require equal reference token totals")
    live_rates, refined_rates = live.rates, refined.rates
    baseline = live.equally_weighted_rate
    return AccuracyGate(
        live_ceilings_pass=all(rate <= ceiling for rate, ceiling in zip(
            live_rates, (Fraction(1, 5), Fraction(1, 4), Fraction(1, 4)))),
        refined_ceilings_pass=all(rate <= ceiling for rate, ceiling in zip(
            refined_rates, (Fraction(3, 20), Fraction(1, 5), Fraction(1, 5)))),
        relative_improvement_pass=(baseline > 0 and
            (baseline - refined.equally_weighted_rate) / baseline >= Fraction(3, 20)),
        per_language_regression_pass=all(after - before <= Fraction(1, 50)
            for before, after in zip(live_rates, refined_rates)),
    )
