# Phase 10 Supply-Chain Gates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete OpenSpec tasks 10.8 and 10.9 with reproducible release-size measurements, fail-closed footprint gates, deterministic third-party notice generation, explicit human approval, and phase evidence.

**Architecture:** Keep release policy in pure Dart tools with deterministic JSON/Markdown outputs. Measure APK and AAB from actual release artifacts, accept installed-byte evidence only from the existing Android `StorageStatsManager` boundary on a clean target-device install, and compare every measurement against fixed binary-byte limits. Generate notice candidates from resolved Dart and Android inventories, benchmark-media metadata, and model manifests, then require exact-version approval metadata and immutable license snapshots before the reviewed notice file can match.

**Tech Stack:** Dart 3, Flutter, Android Gradle/Kotlin DSL, `StorageStatsManager`, JSON, SHA-256, `flutter_test`, Android Debug Bridge, GitNexus, OpenSpec.

**Spec:** `openspec/changes/bootstrap-loquiris-offline-recorder/design.md` and `openspec/changes/bootstrap-loquiris-offline-recorder/specs/model-performance-management/spec.md`

## Global Constraints

- The maximum release artifact size is `500 * 1024 * 1024` bytes (500 MiB); the maximum clean installed footprint is `800 * 1024 * 1024` bytes (800 MiB).
- Measurements must name the exact artifact, build identifier, target ABI/variant, byte count, and SHA-256; estimates cannot satisfy a release gate.
- Installed footprint is `appBytes + dataBytes` from Android `StorageStatsManager` after a clean install and before user meetings are stored; `cacheBytes` is reported separately and must not be subtracted from the raw evidence.
- No target device means installed-size status is `unverified`, never a fabricated pass; OpenSpec 10.8 remains unchecked until the target-device measurement exists.
- Notice generation is fail-closed: every shipped Dart, Android, native, model, and benchmark-media component must resolve to one exact reviewed entry and immutable license snapshot.
- Development/test-only dependencies are inventory evidence but must be labeled non-shipping and must not be represented as release payload.
- A runtime license never implies that model weights share that license.
- Generated notice candidates do not become approved notices until a human verifies exact versions, texts, redistribution obligations, and attribution.
- No network permission, runtime download, telemetry, or remote license lookup may be added.
- Preserve the existing dirty worktree; stage and commit only files owned by each task.

## Review Focus

- An APK/AAB at exactly the limit must pass, while one byte over must fail without MiB rounding.
- A small compressed artifact with an installed footprint above 800 MiB must fail production selection.
- Missing, stale, duplicated, non-regular, or mislabeled artifacts must fail rather than disappear from the report.
- Transitive release dependencies and model/benchmark licenses must be detected even when no direct `pubspec.yaml` entry names them.
- Notice text or approval drift with unchanged component names must fail through immutable version and license-text hashes.

---

### Task 1: Pure release-footprint policy and CLI

**Files:**
- Create: `tool/release_size/release_footprint_policy.dart`
- Create: `tool/check_release_footprint.dart`
- Create: `test/tool/release_footprint_policy_test.dart`
- Create: `test/tool/check_release_footprint_cli_test.dart`

**Interfaces:**
- Produces: `maxReleaseArtifactBytes = 524288000` and `maxInstalledFootprintBytes = 838860800`.
- Produces: immutable `ReleaseArtifactMeasurement`, `InstalledFootprintMeasurement`, `ReleaseFootprintReport`, `ReleaseFootprintViolation`, and `ReleaseFootprintDecision` values.
- Produces: `evaluateReleaseFootprint(ReleaseFootprintReport)` with no filesystem or process access.
- Produces: `Future<int> runReleaseFootprintCommand(List<String> arguments, {required Directory projectRoot, required void Function(String) writeOutput, required void Function(String) writeError})` that reads real artifact lengths/hashes and a device-measurement JSON file, emits canonical JSON, and returns `0` only for a complete passing report.
- Consumes later: Task 2 supplies real `apk`, `aab`, and installed measurement inputs.

- [ ] **Step 1: Write failing policy tests**

Add tests named:

- `exact binary limits pass and one byte over fails`;
- `installed footprint is app plus data and cache remains evidence only`;
- `every required artifact variant must be present exactly once`;
- `unverified installed measurement cannot pass production selection`;
- `canonical report ordering and equality are deterministic`.

- [ ] **Step 2: Run the policy tests and verify RED**

Run:

```bash
env PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin flutter test test/tool/release_footprint_policy_test.dart
```

Expected: FAIL because the policy file and types do not exist.

- [ ] **Step 3: Implement the pure policy**

Use exact byte comparisons. Require one AAB and at least one explicitly labeled APK measurement; preserve ABI/variant labels and hashes in deterministic order. A missing installed measurement returns a typed incomplete decision, not a pass.

- [ ] **Step 4: Run the policy tests and verify GREEN**

Expected: all Task 1 policy tests pass.

- [ ] **Step 5: Write failing CLI tests**

Add tests named:

