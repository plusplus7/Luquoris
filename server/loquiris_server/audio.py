"""Bounded decoding with overlapping windows and declared-media geometry checks."""

import array
import subprocess
import sys
import wave
from pathlib import Path


def below_silence(pcm, threshold=16):
    samples = array.array("h", pcm)
    if sys.byteorder != "little":
        samples.byteswap()
    return sum(sample * sample for sample in samples) <= len(samples) * threshold * threshold


def chunks(source: Path, destination: Path, start_ms=0, budget_ms=30000, duration_ms=None):
    if not 200 <= budget_ms <= 60000:
        raise ValueError("chunk_budget")
    destination.mkdir(parents=True, exist_ok=True)
    width = budget_ms * 32
    overlap = min(300, budget_ms // 4) * 32
    command = [
        "ffmpeg",
        "-nostdin",
        "-v",
        "error",
        "-threads",
        "2",
        "-i",
        str(source),
        "-t",
        str((duration_ms + 251) / 1000) if duration_ms else "43200",
        "-vn",
        "-ac",
        "1",
        "-ar",
        "16000",
        "-f",
        "s16le",
        "pipe:1",
    ]
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    buffer, offset, index, decoded = b"", 0, 0, 0
    eof = False
    try:
        while True:
            while len(buffer) < width and not eof:
                block = process.stdout.read(width - len(buffer))
                decoded += len(block)
                if duration_ms is not None and decoded > (duration_ms + 250) * 32:
                    raise ValueError("decoded_duration_exceeded")
                eof = not block
                buffer += block
            if not buffer:
                break
            count = len(buffer)
            if duration_ms is not None:
                count = min(count, max(0, duration_ms * 32 - offset))
            if count == 0:
                # Drain bounded padding so extra decoded audio is still rejected.
                while not eof:
                    block = process.stdout.read(8192)
                    decoded += len(block)
                    eof = not block
                    if decoded > (duration_ms + 250) * 32:
                        raise ValueError("decoded_duration_exceeded")
                break
            if count == width:
                for candidate in range(width - 640, int(width * 0.8), -640):
                    if below_silence(buffer[candidate : candidate + 640], threshold=100):
                        count = candidate + 640
                        break
            pcm = buffer[:count]
            last = eof or (duration_ms is not None and offset + count >= duration_ms * 32)
            if len(pcm) % 2:
                raise ValueError("invalid_pcm")
            if not below_silence(pcm):
                path = destination / f"{index:06d}.wav"
                with wave.open(str(path), "wb") as out:
                    out.setnchannels(1)
                    out.setsampwidth(2)
                    out.setframerate(16000)
                    out.writeframes(pcm)
                yield {
                    "path": str(path),
                    "startMs": start_ms + offset // 32,
                    "endMs": start_ms + (offset + count) // 32,
                    "coreStartMs": start_ms + (offset + (overlap // 2 if offset else 0)) // 32,
                    "coreEndMs": start_ms + (offset + count - (0 if last else overlap // 2)) // 32,
                }
                index += 1
            advance = count if last else count - overlap
            buffer = buffer[advance:]
            offset += advance
        if process.wait(timeout=30) != 0:
            raise ValueError("invalid_media")
        if duration_ms is not None and decoded < max(0, duration_ms - 250) * 32:
            raise ValueError("decoded_duration_missing")
    finally:
        process.stdout.close()
        if process.poll() is None:
            process.kill()
        process.wait()
