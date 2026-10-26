# Loquiris

Loquiris is a recording-first Android meeting recorder with optional self-hosted remote transcription. Its first invariant is simple: optional transcription or speaker analysis must never endanger the original local recording.

The project is currently implementing the OpenSpec change [`bootstrap-loquiris-offline-recorder`](openspec/changes/bootstrap-loquiris-offline-recorder/). Unverified AI capabilities are experimental and are not product promises.

## Project principles

- Remote transcription uploads only user-selected meetings to a configured server (HTTPS, or HTTP to a private LAN IP); no analytics, accounts, remote configuration or hidden model downloads.
- Release network permissions support explicit remote transcription. Recording works without a server or local ASR weights.
- Original audio stays in application-private storage; remote processing and exports are explicit user choices.
- Recorder reliability and recovery are gated independently from derived AI features.
- Compatibility claims are scoped to the exact devices and builds that produced recorded evidence.

See [Architecture](docs/architecture/README.md), [Privacy](PRIVACY.md), [Contributing](CONTRIBUTING.md), and [Security](SECURITY.md).

## Status

The repository is pre-alpha. OpenSpec artifacts define the required behavior and acceptance criteria. Do not use it for irreplaceable recordings until the Recorder MVP validation report is published.

## License

Loquiris source code is licensed under Apache-2.0. Model weights and third-party assets retain their own licenses and must pass the policy in [MODEL_ACCEPTANCE.md](MODEL_ACCEPTANCE.md) before release.

## Remote transcription

Implementation is tracked by [`remote-server-transcription`](openspec/changes/remote-server-transcription/). See [server deployment and WSL2 setup](server/README.md). Target GPU is an RTX 3080 Ti 12GB, with Qwen3-ASR-1.7B evaluated first and faster-whisper large-v3 as a comparison. Model quality and hardware acceptance remain evidence-gated.
