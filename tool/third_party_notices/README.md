# Third-party notice workflow

The notice workflow is fail-closed:

1. Inventory exact Dart, Android, native, model, and benchmark-media inputs from lock files and manifests.
2. Resolve immutable version, source, license identifier/text, redistribution obligations, and artifact hash.
3. Generate a candidate notice report in deterministic name/version order.
4. Compare the candidate with `THIRD_PARTY_NOTICES.md` in CI.
5. Require human approval for every new or changed entry before a release build.

The collector is offline and fail-closed. It reads:

- `pubspec.lock` plus Pub's generated `.dart_tool/package_graph.json`, so
  direct and transitive runtime packages are included while dev-only closures
  are excluded;
- the generated Android `releaseRuntimeClasspath` artifact inventory;
- each committed `models/manifests/*.json` independently from its runtime;
- the fixed benchmark-audio manifest and license snapshot.

Generate the Android inventory and an unreviewed candidate with:

```sh
JAVA_HOME=<jdk-17> android/gradlew -p android :app:writeReleaseDependencyInventory
dart run tool/generate_third_party_notices.dart \
  --candidate build/third_party_notices/candidate.json
```

Candidate mode writes deterministic `.json` and `.md` files and succeeds even
when review is outstanding. It never guesses a license or treats an engine's
license as authorization for model weights.

After a human verifies every exact component, artifact hash, license text, and
redistribution obligation, record the approvals in `approved_components.json`
and immutable text snapshots under `licenses/`. Then publish or verify the
reviewed notice with:

```sh
dart run tool/generate_third_party_notices.dart --output THIRD_PARTY_NOTICES.md
dart run tool/generate_third_party_notices.dart --check THIRD_PARTY_NOTICES.md
```

Both reviewed modes reject missing entries, stale entries, changed artifact
hashes, changed license text hashes, unsafe snapshot paths, and byte-level
notice drift. The initial approval catalog is intentionally empty; generating a
candidate does not authorize redistribution or make the reviewed gate pass.
