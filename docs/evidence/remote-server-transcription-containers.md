# Container verification — continued 2026-10-22

At this earlier container checkpoint, OpenSpec `remote-server-transcription` was **38/44 verified complete**. The later [target GPU report](remote-server-transcription-target.md) records **42/44**. Task 8.1
is now verified; 4.3, 4.4, 4.6, 8.4, 8.5 and 8.6 remain unchecked.

## Fresh evidence

- Linux/amd64 API image built successfully:
  `sha256:714a703d3446614ff13bf89d9cb41c00edc6ccd1ec631299148dfbf9bd8df6fd`.
- Linux/amd64 GPU worker image built successfully:
  `sha256:40d77a098238c2ac35ce7eb03e1fa5a6114a1b91d9e4ce3e112e4d8dd7da378f`.
- Both image configurations use UID/GID `10001:10001`.
- Full host server suite with real container tests enabled: **48 passed**.
- CPU suite inside Linux/amd64 API container: **45 passed, 3 skipped**. The three
  Docker-bound tests were executed on the host with image selection enabled;
  they are not counted as verified merely because they skip in the container.
- Ruff check and format check passed.
- Caddy 2.10.0 accepted the actual Caddyfile. Both base Compose and optional
  build-CA override configurations validate.
- Independent read-only review found no Important issues in Dockerfile,
  build-CA override, integration tests and updated deployment instructions.

## Real container checks

1. API runs nonroot, acknowledges committed upload bytes, survives container
   restart over its own named volume, resumes the same upload identity, seals
   media, enforces ownership, keeps submission idempotent and cancels the job.
2. Actual Caddy reverse proxy serves HTTPS with a disposable localhost CA. The
   trusted client verifies the certificate and hostname; an untrusted client is
   rejected. API authentication is preserved through TLS termination. No phone
   trust settings or public DNS/ACME configuration were changed.
3. The real worker entrypoint starts from the lightweight API image against an
   empty read-only model volume. It claims the queued job, fails once with
   `model_unavailable`, keeps `qwen-1.7b`, publishes no result, and leaves the API
   live but not model-ready. This path fails before GPU imports and is explicitly
   **not** a GPU dependency/inference check.

Reproduction from `server/`:

```sh
docker build --platform linux/amd64 --target api -t loquiris-api:verify .
LOQUIRIS_TEST_API_IMAGE=loquiris-api:verify uv run --frozen pytest -q
```

For an administered TLS proxy add
`--secret id=build_ca,src=/path/to/approved-ca-bundle.pem`. The bundle is mounted
only during build; it is not copied into the runtime image and SSL verification
is not disabled. Optional Compose usage is documented in `server/README.md`.
The API runtime check confirmed the build certificate was absent and
`SSL_CERT_FILE` was unset.

GPU worker build:

```sh
docker build --platform linux/amd64 --target worker -t loquiris-worker:verify .
```

The first worker build failed when cuDNN download hit uv's default 30-second
network timeout. Build-only `UV_HTTP_TIMEOUT=300` and
`UV_CONCURRENT_DOWNLOADS=4` resolved that failure; dependency versions stayed
locked. The second build completed, including image export. Build logs record
PyTorch 2.6.0 and transformers 4.57.6; this is installation evidence, not runtime
or GPU execution evidence.

## Disk incident and bounded cleanup

First running the GPU image needed additional unpacking space. Approximately
8.7 GiB was free after image export; unpacking then exhausted the host filesystem
and caused Docker metadata I/O errors. The dependency-import probe never returned
and must not be treated as passing. The temporary worker image was removed, so
its build digest is retained above as evidence rather than as a retained image.

Only these task-created resources were cleaned:

- Unique `loquiris-worker-check-4ff14c47f2-*` test container/volumes.
- `loquiris-worker:verify` image.
- Exact private, reclaimable GPU build cache record
  `2924ub7ahhnl76y6f64dd63jc` (9.975 GB), matched to the `uv sync --extra gpu` step.
- Disposable server Python environment and the PyTorch download cache; the locked
  CPU test environment was recreated and the complete 48-test suite passed.

Docker was restarted without resetting its data. Existing stopped containers,
images and volumes were retained. No global prune, volume wipe or factory reset
was performed. Host free space recovered to approximately 10 GiB. All temporary
integration containers/volumes were removed after the final passing run.

For targeted cache selection semantics see the official
[Buildx prune reference](https://docs.docker.com/reference/cli/docker/buildx/prune/).
No further local GPU-image unpack/import attempt was made. Check storage for
build snapshots, compressed layers, runtime unpacking and weights before retrying
on the target machine; compressed image size alone is insufficient.

## Outstanding acceptance

There is still no connection to the Windows/WSL2 RTX 3080 Ti machine, and the user
confirmed it cannot currently be operated. No GPU model inference, peak device
memory measurement, reference-corpus quality comparison, real-phone background
lifecycle/TLS or recording-to-edit/export acceptance is claimed.

Small adjacent text files retain passing suite summaries and successful image
export logs. Full local logs remain under `/tmp/loquiris-remote-container-*` and
`/tmp/loquiris-remote-linux-tests.log`.
