# RTX 3080 Ti / Windows WSL2 verification — 2026-10-22

Target: user-provided SSH `Jacki@192.168.1.20`, Windows 11, existing
`OpenClawGateway` Ubuntu 24.04 WSL2 distribution, RTX 3080 Ti 12288 MiB.
Windows reports approximately 32 GiB RAM and 32 logical processors; WSL currently
has approximately 15 GiB RAM. No WSL restart, memory-limit change or desktop
application termination was performed. The existing gateway remains running.

## Deployment scope

Native Linux verification installation:
`/home/openclaw/loquiris-remote-20261022`.

- Installed ffmpeg, sox, libgomp1 and Python venv support using Ubuntu packages.
- uv 0.8.6 creates a project-local `.venv` from the frozen GPU lock.
- Model weights use immutable upstream revisions and all downloaded bytes are
  verified by the model artifact manifest before inference.
- Separate `loquiris-remote-api` and `loquiris-remote-worker` systemd services run
  as the unprivileged `openclaw` account. New units and private project data are
  separate from the existing gateway. Services have not been enabled at boot.
- API binds only `127.0.0.1:18000`. No firewall, public listener, certificate trust
  or Windows/phone networking configuration was changed.
- Credentials are generated on target in `server.env` with mode 0600; no token,
  private key or environment file is included in this report.
- User explicitly chose **server GPU verification only**; phone HTTPS and full
  mobile end-to-end acceptance remain outstanding.

Service inspection from the Windows SSH session:

```text
wsl -d OpenClawGateway -u root -- systemctl status loquiris-remote-api loquiris-remote-worker
wsl -d OpenClawGateway -u root -- systemctl stop loquiris-remote-api loquiris-remote-worker
wsl -d OpenClawGateway -u root -- systemctl start loquiris-remote-api loquiris-remote-worker
```

This is native WSL2 evidence. Previous Docker image builds passed, but this run
neither installs Docker nor claims target Docker/CUDA-container acceptance.

## Revisions and runtime

| Component | Revision/version |
| --- | --- |
| Qwen/Qwen3-ASR-1.7B | `7278e1e70fe206f11671096ffdd38061171dd6e5` |
| Qwen/Qwen3-ForcedAligner-0.6B | `c7cbfc2048c462b0d63a45797104fc9db3ad62b7` |
| Systran/faster-whisper-large-v3 | `edaa852ec7e145841d8ffdb056a99866b5f0a478` |
| PyTorch | 2.6.0+cu124 |
| qwen-asr / transformers | 0.0.6 / 4.57.6 |
| faster-whisper / PyAV | 1.2.1 / 18.1.0 |

