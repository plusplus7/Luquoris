# Contributing

Loquiris uses OpenSpec as the source of truth. Changes that alter behavior, privacy, persistence, recording safety, model selection, or release claims require an OpenSpec change before implementation.

## Development contract

1. Read the active proposal, design, relevant capability spec, and task.
2. Use test-driven development for behavior: add a test, observe the expected failure, add the minimum implementation, then run the targeted and full suites.
3. Keep recording correctness independent from optional AI work.
4. Do not add network permissions, telemetry, ads, remote configuration, accounts, cloud inference, or runtime model downloads.
5. Do not commit model weights without an accepted model manifest and license review.
6. Update `THIRD_PARTY_NOTICES.md`, tests, documentation, and evidence with dependency/model changes.

Generated code and declarative configuration are reviewed through deterministic generation and validation rather than artificial unit tests.

## Pull requests

Pull requests must state the OpenSpec task IDs, red/green test evidence, verification commands, privacy/license impact, unverified assumptions, and target-device evidence where relevant. Never label experimental AI as production-ready without the signed gate report.
