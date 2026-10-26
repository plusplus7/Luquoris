"""Pure stage reconciliation: omissions are failures, never empty successful output."""

import math
import unicodedata


def normalized(text):
    return "".join(c.casefold() for c in text if unicodedata.category(c)[0] in ("L", "N"))


def validate_stages(chunks, recognized, aligned):
    def key(item):
        return item["path"], item["startMs"], item["endMs"]

    if [key(x) for x in recognized] != [key(x) for x in chunks]:
        raise ValueError("recognition_coverage")
    expected = [x for x in recognized if normalized(x.get("text", ""))]
    if [key(x) for x in aligned] != [key(x) for x in expected]:
        raise ValueError("alignment_coverage")
    for raw, result in zip(expected, aligned, strict=True):
        if normalized(raw["text"]) != normalized("".join(w["text"] for w in result["words"])):
            raise ValueError("alignment_omission")


def merge_words(aligned, *, diagnostics=None):
    groups = []
    for chunk_index, item in enumerate(aligned):
        candidates = []
        words = []
        leading = []
        previous_end = 0
        for word in item["words"]:
            if not all(math.isfinite(word[k]) for k in ("start", "end")):
                raise ValueError("invalid_timestamp")
            start = item["startMs"] + round(word["start"] * 1000)
            end = item["startMs"] + round(word["end"] * 1000)
            if (
                start < item["startMs"]
                or end > item["endMs"]
                or end < start
                or word["start"] < previous_end
                or word["end"] < word["start"]
            ):
                raise ValueError("invalid_timestamp")
            previous_end = word["end"]
            if end == start:
                if words:
                    words[-1]["text"] += word["text"]
                    words[-1]["end"] = word["end"]
                else:
                    leading.append(word)
                continue
            if leading:
                word = {
                    **word,
                    "start": leading[0]["start"],
                    "text": "".join(w["text"] for w in leading) + word["text"],
                }
                leading = []
            words.append(dict(word))
        if leading:
            raise ValueError("unanchored_timestamp")
        for word in words:
            start = item["startMs"] + round(word["start"] * 1000)
            end = item["startMs"] + round(word["end"] * 1000)
            if word["text"].strip():
                candidates.append(
                    {
                        "startMs": start,
                        "endMs": end,
                        "text": word["text"],
                        "language": item["language"] or None,
                        "_chunk": chunk_index,
                        "_margin": min(start - item["startMs"], item["endMs"] - end),
                    }
                )
        groups.append(candidates)
    # Keep complete alternatives until a context owner is selected. Early
    # lexical dedup can otherwise remove a word shared by both hypotheses.
    selected = sorted((word for group in groups for word in group), key=lambda x: x["startMs"])
    components = []
    component = []
    end = -1
    for candidate in selected:
        if candidate["startMs"] >= end and component:
            components.append(component)
            component = []
        component.append(candidate)
        end = max(word["endMs"] for word in component)
    if component:
        components.append(component)
    joined = []
    for component in components:
        chunks = {word["_chunk"] for word in component}
        if (
            joined
            and len(chunks) > 1
            and chunks == {word["_chunk"] for word in joined[-1]}
            and min(w["startMs"] for w in component) == max(w["endMs"] for w in joined[-1])
        ):
            joined[-1].extend(component)
        else:
            joined.append(component)
    result = []
    conflicts = 0
    for component in joined:
        hypotheses = {}
        for word in component:
            hypotheses.setdefault(word["_chunk"], []).append(word)
        if (
            len({normalized("".join(w["text"] for w in group)) for group in hypotheses.values()})
            > 1
        ):
            conflicts += 1
        winner = max(
            hypotheses,
            key=lambda chunk: (min(w["_margin"] for w in hypotheses[chunk]), -chunk),
        )
        result.extend(hypotheses[winner])
    if diagnostics is not None:
        diagnostics["boundaryConflictGroups"] = conflicts
    return [{k: v for k, v in item.items() if not k.startswith("_")} for item in result]


def restore_surface(text, words):
    """Attach the original ASR separators and punctuation to aligned tokens."""
    words = [word for word in words if normalized(word["text"])]
    positions = []
    for index, char in enumerate(text):
        if unicodedata.category(char)[0] in ("L", "N"):
            positions.extend([index] * len(char.casefold()))
    if normalized(text) != normalized("".join(w["text"] for w in words)):
        raise ValueError("alignment_omission")
    cursor = 0
    consumed = 0
    result = []
    for i, word in enumerate(words):
        consumed += len(normalized(word["text"]))
        end = len(text) if i == len(words) - 1 else positions[consumed - 1] + 1
        result.append({**word, "text": text[cursor:end]})
        cursor = end
    return result