- `CLI measures regular artifacts and writes canonical privacy-safe JSON`;
- `CLI rejects missing symlink duplicate and changed artifact inputs`;
- `CLI exits nonzero for artifact or installed budget failure`;
- `CLI never reports a pass without device measurement provenance`.

- [ ] **Step 6: Run CLI tests and verify RED**

Expected: FAIL because `runReleaseFootprintCommand` is unavailable.

- [ ] **Step 7: Implement the CLI**

The CLI accepts repeated `--apk <label>=<path>`, one `--aab <path>`, one `--installed-measurement <json>`, and `--output <json>`. It requires regular files beneath the project or explicit build-output root, verifies files do not change while hashing, records lowercase SHA-256, and prints only stable failure codes.

- [ ] **Step 8: Run Task 1 tests, format, analyze, and commit**

```bash
env PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin flutter test test/tool/release_footprint_policy_test.dart test/tool/check_release_footprint_cli_test.dart
env PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin dart format --output=none --set-exit-if-changed tool test/tool
env PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin flutter analyze --fatal-infos --fatal-warnings
```

Before editing every symbol, run required GitNexus upstream impact analysis. Before committing, stage only Task 1 files and run staged `gitnexus_detect_changes`.

Commit: `feat: add release footprint gate`

---

### Task 2: Real release artifacts and target-device installed measurement

**Files:**
- Modify: `android/settings.gradle.kts`
- Create: `android/footprint-measurer/build.gradle.kts`
- Create: `android/footprint-measurer/src/main/AndroidManifest.xml`
- Create: `android/footprint-measurer/src/androidTest/kotlin/com/loquiris/tools/footprint/ReleaseFootprintInstrumentedTest.kt`
- Create: `tool/measure_release_footprint.sh`
- Create: `docs/evidence/phase-10-release-footprint.json` only from a real complete run
- Test: `test/tool/release_footprint_policy_test.dart`

**Interfaces:**
- Consumes: Task 1's canonical installed-measurement JSON schema.
- Produces: a non-production, standalone Android instrumentation helper that receives a target package name, uses `StorageStatsManager.queryStatsForPackage` after the host grants `GET_USAGE_STATS`, and emits one machine-readable instrumentation-status value containing package ID, device serial/model/build fingerprint, `appBytes`, `dataBytes`, `cacheBytes`, and observed UTC time.
- Produces: a host script that builds release APK and AAB, hashes and measures them, installs the exact release APK under measurement, installs the isolated helper/test APKs, captures the package-specific `StorageStatsManager` result, and invokes Task 1's gate.
- Does not modify or add a measurement surface to the production application and does not include the helper in Loquiris release artifacts.

- [ ] **Step 1: Write the failing integration/host contract tests**

Pin rejection of malformed instrumentation values, mismatched package/build provenance, dirty-install evidence, missing device identity, and integer overflow. The test must prove that `appBytes + dataBytes` is the installed value sent to the gate.

- [ ] **Step 2: Run the focused tests and verify RED**

Run the host-testable parser/policy subset. Expected: FAIL because the measurement adapter does not exist.

- [ ] **Step 3: Implement the measurement adapter and host script**

Use Android's same `StorageStatsManager` authority from a standalone tooling APK, without changing the app or depending on `run-as`. The script must refuse zero/multiple devices, non-target packages, stale artifacts, a missing usage-stats grant, or pre-existing Loquiris app data. It must uninstall the exact target package before installation and verify the package/version afterward. It must not claim the AAB itself is an installed-footprint measurement.

- [ ] **Step 4: Build real release artifacts**

```bash
env PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin flutter build apk --release
env PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin flutter build appbundle --release
```

Expected: release APK and AAB exist as regular files and are measured by Task 1's CLI.

- [ ] **Step 5: Run the clean-install target-device measurement**

Use the selected `M2104K10AC`/`chopin` device. If it is not connected, stop here with 10.8 unchecked and report the exact missing evidence. Do not substitute the existing 191 MB debug APK or an emulator.

- [ ] **Step 6: Verify the complete gate and publish evidence**

Expected: canonical JSON records both release artifacts and the clean installed footprint, and exits zero only when all are within budget. A failure keeps all measured facts and rejects production selection.

- [ ] **Step 7: Commit Task 2 only after a real complete run**

Run focused tests, strict analysis, release privacy checks, and staged GitNexus change detection.

Commit: `build: gate release and installed footprints`

---

### Task 3: Deterministic dependency and model notice inventory

**Files:**
- Create: `tool/third_party_notices/third_party_notice_generator.dart`
- Create: `tool/generate_third_party_notices.dart`
- Create: `tool/third_party_notices/approved_components.json`
- Create: `tool/third_party_notices/licenses/` snapshots as approvals are completed
- Modify: `android/app/build.gradle.kts`
- Modify: `tool/third_party_notices/README.md`
- Create: `test/tool/third_party_notice_generator_test.dart`
- Create: `test/tool/third_party_notice_cli_test.dart`

