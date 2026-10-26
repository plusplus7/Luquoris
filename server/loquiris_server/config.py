"""Explicit single-host settings; no model import or network I/O at startup."""

import hashlib
import json
import os
from dataclasses import dataclass, field
from pathlib import Path

PROFILES = {
    "qwen-1.7b": {"model": "Qwen/Qwen3-ASR-1.7B", "precision": "bfloat16"},
    "whisper-large-v3": {"model": "Systran/faster-whisper-large-v3", "precision": "int8_float16"},
}


@dataclass
class Settings:
    data_dir: Path
    tokens: dict[str, str]
    chunk_bytes: int = 1024 * 1024
    max_upload_bytes: int = 2 * 1024**3
    max_owner_bytes: int = 4 * 1024**3
    retention_seconds: int = 86400
    lease_seconds: int = 90
    max_attempts: int = 3
    stage_timeout_seconds: int = 3600
    model_dir: Path = Path("/models")
    profiles: dict[str, dict[str, str]] = field(
        default_factory=lambda: {"qwen-1.7b": dict(PROFILES["qwen-1.7b"])}
    )

    def __post_init__(self):
        self.data_dir = Path(self.data_dir)
        if not self.tokens or any(not k or len(v) < 32 for k, v in self.tokens.items()):
            raise ValueError("Configure unique client tokens of at least 32 characters")
        if len(set(self.tokens.values())) != len(self.tokens):
            raise ValueError("Client tokens must be unique")
        if not 1 <= self.chunk_bytes <= 8 * 1024**2:
            raise ValueError("Invalid chunk limit")
        if (
            min(
                self.retention_seconds,
                self.lease_seconds,
                self.max_attempts,
                self.max_upload_bytes,
                self.max_owner_bytes,
                self.stage_timeout_seconds,
            )
            <= 0
        ):
            raise ValueError("Limits must be positive")

    @classmethod
    def from_env(cls):
        enabled = os.environ.get("LOQUIRIS_ENABLED_PROFILES", "qwen-1.7b").split(",")
        if not enabled or any(p not in PROFILES for p in enabled):
            raise ValueError("Invalid enabled model profiles")
        return cls(
            profiles={p: dict(PROFILES[p]) for p in enabled},
            retention_seconds=int(os.environ.get("LOQUIRIS_RETENTION_SECONDS", "86400")),
            stage_timeout_seconds=int(os.environ.get("LOQUIRIS_STAGE_TIMEOUT_SECONDS", "3600")),
            data_dir=Path(os.environ.get("LOQUIRIS_DATA_DIR", "/data")),
            tokens=json.loads(os.environ.get("LOQUIRIS_CLIENT_TOKENS", "{}")),
            model_dir=Path(os.environ.get("LOQUIRIS_MODEL_DIR", "/models")),
        )

    def owner_for(self, token: str) -> str | None:
        import hmac

        received = hashlib.sha256(token.encode()).digest()
        for owner, secret in self.tokens.items():
            if hmac.compare_digest(received, hashlib.sha256(secret.encode()).digest()):
                return owner
        return None
