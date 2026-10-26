"""Raw AAC container duration is unreliable; validate bounded decoded samples."""

import subprocess
import threading


def decoded_blocks(process, timeout_seconds=300):
    expired = threading.Event()

    def stop():
        expired.set()
        try:
            process.kill()
        except ProcessLookupError:
            pass

    timer = threading.Timer(timeout_seconds, stop)
    timer.daemon = True
    timer.start()
    try:
        while True:
            block = process.stdout.read(65536)
            if expired.is_set():
                raise ValueError("decoder_timeout")
            if not block:
                break
            yield block
        process.wait()
        if expired.is_set():
            raise ValueError("decoder_timeout")
    finally:
        timer.cancel()
        if process.poll() is None:
            try:
                process.kill()
            except ProcessLookupError:
                pass
        process.wait()


def validate_samples(path, duration_ms):
    process = subprocess.Popen(
        [
            "ffmpeg",
            "-nostdin",
            "-v",
            "error",
            "-threads",
            "2",
            "-i",
            str(path),
            "-t",
            str((duration_ms + 251) / 1000),
            "-vn",
            "-ac",
            "1",
            "-ar",
            "16000",
            "-f",
            "s16le",
            "pipe:1",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    count = 0
    try:
        for block in decoded_blocks(process):
            count += len(block)
            if count > (duration_ms + 250) * 32:
                raise ValueError("decoded_duration_exceeded")
        if process.wait(timeout=30) != 0 or count < max(0, duration_ms - 250) * 32:
            raise ValueError("invalid_decoded_duration")
    finally:
        process.stdout.close()
        if process.poll() is None:
            process.kill()
        process.wait()
