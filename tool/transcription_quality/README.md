# Offline scoring tools (development reports, not qualification)

Run `python3 -m unittest discover -s tool/transcription_quality -p 'test_*.py' -v`.
Requires Python 3.10+ and only the standard library; no audio, model, microphone,
network, or application dependency is loaded.

`score_tokens(reference, hypothesis)` accepts explicit nonempty string tokens.
It returns immutable correct/substitution/deletion/insertion counts and an exact
`Fraction` rate. Empty references have an undefined rate, not zero; insertions
can make a rate exceed 100%. Pool utterance counts within a stratum before
calculating rates. Tie order is diagonal (match/substitution), deletion, insertion.
No text conversion, translation, punctuation removal, case folding, number
rewriting, or simplified/traditional conversion occurs in this core.

Raw and normalized inputs must be scored separately. CER requires frozen
character units; WER requires frozen word units; mixed MER requires explicitly
annotated Chinese-character/English-word units. The caller must not pass whole
strings or infer mixed coverage from model outputs. The core intentionally does
not guess acceptance normalization/tokenization before the human corpus and
annotations exist. Changing its tie policy requires a new documented version.

`compare_accuracy` uses the specification's live ceilings (20/25/25%), refined
ceilings (15/20/20%), equally weighted language mean, ≥15% relative improvement,
and ≤2 percentage-point regression per language. All comparisons use rational
arithmetic, before display rounding. A zero-error live baseline cannot demonstrate
relative reduction and does not pass that condition. Empty/mismatched reference
totals are rejected. Equal totals alone do not prove matching corpus identity:
the future evidence runner must validate utterance IDs, audio/reference hashes,
scoring-rule version, annotation identity and pairing before this call.

Hand-derived operation vectors and a structurally separate recursive edit-distance
oracle verify every pair of binary-alphabet sequences of length 0–4 (961 pairs).
Boundary tests cover exact improvement/regression/ceiling values and malformed
counts. CI never regenerates these expected values.

## Exact paired pre-tokenized report

```sh
python3 tool/transcription_quality/paired_report.py \
  --corpus corpus.json --rules frozen-scoring-rules.txt \
  --live live-output.json --refined refined-output.json > report.json
```

All input files are read-only. Successful execution writes deterministic JSON to
stdout, with no timestamp, random identity or model/audio/network access. Invalid
inputs exit 2 with no report on stdout. A successful exit means the report was
generated, not that its numeric gates passed. The report always says
`qualificationStatus: "not-assessed"`.

Schema version 1 accepts precisely these fields (unknown fields are rejected):

- Corpus: `schemaVersion: 1`, `scoringRulesSha256`, `utterances`.
- Corpus utterance: `id`, `stratum` (`chinese`, `english`, `mixed`), `condition`
  (a frozen acoustic-configuration identity), `audioSha256`, `rawReference` and
  `normalizedReference`.
- Each run: `schemaVersion: 1`, `corpusSha256`, `scoringRulesSha256`,
  `modelManifestSha256`, `utterances`.
- Run utterance: `id`, `audioSha256`, `rawHypothesis`, `normalizedHypothesis`.

Every token field is an explicit array of nonempty strings. Empty arrays are
allowed for silence/insertion diagnostics, but pooled references in every
condition/stratum/form must be nonempty. Hypotheses are never omitted just
because they are empty. Each condition must include all three language strata;
digital input and each distinct room/acoustic setup are never pooled together.
The synthetic, hand-derived inputs in `test_paired_report.py` demonstrate this
format; they are not speech, annotations, rights evidence or a qualifying corpus.

SHA-256 identities use lowercase hex over **exact file bytes**, including whitespace
and final newlines. `corpusSha256` covers the whole reference/token/annotation
snapshot; `scoringRulesSha256` must match the supplied frozen rules file in the
corpus and both runs. Any later corpus/rule edit requires deliberately regenerating
matching evaluation inputs, not silently accepting an old run. Utterance IDs must
be unique, with exactly matching ID sets and matching per-utterance audio hashes.
JSON duplicate keys and nonfinite values are rejected.

The report preserves raw and normalized S/D/I/correct counts and exact rates per
utterance and per condition/stratum, with counts pooled before rates and equal
language weighting. Rates are `[numerator, denominator]`, or `null` for an empty
utterance reference; comparisons use the unchanged rational arithmetic, not
display rounding. Normalized numeric gates are reported independently by
condition. Input/run hashes and declared model-manifest hashes remain visible.

These checks bind supplied claims; they do **not** read physical audio/model
files, verify model execution, audit rights or human reference accuracy, implement
the declared normalization, establish actual bilingual coverage, or prove a
minimum duration. The model digest is explicitly labelled *declared* in output.
The caller must freeze legitimate raw/normalized tokenization and rule semantics;
the tool will not guess them or normalize lexical errors away.

Remaining task 1.7 work includes versioned raw/normalized tokenization,
name/code-switch annotation attribution, physical corpus/provenance verification,
and frozen qualifying corpus/rule inputs. No acceptance checkbox is completed by
these host tools; their numeric output cannot grant quality, latency, acoustic,
license, battery, long-run, or release approval.
