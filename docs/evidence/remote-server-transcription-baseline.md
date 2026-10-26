# Remote transcription implementation baseline

Started 2026-10-21 at HEAD `6b528f7128983a3ce440dc5006eaba6802b033ad`.
The workspace already contains extensive tracked/untracked offline recording and
streaming/refinement work. Preserve it; do not reset, stash, or attribute it to
this change. A machine-local content-hash inventory and status snapshot were
captured at `/tmp/loquiris-remote-baseline.json` and
`/tmp/loquiris-remote-baseline.status` before implementation.

The pending bootstrap and offline-streaming changes remain incomplete. New remote
work has a distinct backend and must never auto-upload historical local jobs.
Local recording remains authoritative. Existing symbol edits require upstream
GitNexus impact and risk reporting; new modules have no indexed callers yet.

Execution environment: macOS arm64, Python 3.12 available via uv, ffmpeg available.
Target deployment: user-owned Windows/WSL2, RTX 3080 Ti 12GB, 8 cores, 32GB RAM.
No SSH or remote GPU access is available. Hardware, CUDA/WSL2, accuracy corpus and
physical phone-to-server acceptance must remain unverified until exercised there.
