import hashlib
import json

import pytest


def test_unlisted_checkpoint_cannot_replace_verified_model(tmp_path):
    from loquiris_server.models import verify_profile

    model = tmp_path / "model"
    model.mkdir()
    weights = model / "model.safetensors"
    weights.write_bytes(b"original")
    profile = {
        "model": "test",
        "directory": "model",
        "revision": "a" * 40,
        "artifacts": {"model/model.safetensors": hashlib.sha256(weights.read_bytes()).hexdigest()},
    }
    (tmp_path / "profiles.json").write_text(json.dumps({"qwen-1.7b": profile}))
    (model / "pytorch_model.bin").write_bytes(b"unlisted replacement")
    with pytest.raises(ValueError, match="artifact"):
        verify_profile(tmp_path, "qwen-1.7b")
