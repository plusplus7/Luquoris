"""Killing a coordinator must not release GPU exclusion ahead of its child."""

import fcntl
import os
import signal
import subprocess
import sys
import time


def test_inference_child_retains_gpu_lock_after_parent_sigkill(tmp_path):
    parent = tmp_path / "parent.py"
    lock = tmp_path / "gpu.lock"
    pidfile = tmp_path / "child.pid"
    parent.write_text(
        """import fcntl,sys
from loquiris_server.runner import run_child
with open(sys.argv[1], 'a+b') as guard:
 fcntl.flock(guard, fcntl.LOCK_EX)
 command=[sys.executable, '-c', "import os,time,pathlib; pathlib.Path(%r).write_text(str(os.getpid())); time.sleep(30)"]
 run_child(command, timeout_seconds=60, still_owned=lambda: True, gpu_lock_fd=guard.fileno())
"""
        % str(pidfile)
    )
    proc = subprocess.Popen([sys.executable, str(parent), str(lock)])
    child = None
    try:
        deadline = time.monotonic() + 5
        while not pidfile.exists() and proc.poll() is None and time.monotonic() < deadline:
            time.sleep(0.02)
        assert pidfile.exists(), "child must have started"
        child = int(pidfile.read_text())
        proc.kill()
        proc.wait()
        with lock.open("a+b") as other:
            try:
                fcntl.flock(other, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                pass
            else:
                raise AssertionError("Live inference child lost GPU exclusion")
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        if child:
            try:
                os.kill(child, signal.SIGKILL)
            except ProcessLookupError:
                pass
