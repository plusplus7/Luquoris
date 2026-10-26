"""Isolated inference phases. Model code is imported only in this executable."""

import importlib.metadata
import json
import os
import sys
from pathlib import Path


def execute(request, phase):
    if phase == "decode":
        from .audio import chunks

        result = []
        for item in request["files"]:
            result.extend(
                chunks(
                    Path(item["path"]),
                    Path(item["chunks"]),
                    start_ms=item["startMs"],
                    duration_ms=item["durationMs"],
                )
            )
        return result
    import torch

    torch.set_num_threads(4)
    torch.cuda.reset_peak_memory_stats()
    if phase == "recognize":
        if request["profileId"] == "whisper-large-v3":
            from faster_whisper import WhisperModel

            model = WhisperModel(
                request["modelPath"],
                device="cuda",
                compute_type="int8_float16",
                cpu_threads=4,
                num_workers=1,
                local_files_only=True,
            )
            result = []
            for item in request["chunks"]:
                segments, info = model.transcribe(
                    item["path"], beam_size=5, vad_filter=True, word_timestamps=True
                )
                words = [
                    {"text": w.word, "start": w.start, "end": w.end}
                    for segment in segments
                    for w in (segment.words or [])
                ]
                result.append(
                    {
                        **item,
                        "words": words,
                        "text": "".join(w["text"] for w in words),
                        "language": info.language,
                    }
                )
            return result
        from qwen_asr import Qwen3ASRModel

        model = Qwen3ASRModel.from_pretrained(
            request["modelPath"],
            dtype=torch.bfloat16,
            device_map="cuda:0",
            max_inference_batch_size=1,
            max_new_tokens=1024,
        )
        result = []
        for item in request["chunks"]:
            value = model.transcribe(audio=item["path"], language=None)[0]
            result.append({**item, "text": value.text, "language": value.language})
        return result
    if phase == "align":
        from qwen_asr import Qwen3ForcedAligner

        model = Qwen3ForcedAligner.from_pretrained(
            request["alignerPath"], dtype=torch.bfloat16, device_map="cuda:0"
        )
        result = []
        for item in request["recognized"]:
            if not item["text"].strip():
                continue
            language = item["language"].split(",")[0].strip()
            aligned = model.align(audio=item["path"], text=item["text"], language=language)[0]
            result.append(
                {
                    **item,
                    "words": [
                        {"text": w.text, "start": w.start_time, "end": w.end_time} for w in aligned
                    ],
                }
            )
        return result
    raise ValueError("unknown_stage")


def main():
    if sys.platform == "linux":
        import ctypes
        import signal

        if ctypes.CDLL(None).prctl(1, signal.SIGKILL, 0, 0, 0) != 0:
            sys.exit(43)
        if os.getppid() != int(os.environ["LOQUIRIS_WORKER_PID"]):
            sys.exit(43)
    phase, request_path, output_path = sys.argv[1:]
    os.environ["HF_HUB_OFFLINE"] = "1"
    request = json.loads(Path(request_path).read_text())
    try:
        result = execute(request, phase)
        import resource

        usage = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
        metadata = {
            "phase": phase,
            "peakRssBytes": usage if sys.platform == "darwin" else usage * 1024,
        }
        if phase != "decode":
            import torch

            metadata.update(
                peakVramBytes=torch.cuda.max_memory_allocated()
                if request["profileId"] != "whisper-large-v3"
                else None,
                runtime=importlib.metadata.version("qwen-asr")
                if request["profileId"] != "whisper-large-v3"
                else importlib.metadata.version("faster-whisper"),
            )
        Path(output_path).write_text(json.dumps({"items": result, "metadata": metadata}))
    except Exception as error:
        # Stable exit codes carry no model text, paths or credentials.
        if "out of memory" in str(error).lower():
            sys.exit(42)
        if isinstance(error, (ImportError, FileNotFoundError)):
            sys.exit(43)
        sys.exit(44)


if __name__ == "__main__":
    main()
