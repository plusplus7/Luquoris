"""Reference-based scoring. Unmeasured resource fields remain null."""

import argparse
import json
import unicodedata
from pathlib import Path


def distance(left, right):
    previous = list(range(len(right) + 1))
    for i, a in enumerate(left, 1):
        current = [i]
        for j, b in enumerate(right, 1):
            current.append(min(previous[j] + 1, current[-1] + 1, previous[j - 1] + (a != b)))
        previous = current
    return previous[-1]


def score(reference, hypothesis, provenance):
    def chars(text):
        return [
            c.casefold()
            for c in unicodedata.normalize("NFC", text)
            if unicodedata.category(c)[0] in ("L", "N")
        ]

    words_ref, words_hyp = reference.casefold().split(), hypothesis.casefold().split()
    ref, hyp = chars(reference), chars(hypothesis)

    def measured(key):
        try:
            return float(provenance[key])
        except (KeyError, ValueError, TypeError):
            return None

    return {
        "cer": distance(ref, hyp) / max(1, len(ref)),
        "wer": distance(words_ref, words_hyp) / max(1, len(words_ref)),
        "missingWords": max(0, len(words_ref) - len(words_hyp)),
        "elapsedSeconds": measured("elapsedSeconds"),
        "coldStartupSeconds": measured("coldStartupSeconds"),
        "warmInferenceSeconds": measured("warmInferenceSeconds"),
        "measurementScope": provenance.get("measurementScope"),
        "peakVramBytes": measured("peakVramBytes"),
        "peakRssBytes": measured("peakRssBytes"),
        "provenance": provenance,
        "properNounErrors": None,
        "boundaryErrors": None,
        "notes": "WER uses whitespace tokens; CER ignores punctuation. MissingWords is a length lower bound, not a deletion alignment. Proper nouns and boundary omissions require annotated human review.",
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("result", type=Path)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = json.loads(args.result.read_text())
    hypothesis = "".join(x["text"] for x in result["segments"])
    report = score(args.reference.read_text(), hypothesis, result["provenance"])
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
