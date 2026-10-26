# Loquiris remote transcription server

This directory implements the server and its model worker; it does not require
Whisper weights on the phone. Initial target: one RTX 3080 Ti 12GB, 8 CPU cores,
32GB RAM. Native Windows/WSL2 CUDA execution has now been exercised on the target
3080 Ti; see `../docs/evidence/remote-server-transcription-target.md` for exact
inputs, runtime scope and outstanding quality/phone acceptance. CPU tests alone
do not establish GPU or accuracy results.

## Windows / WSL2 setup

1. Use WSL2 with a Linux distribution and a Windows NVIDIA driver supporting CUDA
   in WSL. Do not install a separate Linux display driver inside WSL. Check the
   [NVIDIA WSL guide](https://docs.nvidia.com/cuda/wsl-user-guide/index.html).
2. Enable the Docker Desktop WSL2 backend and GPU support. In the Linux shell run
   `nvidia-smi`, `docker compose version`, then
   `docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi`.
   Stop here if the container cannot see the 3080 Ti; model startup is not a driver
   repair tool. Linux hosts need the NVIDIA Container Toolkit instead.
3. Keep the checkout and Docker data in the Linux filesystem for file-lock/WAL
   behavior and I/O performance. Use the named volumes in compose; do not place
   SQLite on a Windows SMB share or a network filesystem.
4. Choose a phone-facing endpoint: HTTP on a trusted private LAN, or HTTPS with
   a trusted certificate. The phone accepts HTTP only to an explicit RFC1918 IPv4
   address or 127.0.0.1. HTTP exposes audio and bearer tokens to network observers;
   use HTTPS when the network is not trusted. Keep token authentication enabled.
5. For HTTPS, the supplied Caddy configuration expects a DNS name for which ACME
   can issue a trusted certificate. Self-signed IP certificates are not accepted
   by the phone's normal trust store. Certificate/hostname verification remains
   enabled.

### Current private LAN endpoint

The verified native WSL2 deployment uses `http://192.168.1.20:18000`. The WSL API
continues to listen on loopback port 18000. Windows forwards only its LAN address
to the existing WSL localhost forwarder; no WSL networking mode change is needed.
Run equivalent commands in an elevated Windows PowerShell only after substituting
the host's actual address and confirming the active network profile is Private:

```powershell
netsh interface portproxy add v4tov4 listenaddress=192.168.1.20 listenport=18000 connectaddress=127.0.0.1 connectport=18000
New-NetFirewallRule -DisplayName 'Loquiris LAN Transcription 18000' -Direction Inbound -Action Allow -Protocol TCP -LocalAddress 192.168.1.20 -LocalPort 18000 -RemoteAddress LocalSubnet -Profile Private -EdgeTraversalPolicy Block
```

The current target already has this rule; do not add duplicates. Do not expose
this HTTP port through a router or change the rule to Public/Any. A DHCP address
change requires updating the forwarding rule and phone settings. The native
`loquiris-remote-api` and `loquiris-remote-worker` services run in WSL; they are
not enabled at boot. Restart them manually after WSL shutdown. The compose/Caddy
path below is an alternative deployment, not a prerequisite for this native one.
Remove the named firewall rule and exact portproxy entry to close LAN access.

## Prepare and run

From `server/` in WSL/Linux:

```sh
cp .env.example .env
python3 -c 'import secrets; print(secrets.token_urlsafe(32))'
```

Put the generated token in `.env` and the phone configuration. Set
`LOQUIRIS_SERVER_HOST` to the actual DNS name. Use a separate token for each
principal. The file is ignored by git and is never included in a backup.

```sh
docker compose build
```

If an administered TLS proxy requires an organization CA, use an approved PEM
trust bundle as a build-only secret. This keeps verification enabled and does
not copy the bundle into the image or runtime service:

```sh
LOQUIRIS_BUILD_CA_FILE=/absolute/path/to/approved-ca-bundle.pem \
  docker compose -f compose.yaml -f compose.build-ca.yaml build
```

GPU wheel downloads use a 300-second HTTP timeout and four concurrent downloads
by default. These build-only values can be overridden for a slow connection:

```sh
docker compose build --build-arg UV_HTTP_TIMEOUT=600 \
  --build-arg UV_CONCURRENT_DOWNLOADS=2 worker
```

Ordinary public-CA connections use the base compose file. Do not disable TLS
verification or commit local certificate bundles. Package caches are excluded
from the resulting image by `uv --no-cache`.

Choose reviewed full commit SHAs from the upstream model repositories. Preparation
requires explicit immutable revisions, not `main`. This downloads weights only
when you run this command; ordinary worker inference is offline:

```sh
docker compose run --rm prepare --directory /models \
  --qwen-revision FULL_40_CHARACTER_COMMIT_SHA \
  --aligner-revision FULL_40_CHARACTER_COMMIT_SHA \
  --whisper-revision FULL_40_CHARACTER_COMMIT_SHA
```

The Whisper argument is optional. To advertise and run it, set
`LOQUIRIS_ENABLED_PROFILES=qwen-1.7b,whisper-large-v3` in `.env`. Qwen and the aligner are separate snapshots.
The command writes `profiles.json` only after downloads finish and hashes every
artifact. The worker verifies those hashes before use; changed bytes fail without
silently selecting a different model. Review model licenses before deployment:
[Qwen model card](https://huggingface.co/Qwen/Qwen3-ASR-1.7B) and
[faster-whisper](https://github.com/SYSTRAN/faster-whisper).

```sh
docker compose up -d api worker proxy
docker compose logs --tail 50 api worker proxy
```

Only the proxy exposes a host port. API and worker share a durable SQLite/file
volume; models are read-only to the worker. One GPU lock covers all stage
subprocesses. Qwen uses 16-bit weights, batch 1 and bounded overlapping windows;
alignment starts after recognition exits. CPU splitting uses a conservative RMS
silence heuristic (16 PCM units to skip a silent window, 100 at a cut boundary);
this is not a learned speech detector and requires noisy/quiet-speech evaluation. Resource exhaustion is a typed failure,
with at most three worker attempts; the selected profile remains unchanged.

On the phone open Settings and save the server origin and token once. Saving
settings does not create a meeting or a new transcription job. Select remote
transcription for a new recording, or explicitly start it for an existing meeting.
Recording can start without configuration; previously opted-in uploads wait for
settings and durable audio finalization. Connection changes do not redirect
already bound tasks or enable restored tasks. Language recognition is automatic;
local language/people controls and live local draft controls are hidden in this
mode. Active tasks expose cancellation, results keep editing and a single export
menu, and recording diagnostics are collapsed.
Phone output, local corrections and original audio survive server expiry.

`/health/live` checks API process liveness. Authenticated `/health/ready` requires
an unexpired worker heartbeat after model-manifest verification and an isolated
CUDA/dependency probe. It does not prove a real model forward pass fits in VRAM.
Readiness requires every enabled profile's weights; the default enables Qwen
only. Optional Whisper is advertised only after explicitly enabling its profile.
Validate the
GPU with `nvidia-smi` and perform one authorized fixture job before enabling
normal traffic. A queued or failed task alone is not proof of model readiness.

## CPU verification and evaluation

```sh
uv sync --frozen --python 3.12
uv run --frozen pytest
uv run --frozen ruff check .
uv run --frozen ruff format --check .
```

An opt-in test builds on a real Linux/amd64 API image and Docker volume. It
checks nonroot startup, interrupted upload followed by container restart,
idempotent resume/submission, ownership and cancellation. The listener binds only
to loopback and the test removes its own container, volume and temporary token:

```sh
docker build --platform linux/amd64 --target api -t loquiris-api:verify .
LOQUIRIS_TEST_API_IMAGE=loquiris-api:verify uv run --frozen \
  pytest tests/test_container_integration.py -q
```

In a proxy environment add `--secret id=build_ca,src=/path/to/approved-bundle.pem`
to the build command. The test is skipped during ordinary CPU-only pytest runs;
that skip must not be counted as container acceptance. A second test exercises
Caddy HTTPS using a disposable localhost CA, verifies that an untrusted client
fails, and checks authentication through the proxy. It changes no phone trust
settings and does not perform public ACME certificate issuance.

The third test starts the real worker entrypoint from the lightweight API image
with an empty read-only model volume. It confirms a missing model fails explicitly,
keeps the selected profile, publishes no result, and leaves the API available.
This guard executes before GPU imports, so CUDA packages and model downloads are
unnecessary for this check. It does not validate the GPU package/runtime.

On a host with sufficient storage, `LOQUIRIS_TEST_WORKER_IMAGE=loquiris-worker:verify`
can explicitly select the built GPU image for the same check. Check Docker's
storage filesystem before building or first running a GPU image: downloaded
layers, build snapshots, runtime unpacking and model caches all need space.
The local verification exhausted approximately 8.7 GiB of remaining space during
first GPU-image unpacking, even though the image build itself had succeeded.
Do not infer required disk capacity from compressed image size, and do not
prune unrelated images/volumes to make a test pass.

No model import/download is needed for these tests; ffmpeg and ffprobe are needed.
For native execution with a GPU, install the locked optional set using
`uv sync --frozen --extra gpu`. The lock pins PyTorch 2.6.0 and the Qwen wrapper;
The GPU optional set also constrains PyAV below 19 because faster-whisper 1.2.1
uses the removed `metadata_errors` argument. The opt-in dependency test exercises
real PCM decoding; run it in the GPU environment, where it must pass rather than
skip. Linux CUDA library availability must still be checked on each deployment.

Score a downloaded v1 result against a human reference:

```sh
uv run --frozen python -m loquiris_server.evaluate result.json \
  --reference reference.txt --output report.json
```

Run the same representative authorized Chinese, English, mixed, silence, noisy
and long-meeting set against Qwen, remote Whisper and the local baseline. Keep
raw outputs and model/runtime revisions. CER/WER do not replace manual review of
proper nouns, omitted sentences, duplicates or overlapping-speaker speech. The
report leaves unmeasured values null. It distinguishes `coldStartupSeconds` and
`warmInferenceSeconds` when a benchmark supplies them in provenance. The current
isolated worker measures cold job wall time and maximum stage RSS; it does not
claim warm model timings, full-device VRAM, or CTranslate2 allocator VRAM. Record cold startup separately from warmed
inference, actual wall-clock time, peak process memory and device GPU memory on
12GB hardware. Do not infer GPU capacity from parameter weight size.

## Recovery, retention and operations

Upload keys and job keys are persistent client identities. Transport retries do
not create another run. Files are acknowledged only after fsync and a ledger
commit. Restarting API/worker preserves offsets and recovers abandoned leases;
old attempts cannot publish results. The worker also reconciles files left by
crashes between result rename and DB commit.

Configure `LOQUIRIS_RETENTION_SECONDS` in `.env`; capabilities and actual
deadlines are displayed on the phone. Default retention is 24h from upload activity and 24h after a job becomes terminal.
Shared audio stays until all referring jobs expire. The worker runs cleanup;
keep it running even when no model job is active. The phone displays job state;
if a result expires before download, submit a new explicit run from local audio.
Cancellation is local first and remote cancellation retries use the same submission
key, including recovery of a lost POST response.

To revoke a client, remove/replace its token in `.env` then recreate API and worker:
`docker compose up -d --force-recreate api worker`. Existing phone credentials will
fail visibly. The worker never logs audio, transcript text or tokens; disable
proxy request logging if adding custom Caddy configuration. Standard TLS access
and driver logs still need normal administrator access controls.

For a consistent server backup stop API and worker, archive the complete `data`
volume (including SQLite sidecars and files), then restart. Protect that archive
because it contains audio/transcripts. Model snapshots can be backed up separately.
Never copy only the live SQLite main file. Restore to the same schema/runtime,
check SQLite integrity and run a fixture before accepting traffic.

To update, back up first, build the new images and restart. To roll back remote
processing, stop the services and use phone recording-only mode. Do not downgrade
or delete the phone database or original recordings. Never use `docker compose
down -v` as a routine update command: it destroys persisted server data.

Linux/amd64 API and GPU worker image builds have passed. The API, trusted test
TLS proxy, durable upload restart and missing-weight worker path are covered by
container tests. Actual GPU-image dependency import could not finish locally
because runtime unpacking exhausted disk; the temporary GPU image/build snapshot
were removed. That earlier local limitation has since been superseded by native target-WSL2
CUDA/model runs; see the target evidence report. GPU execution through Docker,
Private LAN HTTP has passed an authenticated real model task; see
`../docs/evidence/remote-server-transcription-lan-smoke.json`. Phone end-to-end
capture/background/result acceptance remains a separate scope.

## Android integration checks

Before building instrumentation tests, export the actual current Drift database:

```sh
dart run tool/export_remote_test_database.dart
JAVA_HOME=<Android-Studio-JDK> android/gradlew -p android \
  :app:testDebugUnitTest :app:assembleDebug :app:assembleDebugAndroidTest
adb -s <test-device> install -r build/app/outputs/apk/debug/app-debug.apk
adb -s <test-device> install -r build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb -s <test-device> shell am instrument -w -e package com.loquiris.remote \
  com.loquiris.debug.test/androidx.test.runner.AndroidJUnitRunner
```

The fixture is generated under `build/` and included only in the instrumentation
APK. These tests exercise the real bundled SQLite driver, Keystore, shared wire
fixtures, and durable repository against an injected HTTP boundary. They do not
replace the physical-phone TLS/background/server acceptance checklist.