**Interfaces:**
- Produces: a Gradle `writeReleaseDependencyInventory` task that writes sorted release-runtime component coordinates and artifact hashes under `build/` without resolving debug/androidTest-only configurations.
- Produces: `NoticeInventory.collect(...)` over `pubspec.lock`, the generated Android release inventory, `models/manifests/*.json`, and `assets/benchmarks/audio/manifest.json`.
- Produces: `NoticeApprovalCatalog` keyed by component kind/name/exact version and immutable license-text SHA-256.
- Produces: deterministic candidate Markdown and machine-readable JSON; missing/stale approvals are explicit failures.

- [ ] **Step 1: Write failing inventory tests**

Add tests named:

- `collects transitive Dart packages in stable exact-version order`;
- `collects only Android release runtime artifacts`;
- `collects model and benchmark licenses independently from runtimes`;
- `rejects missing duplicate mutable and unsafe license metadata`;
- `detects stale approvals and changed license text hashes`;
- `development-only dependencies cannot masquerade as shipped entries`.

- [ ] **Step 2: Run generator tests and verify RED**

Expected: FAIL because the generator is unavailable.

- [ ] **Step 3: Implement the Gradle inventory and pure generator**

The generator may read local resolved metadata but performs no network access. It must identify unresolved license information as unreviewed; it must not guess SPDX identifiers or inherit model licenses from engines.

- [ ] **Step 4: Write and run failing CLI/drift tests**

Pin canonical output, privacy-safe diagnostics, missing inputs, approval drift, notice drift, and unchanged-file behavior.

- [ ] **Step 5: Implement the CLI and drift check**

Support `--candidate`, `--check`, and `--output` modes. `--check` compares generated reviewed content byte-for-byte with `THIRD_PARTY_NOTICES.md` and fails when any inventory or approved text changes.

- [ ] **Step 6: Run Task 3 verification and commit**

Run focused tests, the release dependency inventory task, formatting, strict analysis, release privacy checks, and staged GitNexus detection.

Commit: `feat: generate fail-closed third-party notices`

---

### Task 4: Review current shipped components and publish notices

**Files:**
- Modify: `tool/third_party_notices/approved_components.json`
- Add/Modify: `tool/third_party_notices/licenses/*`
- Modify: `THIRD_PARTY_NOTICES.md`
- Test: `test/tool/third_party_notice_generator_test.dart`

**Interfaces:**
- Consumes: Task 3's complete unreviewed candidate inventory.
- Produces: exact approval entries and immutable license snapshots for every current release component, benchmark asset, and model manifest.

- [ ] **Step 1: Generate the current candidate and retain all unreviewed entries**

Do not suppress Flutter-engine, plugin, Android, benchmark, or transitive entries simply to make the gate green.

- [ ] **Step 2: Verify source, version, license, redistribution, attribution, and hash for every entry**

Record uncertain or incompatible entries as blockers. Human review is mandatory; agent-generated metadata alone cannot authorize release redistribution.

- [ ] **Step 3: Obtain explicit human approval for the exact candidate**

If approval is unavailable, stop with 10.9 unchecked and provide the candidate and blocker list. Do not mark the task complete.

- [ ] **Step 4: Publish approved snapshots and deterministic notices**

Copy only the explicitly approved catalog/snapshots into the repository, regenerate `THIRD_PARTY_NOTICES.md`, and verify `--check` passes byte-for-byte.

- [ ] **Step 5: Commit the approved inventory**

Run focused tests, privacy checks, strict analysis, staged GitNexus detection, and `git diff --check`.

Commit: `docs: approve phase 10 third-party notices`

---

### Task 5: Phase 10 evidence and OpenSpec completion

**Files:**
- Create: `docs/evidence/phase-10-model-supply-chain.md`
- Modify: `openspec/changes/bootstrap-loquiris-offline-recorder/tasks.md`

**Interfaces:**
- Consumes: real Task 2 measurement JSON and human-approved Task 4 notice inventory.
- Produces: complete Phase 10 evidence, or an explicitly partial report with 10.8/10.9 left unchecked.

- [ ] **Step 1: Write the phase evidence from actual command output**

Record exact build/tool versions, artifact hashes/bytes, installed measurement/device provenance, notice inventory counts, approval identity/date, tests, limitations, and remaining physical-device assumptions.

- [ ] **Step 2: Mark OpenSpec checkboxes only when their gates are complete**

Change 10.8 only after real artifact and installed measurements exist. Change 10.9 only after deterministic drift checks and explicit human approval succeed.

- [ ] **Step 3: Run final Phase 10 verification**

```bash
env PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin dart format --output=none --set-exit-if-changed lib test tool
env PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin flutter analyze --fatal-infos --fatal-warnings
env PATH=/Users/bytedance/.cache/loquiris-toolchains/flutter/bin:/usr/bin:/bin:/usr/sbin:/sbin flutter test
npx @fission-ai/openspec validate bootstrap-loquiris-offline-recorder --strict
```

Also run release APK/AAB builds, release privacy checks, the footprint gate, notice drift check, `git diff --check`, and staged GitNexus change detection.

- [ ] **Step 4: Commit Phase 10 evidence**

Commit: `docs: complete phase 10 supply-chain gates`
