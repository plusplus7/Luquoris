"""Cancelable process-group execution: raw model diagnostics never reach API output."""

import os
import signal
import subprocess
import time


class StageFailure(Exception):
    pass


def run_child(command, *, timeout_seconds, still_owned, gpu_lock_fd=None):
    started = time.monotonic()
    process = subprocess.Popen(
        command,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
        pass_fds=() if gpu_lock_fd is None else (gpu_lock_fd,),
        env={**os.environ, "LOQUIRIS_WORKER_PID": str(os.getpid())},
    )
    try:
        while True:
            if not still_owned():
                raise StageFailure("cancelled")
            status = process.poll()
            if status is not None:
                if status != 0:
                    raise StageFailure(
                        {42: "gpu_memory", 43: "model_unavailable", 44: "invalid_model_output"}.get(
                            status, "stage_failed"
                        )
                    )
                return
            if time.monotonic() - started >= timeout_seconds:
                raise StageFailure("stage_timeout")
            time.sleep(0.05)
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
        process.wait()
