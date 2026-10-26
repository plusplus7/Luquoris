"""Explicit weight preparation and byte-bound local provenance; no runtime download."""

import argparse
import hashlib
import json
import os
import re
from pathlib import Path


def verify_profile(root: Path, profile_id: str):
    root = root.resolve()
    profile = json.loads((root / "profiles.json").read_text())[profile_id]
    if not re.fullmatch("[a-f0-9]{40}", profile["revision"]):
        raise ValueError("model_revision")
    if not profile.get("artifacts"):
        raise ValueError("model_artifact_manifest")
    for relative, expected in profile["artifacts"].items():
        path = (root / relative).resolve()
        if not path.is_relative_to(root) or not path.is_file():
            raise ValueError("model_artifact_path")
        with path.open("rb") as stream:
            actual = hashlib.file_digest(stream, "sha256").hexdigest()
        if actual != expected:
            raise ValueError("model_artifact_digest")
    actual_files = set()
    for name in ("directory", "alignerDirectory"):
        if name not in profile:
            continue
        directory = (root / profile[name]).resolve()
        if not directory.is_relative_to(root) or not directory.is_dir():
            raise ValueError("model_artifact_path")
        for path in directory.rglob("*"):
            if path.is_file() and ".cache" not in path.relative_to(directory).parts:
                if not path.resolve().is_relative_to(directory):
                    raise ValueError("model_artifact_path")
                actual_files.add(str(path.relative_to(root)))
    if actual_files != set(profile["artifacts"]):
        raise ValueError("model_artifact_manifest")
    return profile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--qwen-revision", required=True)
    parser.add_argument("--aligner-revision", required=True)
    parser.add_argument("--whisper-revision")
    args = parser.parse_args()
    revisions = [args.qwen_revision, args.aligner_revision]
    if args.whisper_revision:
        revisions.append(args.whisper_revision)
    if any(not re.fullmatch("[a-f0-9]{40}", r) for r in revisions):
        parser.error("Every revision must be an explicit full Hugging Face commit SHA")
    from huggingface_hub import snapshot_download

    root = args.directory.resolve()
    root.mkdir(parents=True, exist_ok=True)

    def prepare(model, revision):
        target = root / (model.replace("/", "--") + "--" + revision)
        snapshot_download(repo_id=model, revision=revision, local_dir=target)
        artifacts = {}
        for path in target.rglob("*"):
            if path.is_file() and ".cache" not in path.relative_to(target).parts:
                with path.open("rb") as stream:
                    artifacts[str(path.relative_to(root))] = hashlib.file_digest(
                        stream, "sha256"
                    ).hexdigest()
        return target.name, artifacts

    qwen, qwen_files = prepare("Qwen/Qwen3-ASR-1.7B", args.qwen_revision)
    aligner, align_files = prepare("Qwen/Qwen3-ForcedAligner-0.6B", args.aligner_revision)
    profiles = {
        "qwen-1.7b": {
            "model": "Qwen/Qwen3-ASR-1.7B",
            "revision": args.qwen_revision,
            "directory": qwen,
            "alignerDirectory": aligner,
            "alignerRevision": args.aligner_revision,
            "artifacts": {**qwen_files, **align_files},
        }
    }
    if args.whisper_revision:
        whisper, artifacts = prepare("Systran/faster-whisper-large-v3", args.whisper_revision)
        profiles["whisper-large-v3"] = {
            "model": "Systran/faster-whisper-large-v3",
            "revision": args.whisper_revision,
            "directory": whisper,
            "artifacts": artifacts,
        }
    temporary = root / "profiles.tmp"
    with temporary.open("w") as stream:
        stream.write(json.dumps(profiles, indent=2))
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, root / "profiles.json")
    for profile in profiles:
        verify_profile(root, profile)
    print("Prepared and verified profiles:", ", ".join(profiles))


if __name__ == "__main__":
    main()