Model cards list [Qwen ASR](https://huggingface.co/Qwen/Qwen3-ASR-1.7B) and
[aligner](https://huggingface.co/Qwen/Qwen3-ForcedAligner-0.6B) as Apache-2.0,
and the [converted Whisper model](https://huggingface.co/Systran/faster-whisper-large-v3)
as MIT. Full revisions were resolved before preparation. Normal inference uses
local verified snapshots with `HF_HUB_OFFLINE=1`.

CUDA import and tensor probe passed: correct device, `torch.cuda.is_available()`
true and a 1024-element on-device sum returned 1024.0. This preceded real jobs.

## Issues discovered and verified fixes

1. Real Qwen recognition and alignment succeeded, but some Chinese character
   timestamps were points (`start == end`), causing `invalid_timestamp` during
   merge. Spec/design were updated before implementation. The regression failed
   first, then passed after preserving text in adjacent positive-duration groups
   using existing time boundaries. Entirely unanchored, reversed and out-of-range
   times still fail. Provenance records the policy.
2. Independent review reproduced identical boundary speech grouped differently
   across windows. A failing regression showed `boundary_alignment_conflict`.
   The real long sample also produced different words at shared boundaries. The
   spec now resolves complete temporal alternatives by source-window context,
   preserving original text/times and recording conflict counts. A review found
   early dedup could erase a shared word; its failing regression led to keeping
   all alternatives until ownership selection, including touching competition
   groups with different tokenization. Re-review found no remaining
   Important/Critical issues. Boundary quality remains empirically unverified.
3. Actual faster-whisper decoding failed because PyAV 19 removed
   `metadata_errors`. The real decoder regression failed first on target. GPU
   dependencies now constrain `av<19`, the lock resolves 18.1.0, and real decoding
   passes. See the [PyAV 19 changelog](https://pyav.basswood.io/docs/stable/development/changelog.html)
   and [faster-whisper 1.2.1 decoder](https://raw.githubusercontent.com/SYSTRAN/faster-whisper/v1.2.1/faster_whisper/audio.py).

## Verification boundaries

The 45-second input is the same previously authorized fixture as the phone
comparison, SHA-256
`83440d4ccbd82dafd1a88346ab448e1dd309e408c598d665413b910cc92c40a7`.
The long input repeats that PCM and truncates it at 600 seconds. A separate paused
case splits the original into contiguous 22- and 23-second files. Silence is four
seconds of zero PCM. The long case tests bounded processing, not representative
meeting quality or speech omission accuracy.

Target CPU/dependency suite after both fixes: **55 passed, 3 skipped**. The three
Docker integration tests skip because Docker is absent on target; their prior
container evidence remains separate. Host server suite: **54 passed, 4 skipped**
(the additional skip is optional GPU dependency decoding). Server Ruff check and
format check passed. An initial lint invocation from the repository root also
included unrelated pre-existing third-party/tool style errors; the scoped server
lint is the relevant clean gate, and those files were not changed.

All GPU jobs use batch one and separate recognition/alignment child processes.
Metrics report cold job wall time and maximum stage RSS. Torch allocator VRAM
excludes driver/desktop and does not measure CTranslate2 allocations. The external
one-second sampler records whole-device usage including unrelated Windows apps;
it may miss shorter peaks. Neither metric is represented as exact isolated
per-job device memory.

The target retains raw result JSON, stage diagnostics, monitoring samples and
reproduction scripts in the private project's `evidence/` directory. No audio
or credentials are copied into the repository evidence. Machine-readable result
summaries and exact source/result hashes accompany the final verification update.

## Final GPU evidence and status

OpenSpec is now **42/44** verified complete. Tasks 4.3, 4.4, 4.6 and 8.4 are
checked on this evidence; only 8.5 (reference quality corpus) and 8.6 (phone full
chain) remain. No production accuracy/default-model claim is made.

| Final input | Backend | Cold job seconds | Output segments | Boundary conflicts |
| --- | --- | ---: | ---: | ---: |
| 45 s baseline fixture | Qwen + aligner | 31.06 | 221 | 0 |
| 45 s baseline fixture | Whisper large-v3 | 13.90 | 131 | 0 |
| 4 s zero PCM | Qwen + aligner | 19.44 | 0 | 0 |
| 22 s + 23 s contiguous files | Qwen + aligner | 30.96 | 226 | 0 |
| 600 s repeated fixture | Qwen + aligner | 133.58 | 2986 | 12 |

The 600 s input yielded 21 chunks of at most 30 s in the retained reproduction.
Final one-second monitoring recorded 227 samples, a whole-device peak of
**8393 MiB including desktop/other applications**, and at most one simultaneous
stage child. Recognition and alignment were observed separately. The maximum
Qwen-stage Torch allocator peak was 4,698,449,408 bytes; maximum stage RSS was
approximately 5.22 GB. These scopes differ and must not be added or substituted
for each other. Multi-hour real meetings and warm-resident model timing were not
measured. Twelve boundary conflicts select one original model hypothesis each;
a reference is still required to judge which words are correct.

The final report checks that each result belongs to its latest successful job,
uses the final `complete-context-alternatives-v2` policy and passes the result
schema. Target source hashes match the current workspace. Both services are
active, and authenticated `/health/ready` plus `/health/live` returned 200.

Machine-readable evidence: [target report](remote-server-transcription-target.json)
and [target CPU/dependency tests](remote-server-transcription-target-tests.txt).
The earlier failed runs and their diagnostics remain recorded on target; the
retained diagnostic PCM work directory was removed after preserving JSON.
