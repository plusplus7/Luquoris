"""Exercise the optional decoder dependency boundary without loading a GPU model."""

import wave

import pytest


def test_whisper_decodes_bounded_pcm_with_locked_pyav(tmp_path):
    pytest.importorskip("faster_whisper")
    from faster_whisper.audio import decode_audio

    path = tmp_path / "chunk.wav"
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(16000)
        output.writeframes(b"\x00\x40" * 1600)
    samples = decode_audio(str(path))
    assert samples.shape == (1600,)
    assert samples.dtype.name == "float32"
    assert samples[0] == 0.5
