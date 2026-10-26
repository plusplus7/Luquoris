"""Synthetic pre-tokenized report inputs; never a qualifying speech corpus."""

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from paired_report import build_paired_report


def fixture_inputs():
    rules = b'Explicit synthetic tokens; no automatic normalization. Version 1.\n'
    rows = [
        {"id": "zh-short", "stratum": "chinese", "condition": "digital",
         "audioSha256": "a" * 64, "rawReference": ["刘", "梁"],
         "normalizedReference": ["刘", "梁"]},
        {"id": "zh-long", "stratum": "chinese", "condition": "digital",
         "audioSha256": "b" * 64, "rawReference": ["中"] * 8,
         "normalizedReference": ["中"] * 8},
        {"id": "en", "stratum": "english", "condition": "digital",
         "audioSha256": "c" * 64, "rawReference": ["Use", "ONNX", "."],
         "normalizedReference": ["use", "onnx"]},
        {"id": "mix", "stratum": "mixed", "condition": "digital",
         "audioSha256": "d" * 64, "rawReference": ["用", "Zoom", "API"],
         "normalizedReference": ["用", "zoom", "api"]},
    ]
    corpus = {"schemaVersion": 1, "scoringRulesSha256": hashlib.sha256(rules).hexdigest(),
              "utterances": rows}
    live = {"schemaVersion": 1, "corpusSha256": "", "modelManifestSha256": "e" * 64,
            "scoringRulesSha256": corpus["scoringRulesSha256"], "utterances": [
                {"id": r["id"], "audioSha256": r["audioSha256"],
                 "rawHypothesis": list(r["rawReference"]),
                 "normalizedHypothesis": list(r["normalizedReference"])} for r in rows]}
    live["utterances"][0]["rawHypothesis"] = ["刘", "良"]
    live["utterances"][0]["normalizedHypothesis"] = ["刘", "良"]
    live["utterances"][2]["rawHypothesis"] = ["use", "ONNX", "."]
    refined = copy.deepcopy(live)
    refined["modelManifestSha256"] = "f" * 64
    refined["utterances"][0]["rawHypothesis"] = ["刘", "梁"]
    refined["utterances"][0]["normalizedHypothesis"] = ["刘", "梁"]
    return rules, corpus, live, refined


