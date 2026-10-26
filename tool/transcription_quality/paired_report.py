"""Offline pre-tokenized pairing report; not corpus or release qualification."""

import argparse
from dataclasses import asdict
import hashlib
import json
from pathlib import Path
import re
import sys

if __package__:
    from .token_alignment import ThreeStratumScores, TokenErrors, compare_accuracy, score_tokens
else:
    from token_alignment import ThreeStratumScores, TokenErrors, compare_accuracy, score_tokens


STRATA = ("chinese", "english", "mixed")
SHA256 = re.compile(r"[0-9a-f]{64}\Z")


def _unique_object(pairs):
    """Reject duplicate keys instead of silently accepting the last claim."""
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def _reject_constant(value):
    """JSON evidence cannot contain nonfinite numeric extensions."""
    raise ValueError("nonfinite JSON number")


def _load_json(data):
    """Read strict UTF-8 JSON, preserving exact input bytes for identity."""
    return json.loads(data.decode("utf-8"), object_pairs_hook=_unique_object,
                      parse_constant=_reject_constant)


def _require_keys(value, keys):
    """Fail closed on misspelled, missing or silently ignored schema fields."""
    if not isinstance(value, dict) or set(value) != set(keys):
        raise ValueError("unexpected schema fields")


def _tokens(value):
    """Keep caller-frozen lexical units unchanged; an empty hypothesis is valid."""
    if not isinstance(value, list) or any(not isinstance(t, str) or not t for t in value):
        raise ValueError("expected explicit nonempty string tokens")
    return value


def _index_utterances(rows, reference):
    """Validate identities before pooling; equal token totals are insufficient."""
    if not isinstance(rows, list) or not rows:
        raise ValueError("utterances must be a nonempty list")
    result = {}
    for row in rows:
        _require_keys(row, ("id", "stratum", "condition", "audioSha256",
                            "rawReference", "normalizedReference") if reference else
                           ("id", "audioSha256", "rawHypothesis", "normalizedHypothesis"))
        identity = row["id"]
        if not isinstance(identity, str) or not identity.strip() or identity in result:
            raise ValueError("invalid or duplicate utterance id")
        if not isinstance(row["audioSha256"], str) or not SHA256.fullmatch(row["audioSha256"]):
            raise ValueError("invalid audio digest")
        suffix = "Reference" if reference else "Hypothesis"
        _tokens(row["raw" + suffix])
        _tokens(row["normalized" + suffix])
        if reference and (row["stratum"] not in STRATA or
                          not isinstance(row["condition"], str) or not row["condition"].strip()):
            raise ValueError("invalid stratum or acoustic condition")
        result[identity] = row
    return result


def _counts_json(counts):
    """Publish exact rational rates rather than rounded gate inputs."""
    result = asdict(counts)
    result["errors"] = counts.errors
    rate = counts.rate
    result["rate"] = None if rate is None else [rate.numerator, rate.denominator]
    return result


