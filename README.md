# Loquiris

Loquiris is an offline-first Android meeting recorder. Its first invariant is simple: optional transcription or speaker analysis must never endanger the original local recording.

The project is currently implementing the OpenSpec change [`bootstrap-loquiris-offline-recorder`](openspec/changes/bootstrap-loquiris-offline-recorder/). Unverified AI capabilities are experimental and are not product promises.

## Project principles

- No runtime cloud transcription, analytics, accounts, remote configuration, or hidden model downloads.
- Release builds do not request Android network permissions.
- Audio is stored in application-private storage until the user explicitly exports it.
- Recorder reliability and recovery are gated independently from derived AI features.
- Compatibility claims are scoped to the exact devices and builds that produced recorded evidence.

See [Architecture](docs/architecture/README.md), [Privacy](PRIVACY.md), [Contributing](CONTRIBUTING.md), and [Security](SECURITY.md).

## Status

The repository is pre-alpha. OpenSpec artifacts define the required behavior and acceptance criteria. Do not use it for irreplaceable recordings until the Recorder MVP validation report is published.

## License

Loquiris source code is licensed under Apache-2.0. Model weights and third-party assets retain their own licenses and must pass the policy in [MODEL_ACCEPTANCE.md](MODEL_ACCEPTANCE.md) before release.
