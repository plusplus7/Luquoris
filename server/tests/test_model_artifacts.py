"""Local revision provenance must be invalidated if a prepared artifact changes."""

import hashlib
import json

import pytest


def test_verified_profile_is_bound_to_weight_bytes(tmp_path):
    from loquiris_server.models import verify_profile

    directory = tmp_path / "model"
    directory.mkdir()
    weights = directory / "model.safetensors"
    weights.write_bytes(b"original weights")
    manifest = {
        "model": "Qwen/Qwen3-ASR-1.7B",
        "revision": "a" * 40,
        "directory": "model",
        "artifacts": {"model/model.safetensors": hashlib.sha256(weights.read_bytes()).hexdigest()},
    }
    (tmp_path / "profiles.json").write_text(json.dumps({"qwen-1.7b": manifest}))
    assert verify_profile(tmp_path, "qwen-1.7b")["revision"] == "a" * 40
    weights.write_bytes(b"changed weights")
    with pytest.raises(ValueError, match="artifact"):
        verify_profile(tmp_path, "qwen-1.7b")
