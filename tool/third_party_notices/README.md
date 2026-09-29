# Third-party notice workflow

The notice workflow is fail-closed:

1. Inventory exact Dart, Android, native, model, and benchmark-media inputs from lock files and manifests.
2. Resolve immutable version, source, license identifier/text, redistribution obligations, and artifact hash.
3. Generate a candidate notice report in deterministic name/version order.
4. Compare the candidate with `THIRD_PARTY_NOTICES.md` in CI.
5. Require human approval for every new or changed entry before a release build.

The initial repository intentionally has no approved production dependencies or models. The executable generator and drift check are implemented with the model-supply-chain tasks after dependency manifests exist; they must never infer that a runtime's license automatically covers model weights.
