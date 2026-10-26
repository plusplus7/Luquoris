"""Model output validation must reject silent omissions before publication."""

import pytest


def sample():
    return [
        {
            "path": "/private/chunk.wav",
            "startMs": 0,
            "endMs": 1000,
            "coreStartMs": 0,
            "coreEndMs": 1000,
        }
    ]


def test_empty_or_missing_alignment_cannot_erase_recognized_speech():
    from loquiris_server.pipeline import validate_stages

    chunks = sample()
    recognized = [{**chunks[0], "text": "你好 world", "language": "Chinese,English"}]
    for alignment in (
        [],
        [{**recognized[0], "words": []}],
        [{**recognized[0], "words": [{"text": "你好", "start": 0, "end": 1}]}],
    ):
        with pytest.raises(ValueError):
            validate_stages(chunks, recognized, alignment)


def test_complete_alignment_is_accepted_and_mapped_to_media_time():
    from loquiris_server.pipeline import merge_words, validate_stages

    chunks = sample()
    recognized = [{**chunks[0], "text": "你好 world!", "language": "Chinese,English"}]
    aligned = [
        {
            **recognized[0],
            "words": [
                {"text": "你好", "start": 0, "end": 0.3},
                {"text": "world", "start": 0.4, "end": 0.8},
            ],
        }
    ]
    validate_stages(chunks, recognized, aligned)
    result = merge_words(aligned)
    assert result[1]["startMs"] == 400
    assert result[1]["text"] == "world"


def test_overlapping_windows_assign_words_once_by_media_midpoint():
    from loquiris_server.pipeline import merge_words

    common = {"language": "English", "words": [{"text": "boundary", "start": 0.7, "end": 0.9}]}
    first = {**common, "startMs": 0, "endMs": 1000, "coreStartMs": 0, "coreEndMs": 850}
    second = {
        **common,
        "startMs": 700,
        "endMs": 1700,
        "coreStartMs": 850,
        "coreEndMs": 1700,
        "words": [{"text": "boundary", "start": 0, "end": 0.2}],
    }
    assert len(merge_words([first, second])) == 1


def test_alignment_jitter_cannot_drop_both_boundary_hypotheses():
    from loquiris_server.pipeline import merge_words

    a = {
        "path": "a",
        "startMs": 0,
        "endMs": 30000,
        "coreStartMs": 0,
        "coreEndMs": 29850,
        "language": "English",
        "words": [{"text": "hello", "start": 29.830, "end": 29.890}],
    }
    b = {
        "path": "b",
        "startMs": 29700,
        "endMs": 59700,
        "coreStartMs": 29850,
        "coreEndMs": 59700,
        "language": "English",
        "words": [{"text": "hello", "start": 0.100, "end": 0.180}],
    }
    result = merge_words([a, b])
    assert len(result) == 1
    assert result[0]["text"] == "hello"


def test_point_tokens_preserve_text_using_existing_time_boundaries():
    from loquiris_server.pipeline import merge_words

    item = {
        **sample()[0],
        "language": "Chinese",
        "words": [
            {"text": "似", "start": 0.0, "end": 0.0},
            {"text": "乎", "start": 0.1, "end": 0.2},
            {"text": "有", "start": 0.3, "end": 0.3},
            {"text": "一些。", "start": 0.4, "end": 0.6},
            {"text": "好", "start": 0.6, "end": 0.6},
        ],
    }
    assert merge_words([item]) == [
        {"startMs": 0, "endMs": 300, "text": "似乎有", "language": "Chinese"},
        {"startMs": 400, "endMs": 600, "text": "一些。好", "language": "Chinese"},
    ]


@pytest.mark.parametrize(
    "words",
    [
        [{"text": "字", "start": 0.2, "end": 0.2}],
        [{"text": "倒", "start": 0.3, "end": 0.2}],
        [{"text": "外", "start": 1.1, "end": 1.1}],
        [
            {"text": "好", "start": 0.2, "end": 0.5},
            {"text": "倒", "start": 0.1, "end": 0.1},
        ],
    ],
)
def test_point_coalescing_still_rejects_invalid_or_unanchored_time(words):
    from loquiris_server.pipeline import merge_words

    with pytest.raises(ValueError):
        merge_words([{**sample()[0], "language": "Chinese", "words": words}])


def test_overlap_reconciles_identical_text_with_different_point_token_groups():
    from loquiris_server.pipeline import merge_words

    a = {
        "startMs": 0,
        "endMs": 1000,
        "language": "Chinese",
        "words": [
            {"text": "你", "start": 0.7, "end": 0.8},
            {"text": "好", "start": 0.8, "end": 0.8},
            {"text": "呀", "start": 0.8, "end": 0.9},
        ],
    }
    b = {
        "startMs": 700,
        "endMs": 1700,
        "language": "Chinese",
        "words": [
            {"text": "你", "start": 0, "end": 0.1},
            {"text": "好", "start": 0.1, "end": 0.2},
            {"text": "呀", "start": 0.2, "end": 0.2},
        ],
    }
    result = merge_words([a, b])
    assert "".join(x["text"] for x in result) == "你好呀"
    assert [(x["startMs"], x["endMs"]) for x in result] == [(700, 800), (800, 900)]


def test_group_overlap_selects_context_owned_hypothesis_and_counts_conflict():
    from loquiris_server.pipeline import merge_words

    a = {
        "startMs": 0,
        "endMs": 1000,
        "language": "Chinese",
        "words": [{"text": "你好", "start": 0.7, "end": 0.9}],
    }
    b = {
        "startMs": 700,
        "endMs": 1700,
        "language": "Chinese",
        "words": [{"text": "您好", "start": 0, "end": 0.2}],
    }
    diagnostics = {}
    result = merge_words([a, b], diagnostics=diagnostics)
    assert result == [{"startMs": 700, "endMs": 900, "text": "你好", "language": "Chinese"}]
    assert diagnostics == {"boundaryConflictGroups": 1}


def test_conflict_selects_whole_window_group_with_more_context():
    from loquiris_server.pipeline import merge_words

    a = {
        "startMs": 0,
        "endMs": 1000,
        "language": "Chinese",
        "words": [
            {"text": "请", "start": 0.85, "end": 0.93},
            {"text": "进", "start": 0.93, "end": 0.99},
        ],
    }
    b = {
        "startMs": 700,
        "endMs": 1700,
        "language": "Chinese",
        "words": [
            {"text": "走进", "start": 0.12, "end": 0.27},
            {"text": "来。", "start": 0.27, "end": 0.35},
            {"text": "继续", "start": 0.4, "end": 0.5},
        ],
    }
    diagnostics = {}
    result = merge_words([a, b], diagnostics=diagnostics)
    assert "".join(x["text"] for x in result) == "走进来。继续"
    assert [(x["startMs"], x["endMs"]) for x in result] == [(820, 970), (970, 1050), (1100, 1200)]
    assert diagnostics == {"boundaryConflictGroups": 1}


def test_context_resolution_keeps_shared_speech_until_ownership_is_selected():
    from loquiris_server.pipeline import merge_words

    a = {
        "startMs": 0,
        "endMs": 1000,
        "language": "English",
        "words": [
            {"text": "hello ", "start": 0.7, "end": 0.9},
            {"text": "there", "start": 0.9, "end": 0.95},
        ],
    }
    b = {
        "startMs": 700,
        "endMs": 1700,
        "language": "English",
        "words": [
            {"text": "hello ", "start": 0, "end": 0.1},
            {"text": "world", "start": 0.1, "end": 0.25},
        ],
    }
    result = merge_words([a, b])
    assert "".join(x["text"] for x in result) == "hello there"