class PairedReportTest(unittest.TestCase):
    def test_repo_root_module_entry_point(self):
        root = Path(__file__).resolve().parents[2]
        result = subprocess.run([sys.executable, "-m", "tool.transcription_quality.paired_report", "--help"],
                                cwd=root, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--corpus", result.stdout)

    def test_hand_derived_raw_normalized_and_pooled_counts(self):
        rules, corpus, live, refined = fixture_inputs()
        corpus_bytes = json.dumps(corpus).encode()
        for run in (live, refined):
            run["corpusSha256"] = hashlib.sha256(corpus_bytes).hexdigest()
        before = copy.deepcopy((corpus, live, refined))
        report = build_paired_report(corpus_bytes, rules, json.dumps(live).encode(),
                                     json.dumps(refined).encode())
        self.assertIn("conditions", report)
        result = report["conditions"]["digital"]
        self.assertEqual(result["live"]["normalized"]["chinese"]["rate"], [1, 10])
        self.assertEqual(result["live"]["raw"]["english"]["substitutions"], 1)
        self.assertEqual(result["live"]["normalized"]["english"]["rate"], [0, 1])
        self.assertEqual(result["live"]["normalized"]["equallyWeightedRate"], [1, 30])
        self.assertEqual(result["refined"]["normalized"]["chinese"]["rate"], [0, 1])
        self.assertTrue(result["normalizedNumericGate"]["passed"])
        self.assertEqual(report["qualificationStatus"], "not-assessed")
        self.assertEqual([r["id"] for r in report["utterances"]],
                         ["en", "mix", "zh-long", "zh-short"])
        self.assertEqual((corpus, live, refined), before)

    def test_conditions_are_never_pooled_together(self):
        rules, corpus, live, refined = fixture_inputs()
        for r in list(corpus["utterances"]):
            extra = copy.deepcopy(r)
            extra["id"] += "-room"
            extra["condition"] = "room"
            corpus["utterances"].append(extra)
        for run in (live, refined):
            for r in list(run["utterances"]):
                extra = copy.deepcopy(r)
                extra["id"] += "-room"
                extra["rawHypothesis"] = []
                extra["normalizedHypothesis"] = []
                run["utterances"].append(extra)
        corpus_bytes = json.dumps(corpus).encode()
        for run in (live, refined):
            run["corpusSha256"] = hashlib.sha256(corpus_bytes).hexdigest()
        report = build_paired_report(corpus_bytes, rules, json.dumps(live).encode(),
                                     json.dumps(refined).encode())
        self.assertIn("conditions", report)
        self.assertEqual(set(report["conditions"]), {"digital", "room"})
        self.assertEqual(report["conditions"]["room"]["live"]["normalized"]
                         ["chinese"]["rate"], [1, 1])
        self.assertTrue(report["conditions"]["digital"]["normalizedNumericGate"]["passed"])
        self.assertFalse(report["conditions"]["room"]["normalizedNumericGate"]["passed"])

    def test_pairing_rejects_missing_extra_duplicate_and_changed_audio(self):
        for mutation in ("missing", "extra", "duplicate", "audio", "corpus-duplicate"):
            with self.subTest(mutation=mutation):
                rules, corpus, live, refined = fixture_inputs()
                if mutation == "missing":
                    refined["utterances"].pop()
                elif mutation == "extra":
                    extra = copy.deepcopy(refined["utterances"][0])
                    extra["id"] = "unknown"
                    refined["utterances"].append(extra)
                elif mutation == "duplicate":
                    refined["utterances"].append(refined["utterances"][0])
                elif mutation == "audio":
                    refined["utterances"][0]["audioSha256"] = "0" * 64
                else:
                    corpus["utterances"].append(corpus["utterances"][0])
                corpus_bytes = json.dumps(corpus).encode()
                for run in (live, refined):
                    run["corpusSha256"] = hashlib.sha256(corpus_bytes).hexdigest()
                with self.assertRaises(ValueError):
                    build_paired_report(corpus_bytes, rules, json.dumps(live).encode(),
                                        json.dumps(refined).encode())

    def test_hashes_bind_exact_corpus_and_frozen_rules_bytes(self):
        for mutation in ("corpus-bytes", "rules-bytes", "run-rules", "model-hash"):
            with self.subTest(mutation=mutation):
                rules, corpus, live, refined = fixture_inputs()
                corpus_bytes = json.dumps(corpus).encode()
                for run in (live, refined):
                    run["corpusSha256"] = hashlib.sha256(corpus_bytes).hexdigest()
                if mutation == "corpus-bytes":
                    corpus_bytes += b'\n'
                elif mutation == "rules-bytes":
                    rules += b'changed'
                elif mutation == "run-rules":
                    refined["scoringRulesSha256"] = "0" * 64
                else:
                    live["modelManifestSha256"] = "not-a-digest"
                with self.assertRaises(ValueError):
                    build_paired_report(corpus_bytes, rules, json.dumps(live).encode(),
                                        json.dumps(refined).encode())

    def test_invalid_tokens_and_missing_strata_fail_closed(self):
        for mutation in ("implicit", "empty-token", "missing-stratum", "unknown-key", "bool-schema"):
            with self.subTest(mutation=mutation):
                rules, corpus, live, refined = fixture_inputs()
                if mutation == "implicit":
                    live["utterances"][0]["rawHypothesis"] = "刘梁"
                elif mutation == "empty-token":
                    live["utterances"][0]["normalizedHypothesis"] = [""]
                elif mutation == "missing-stratum":
                    corpus["utterances"] = [r for r in corpus["utterances"] if r["stratum"] != "mixed"]
                    for run in (live, refined):
                        run["utterances"] = [r for r in run["utterances"] if r["id"] != "mix"]
                elif mutation == "unknown-key":
                    corpus["unreviewedNormalization"] = True
                else:
                    corpus["schemaVersion"] = True
                corpus_bytes = json.dumps(corpus).encode()
                for run in (live, refined):
                    run["corpusSha256"] = hashlib.sha256(corpus_bytes).hexdigest()
                with self.assertRaises(ValueError):
                    build_paired_report(corpus_bytes, rules, json.dumps(live).encode(),
                                        json.dumps(refined).encode())

    def test_cli_runs_real_files_and_rejects_invalid_pair(self):
        rules, corpus, live, refined = fixture_inputs()
        corpus_bytes = json.dumps(corpus).encode()
        for run in (live, refined):
            run["corpusSha256"] = hashlib.sha256(corpus_bytes).hexdigest()
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name, data in (("corpus", corpus_bytes), ("rules", rules),
                               ("live", json.dumps(live).encode()),
                               ("refined", json.dumps(refined).encode())):
                (root / name).write_bytes(data)
            command = [sys.executable, str(Path(__file__).with_name("paired_report.py")),
                       "--corpus", str(root / "corpus"), "--rules", str(root / "rules"),
                       "--live", str(root / "live"), "--refined", str(root / "refined")]
            completed = subprocess.run(command, capture_output=True, text=True, check=False)
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertTrue(completed.stdout.strip())
            report = json.loads(completed.stdout)
            self.assertEqual(report["corpusSha256"], hashlib.sha256(corpus_bytes).hexdigest())
            self.assertEqual(report["qualificationStatus"], "not-assessed")
            self.assertEqual(subprocess.run(command, capture_output=True, check=False).stdout,
                             completed.stdout.encode())
            (root / "rules").write_bytes(b'changed')
            failed = subprocess.run(command, capture_output=True, text=True, check=False)
            self.assertEqual(failed.returncode, 2)
            self.assertEqual(failed.stdout, "")
            self.assertIn("invalid_quality_inputs", failed.stderr)

    def test_duplicate_json_keys_and_nonfinite_numbers_are_rejected(self):
        rules, corpus, live, refined = fixture_inputs()
        ordinary = json.dumps(corpus).encode()
        for value in (ordinary.replace(b'"schemaVersion": 1',
                                        b'"schemaVersion": 1, "schemaVersion": 1'),
                      ordinary.replace(b'"schemaVersion": 1', b'"schemaVersion": NaN'),
                      ordinary.replace(b'"schemaVersion": 1', b'"schemaVersion": Infinity')):
            for run in (live, refined):
                run["corpusSha256"] = hashlib.sha256(value).hexdigest()
            with self.subTest(value=value), self.assertRaises(ValueError):
                build_paired_report(value, rules, json.dumps(live).encode(),
                                     json.dumps(refined).encode())


if __name__ == '__main__':
    unittest.main()
