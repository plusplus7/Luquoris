"""Worker-only dependency/weight probe; API reads its expiring heartbeat."""

import importlib.metadata
import json
import os
import threading
import time

from .models import verify_profile


def ready(root):
    try:
        value = json.loads((root / "worker-ready.json").read_text())
        return value["ready"] is True and 0 <= time.time() - value["checkedAt"] <= 30
    except (OSError, ValueError, KeyError, TypeError):
        return False


def probe(settings):
    # This function runs only in the worker, never in the HTTP process.
    try:
        import subprocess
        import sys

        for profile in settings.profiles:
            verify_profile(settings.model_dir, profile)
        importlib.metadata.version("qwen-asr")
        importlib.metadata.version("faster-whisper")
        # Probe in a reaped child, preserving stage-only CUDA context ownership.
        subprocess.run(
            [
                sys.executable,
                "-c",
                "import torch,qwen_asr,faster_whisper; assert torch.cuda.is_available()",
            ],
            check=True,
            timeout=60,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return True
    except Exception:
        return False


def start(settings):
    def maintain():
        while True:
            available = probe(settings)
            # Refresh during long inference without keeping a CUDA context here.
            for _ in range(12):
                target = settings.data_dir / "worker-ready.json"
                temporary = target.with_suffix(".tmp")
                temporary.write_text(json.dumps({"ready": available, "checkedAt": time.time()}))
                os.replace(temporary, target)
                time.sleep(5)

    threading.Thread(target=maintain, daemon=True).start()
