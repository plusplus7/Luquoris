"""Bounded audio and real child-process lifecycle tests; no model fakes in production."""

import array
import math
import sys
import wave

import pytest


def test_chunking_bounds_memory_and_preserves_offsets(tmp_path):
    from loquiris_server.audio import chunks

    source = tmp_path / "input.wav"
    with wave.open(str(source), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(16000)
        for second in range(3):
            out.writeframes(
                array.array("h", [int(8000 * math.sin(i / 10)) for i in range(16000)]).tobytes()
            )
    result = list(chunks(source, tmp_path / "chunks", start_ms=5000, budget_ms=1000))
    assert len(result) >= 3
    assert result[0]["startMs"] == 5000
    assert result[-1]["endMs"] == 8000
    for item in result:
        assert 0 < item["endMs"] - item["startMs"] <= 1000
        with wave.open(item["path"]) as audio:
            assert audio.getnframes() <= 16000


def test_silence_produces_no_speech_chunks(tmp_path):
    from loquiris_server.audio import chunks

    source = tmp_path / "silent.wav"
    with wave.open(str(source), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(16000)
        out.writeframes(b"\0\0" * 16000)
    assert list(chunks(source, tmp_path / "chunks", start_ms=0)) == []


def test_stage_timeout_reaps_process_and_returns_stable_error(tmp_path):
    from loquiris_server.runner import StageFailure, run_child

    with pytest.raises(StageFailure, match="stage_timeout"):
        run_child(
            [sys.executable, "-c", "import time; time.sleep(10)"],
            timeout_seconds=0.1,
            still_owned=lambda: True,
        )


def test_stage_cancel_reaps_process_without_waiting_for_timeout():
    from loquiris_server.runner import StageFailure, run_child

    with pytest.raises(StageFailure, match="cancelled"):
        run_child(
            [sys.executable, "-c", "import time; time.sleep(10)"],
            timeout_seconds=20,
            still_owned=lambda: False,
        )


def test_stage_never_leaks_model_exception_text():
    from loquiris_server.runner import StageFailure, run_child

    with pytest.raises(StageFailure, match="stage_failed") as error:
        run_child(
            [sys.executable, "-c", 'import sys; print("SECRET", file=sys.stderr); sys.exit(1)'],
            timeout_seconds=5,
            still_owned=lambda: True,
        )
    assert "SECRET" not in str(error.value)


def test_declared_duration_bounds_decoded_pcm(tmp_path):
    from loquiris_server.audio import chunks

    source = tmp_path / "long.wav"
    with wave.open(str(source), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(16000)
        out.writeframes(b"\1\0" * 32000)
    with pytest.raises(ValueError, match="duration"):
        list(chunks(source, tmp_path / "chunks", start_ms=0, duration_ms=1000))


def test_continuous_speech_has_bounded_overlap(tmp_path):
    from loquiris_server.audio import chunks

    source = tmp_path / "voice.wav"
    with wave.open(str(source), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(16000)
        out.writeframes(array.array("h", [8000, -8000] * 24000).tobytes())
    result = list(chunks(source, tmp_path / "chunks", budget_ms=1000))
    assert result[1]["startMs"] < result[0]["endMs"]
    assert result[0]["coreEndMs"] == result[1]["coreStartMs"]


def test_near_silence_quantization_noise_is_not_sent_to_asr(tmp_path):
    from loquiris_server.audio import chunks

    source = tmp_path / "quiet.wav"
    with wave.open(str(source), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(16000)
        out.writeframes(array.array("h", [1, -1] * 8000).tobytes())
    assert list(chunks(source, tmp_path / "chunks")) == []


def test_sealing_decoder_deadline_covers_hung_stdout_and_reaps_child(tmp_path):
    import subprocess
    import time

    from loquiris_server.media_validation import decoded_blocks

    child = subprocess.Popen(
        [sys.executable, "-c", "import time; time.sleep(60)"],
        stdout=subprocess.PIPE,
        start_new_session=True,
    )
    started = time.monotonic()
    try:
        with pytest.raises(ValueError, match="timeout"):
            list(decoded_blocks(child, timeout_seconds=0.1))
        assert child.poll() is not None
        assert time.monotonic() - started < 3
    finally:
        if child.poll() is None:
            child.kill()
        child.wait()
        child.stdout.close()
