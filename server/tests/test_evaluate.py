def test_evaluation_reports_real_error_rates_without_inventing_resource_metrics():
    from loquiris_server.evaluate import score

    result = score("hello world", "hello word", {"modelRevision": "a" * 40, "runtime": "test"})
    assert result["wer"] == 0.5
    assert result["cer"] > 0
    assert result["peakVramBytes"] is None
    assert result["missingWords"] == 0


def test_surface_restores_recognizer_spacing_and_punctuation():
    from loquiris_server.pipeline import restore_surface

    words = [{"text": "Hello", "start": 0, "end": 0.2}, {"text": "world", "start": 0.3, "end": 0.5}]
    value = restore_surface("Hello, world!", words)
    assert "".join(w["text"] for w in value) == "Hello, world!"


def test_surface_handles_punctuation_only_alignment_tokens():
    from loquiris_server.pipeline import restore_surface

    words = [{"text": ",", "start": 0, "end": 0.1}, {"text": "Hello", "start": 0.1, "end": 0.5}]
    value = restore_surface("Hello!", words)
    assert "".join(w["text"] for w in value) == "Hello!"
    assert len(value) == 1


def test_cold_and_warm_measurements_remain_distinct():
    from loquiris_server.evaluate import score

    value = score("hello", "hello", {"coldStartupSeconds": "2.5", "warmInferenceSeconds": "0.4"})
    assert value["coldStartupSeconds"] == 2.5
    assert value["warmInferenceSeconds"] == 0.4