def build_paired_report(corpus_bytes: bytes, rules_bytes: bytes,
                        live_bytes: bytes, refined_bytes: bytes) -> dict:
    """Pair exact corpus/rule bytes and IDs; report numeric gates by condition.

    Input digests bind claims, not physical audio, human references or model
    provenance. Nothing here certifies normalization, rights or language coverage.
    """
    corpus = _load_json(corpus_bytes)
    _require_keys(corpus, ("schemaVersion", "scoringRulesSha256", "utterances"))
    corpus_hash = hashlib.sha256(corpus_bytes).hexdigest()
    rules_hash = hashlib.sha256(rules_bytes).hexdigest()
    if not rules_bytes or type(corpus["schemaVersion"]) is not int or corpus["schemaVersion"] != 1:
        raise ValueError("unsupported corpus schema or empty rules")
    if corpus["scoringRulesSha256"] != rules_hash:
        raise ValueError("frozen rules hash mismatch")
    references = _index_utterances(corpus["utterances"], True)
    conditions = sorted({r["condition"] for r in references.values()})
    for condition in conditions:
        if {r["stratum"] for r in references.values() if r["condition"] == condition} != set(STRATA):
            raise ValueError("each acoustic condition requires all three strata")
    report = {
        "schemaVersion": 1, "qualificationStatus": "not-assessed",
        "corpusSha256": corpus_hash, "scoringRulesSha256": rules_hash,
        "alignmentVersion": "unit-cost-diagonal-deletion-insertion-v1",
        "runs": {}, "conditions": {}, "utterances": [],
    }
    utterances = {identity: {"id": identity, "stratum": r["stratum"],
                             "condition": r["condition"], "audioSha256": r["audioSha256"]}
                  for identity, r in references.items()}
    pooled = {}
    for role, run_bytes in (("live", live_bytes), ("refined", refined_bytes)):
        run = _load_json(run_bytes)
        _require_keys(run, ("schemaVersion", "corpusSha256", "scoringRulesSha256",
                            "modelManifestSha256", "utterances"))
        if (type(run["schemaVersion"]) is not int or run["schemaVersion"] != 1 or
                run["corpusSha256"] != corpus_hash or run["scoringRulesSha256"] != rules_hash):
            raise ValueError("run corpus/rules identity mismatch")
        if not isinstance(run["modelManifestSha256"], str) or not SHA256.fullmatch(run["modelManifestSha256"]):
            raise ValueError("invalid declared model manifest digest")
        hypotheses = _index_utterances(run["utterances"], False)
        if set(hypotheses) != set(references):
            raise ValueError("missing or extra utterance ids")
        report["runs"][role] = {"inputSha256": hashlib.sha256(run_bytes).hexdigest(),
                                "declaredModelManifestSha256": run["modelManifestSha256"]}
        for identity, reference in references.items():
            hypothesis = hypotheses[identity]
            if hypothesis["audioSha256"] != reference["audioSha256"]:
                raise ValueError("utterance audio identity mismatch")
            utterances[identity][role] = {}
            for form in ("raw", "normalized"):
                counts = score_tokens(reference[form + "Reference"], hypothesis[form + "Hypothesis"])
                utterances[identity][role][form] = _counts_json(counts)
                key = (reference["condition"], role, form, reference["stratum"])
                pooled[key] = pooled.get(key, TokenErrors(0, 0, 0, 0, 0, 0)) + counts
    report["utterances"] = [utterances[identity] for identity in sorted(utterances)]
    for condition in conditions:
        group = {}
        normalized = {}
        for role in ("live", "refined"):
            group[role] = {}
            for form in ("raw", "normalized"):
                scores = ThreeStratumScores(*(pooled[(condition, role, form, stratum)] for stratum in STRATA))
                mean = scores.equally_weighted_rate
                group[role][form] = {stratum: _counts_json(pooled[(condition, role, form, stratum)])
                                     for stratum in STRATA}
                group[role][form]["equallyWeightedRate"] = [mean.numerator, mean.denominator]
                if form == "normalized":
                    normalized[role] = scores
        gate = compare_accuracy(normalized["live"], normalized["refined"])
        group["normalizedNumericGate"] = {**asdict(gate), "passed": gate.passed}
        report["conditions"][condition] = group
    return report


def main():
    """Write deterministic JSON to stdout; rejected inputs never produce a report."""
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("corpus", "rules", "live", "refined"):
        parser.add_argument("--" + name, required=True, type=Path)
    args = parser.parse_args()
    try:
        report = build_paired_report(args.corpus.read_bytes(), args.rules.read_bytes(),
                                     args.live.read_bytes(), args.refined.read_bytes())
    except (ValueError, OSError) as error:
        print("invalid_quality_inputs: " + str(error), file=sys.stderr)
        return 2
    print(json.dumps(report, sort_keys=True, separators=(",", ":"), allow_nan=False))
    return 0


if __name__ == '__main__':
    sys.exit(main())
