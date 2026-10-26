"""Single-GPU durable worker. flock is held until all stage children are reaped."""

import fcntl
import json
import shutil
import sys
import threading
import time

from .config import Settings
from .models import verify_profile
from .pipeline import merge_words, restore_surface, validate_stages
from .runner import StageFailure, run_child
from .store import Store


def run_job(store, claim, gpu_lock_fd=None):
    settings = store.settings
    work = store.root / "work" / claim["id"]
    work.mkdir(exist_ok=True)
    owned = threading.Event()
    owned.set()
    done = threading.Event()

    def renew():
        while not done.wait(min(settings.lease_seconds / 3, 10)):
            try:
                if not store.heartbeat(claim["id"], claim["generation"]):
                    owned.clear()
                    return
            except Exception:
                owned.clear()
                return

    thread = threading.Thread(target=renew, daemon=True)
    thread.start()
    started = time.monotonic()
    metadata = {}
    try:
        profile = verify_profile(settings.model_dir, claim["profile"])
        model = settings.model_dir / profile["directory"]
        aligner = settings.model_dir / profile.get("alignerDirectory", "")
        for revision in [profile["revision"], profile.get("alignerRevision", profile["revision"])]:
            if len(revision) != 40 or any(c not in "0123456789abcdef" for c in revision):
                raise StageFailure("model_unavailable")
        request = {
            "profileId": claim["profile"],
            "modelPath": str(model),
            "alignerPath": str(aligner),
            "files": [
                {
                    **f,
                    "path": str(store.root / "uploads" / claim["upload_id"] / f["fileId"]),
                    "chunks": str(work / f["fileId"]),
                }
                for f in claim["upload"]["files"]
            ],
        }

        def stage(phase):
            source, destination = work / f"{phase}-input.json", work / f"{phase}-output.json"
            source.write_text(json.dumps(request))
            run_child(
                [
                    sys.executable,
                    "-m",
                    "loquiris_server.stage",
                    phase,
                    str(source),
                    str(destination),
                ],
                timeout_seconds=settings.stage_timeout_seconds,
                still_owned=owned.is_set,
                gpu_lock_fd=gpu_lock_fd,
            )
            value = json.loads(destination.read_text())
            metadata[phase] = value["metadata"]
            return value["items"]

        request["chunks"] = stage("decode")
        request["recognized"] = stage("recognize")
        aligned = (
            request["recognized"] if claim["profile"] == "whisper-large-v3" else stage("align")
        )
        if claim["profile"] == "whisper-large-v3":
            aligned = [x for x in aligned if x.get("text", "").strip()]
        validate_stages(request["chunks"], request["recognized"], aligned)
        for item in aligned:
            item["words"] = restore_surface(item["text"], item["words"])
        diagnostics = {}
        segments = merge_words(aligned, diagnostics=diagnostics)
        value = {
            "schemaVersion": 1,
            "jobId": claim["id"],
            "meetingId": claim["upload"]["meetingId"],
            "runId": claim["upload"]["runId"],
            "audioManifestDigest": claim["audioManifestDigest"],
            "durationMs": sum(f["durationMs"] for f in claim["upload"]["files"]),
            "provenance": {
                "model": profile["model"],
                "modelRevision": profile["revision"],
                "runtime": metadata["recognize"]["runtime"],
                "precision": "bfloat16" if claim["profile"] == "qwen-1.7b" else "int8_float16",
                "alignerRevision": profile.get("alignerRevision", "integrated"),
                "chunkPolicy": "silence-boundary-30000ms-v1",
                "timestampPolicy": "coalesced-zero-duration-v1",
                "overlapPolicy": "complete-context-alternatives-v2",
                "boundaryPolicy": "whole-group-max-min-context-v1",
                "boundaryConflictGroups": str(diagnostics["boundaryConflictGroups"]),
                "batchSize": "1",
                "measurementScope": "cold-job-wall-time; max-stage-RSS; torch-allocator-VRAM-excludes-driver",
                "peakRssBytes": str(max(m.get("peakRssBytes", 0) for m in metadata.values())),
                "elapsedSeconds": str(time.monotonic() - started),
                "peakVramBytes": str(
                    max(
                        (
                            m["peakVramBytes"]
                            for m in metadata.values()
                            if m.get("peakVramBytes") is not None
                        ),
                        default="unmeasured",
                    )
                ),
            },
            "segments": segments,
        }
        store.finish(claim, value)
    except (FileNotFoundError, KeyError):
        store.fail(claim, "model_unavailable")
    except StageFailure as error:
        if str(error) != "cancelled":
            store.fail(claim, str(error), retryable=str(error) in ("stage_timeout", "gpu_memory"))
    except Exception:
        store.fail(claim, "worker_failed")
    finally:
        done.set()
        thread.join()
        shutil.rmtree(work, ignore_errors=True)


def main():
    settings = Settings.from_env()
    store = Store(settings)
    from .readiness import start

    start(settings)
    while True:
        # Also excludes a cancelled/stale process still holding GPU resources.
        with (store.root / ".gpu.lock").open("a+b") as guard:
            try:
                fcntl.flock(guard, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                time.sleep(1)
                continue
            store.cleanup()
            claim = store.claim()
            if claim:
                run_job(store, claim, gpu_lock_fd=guard.fileno())
            fcntl.flock(guard, fcntl.LOCK_UN)
        time.sleep(1)


if __name__ == "__main__":
    main()
