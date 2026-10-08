# Phase 10 model and supply-chain evidence

## Outcome

Phase 10 release-footprint and third-party-notice gates passed on 2026-10-09
(Asia/Singapore). OpenSpec tasks 10.8 and 10.9 are complete for the current
Android release inputs.

The canonical machine-readable footprint report is
`docs/evidence/phase-10-release-footprint.json` with SHA-256
`ddf5ea956a887dbf21baaaf13e4e103ca9c80f326a6e19d9d351487d5264506a`.

## Toolchain and target

- Flutter 3.44.0, framework revision `559ffa3f75`, engine revision
  `4c525dac5e`.
- Dart 3.12.0.
- Gradle 9.1.0 with launcher JVM Temurin 17.0.20.1.
- Target device serial `j75tmvsovouchmlj`, model `M2104K10AC`, device
  `chopin`, Android 13.
- Device build fingerprint
  `Redmi/chopin/chopin:13/TP1A.220624.014/V14.0.8.0.TKPCNXM:user/release-keys`.

## Release-footprint gate

The final clean-install workflow ran `tool/measure_release_footprint.sh`. It
removed any existing target and helper packages, rebuilt the release APK and
AAB, signed the otherwise unsigned APK with a one-day measurement-only local
certificate, installed that exact APK, queried Android `StorageStatsManager`,
and passed the exact-byte gate.

Build ID:
`49a92acadb76a37703d0eb935d1ebda2cff1d6a7-4018bab79568`.

| Input | Exact bytes | Limit | SHA-256 |
| --- | ---: | ---: | --- |
| Universal release APK | 64,665,928 | 524,288,000 | `4018bab79568c324674cc2637128605f56abaf9d18039ff47fd6c6dedb0c3e09` |
| Release AAB | 62,171,745 | 524,288,000 | `2b36747882da8fa5f31af88dd79768ab335fa772753c2e550569424f0379963c` |

The clean installed measurement was observed at
`2026-10-08T16:18:53.403058Z`:

- `appBytes`: 177,664;
- `dataBytes`: 0;
- `cacheBytes`: 0, reported as evidence and not subtracted;
- gated `installedBytes` (`appBytes + dataBytes`): 177,664;
- installed limit: 838,860,800 bytes;
- decision: `passed`, with no violations.

The temporary measurement helper and its test package were removed after the
query. The measured `com.loquiris` package remains installed.

## Third-party notice gate

Human approver `+7` explicitly approved the exact 113-component candidate on
2026-10-09. The pre-approval candidate SHA-256 is
`47635847d5f70d7b91a55e35cf235e19a41ca1823c28dcad93bc640f3f810681`.

The reviewed inventory contains:

- 47 Android release-runtime artifacts;
- 65 Dart runtime-closure packages;
- 1 fixed benchmark-media asset;
- 0 model manifests or weights, because none are currently shipped.

The approved license distribution is 44 Apache-2.0, 56 BSD-3-Clause, 7 MIT,
5 Flutter-engine composite bundles, and 1 CC0-1.0 entry. Thirty-two distinct
byte-exact license snapshots are committed under
`tool/third_party_notices/licenses/`.

- Approval catalog SHA-256:
  `0596c1c914edbd10d28ea850280b289a2bc53c7222cd1b9e60ceef952ab3cb93`.
- `THIRD_PARTY_NOTICES.md` SHA-256:
  `4ec1b9a535699ef57f5860ecd69b235a445fb3ef20d9fe2251a9c51b1c26c955`.
- Deterministic notice size: 7,024,891 bytes.
- `dart run tool/generate_third_party_notices.dart --check
  THIRD_PARTY_NOTICES.md`: `third_party_notices.check_passed components=113`.

The Flutter engine entries use the complete generated `sky_engine/LICENSE`
bundle rather than inheriting the framework's BSD license. The benchmark audio
retains its independent CC0 text and rights attestation. Any future model
manifest must supply and obtain approval for its own weight license; a runtime
license cannot authorize model redistribution.

## Verification

- Release APK/AAB build and clean-install measurement: passed.
- Independent AAB inspection found both `libflutter.so` and `libapp.so` symbol
  metadata after Flutter's symbol-stripping post-check returned nonzero.
- Android `:app:writeReleaseDependencyInventory`: passed for
  `releaseRuntimeClasspath`.
- Focused notice tests: 11 passed.
- Release privacy policy tests: 6 passed.
- Full Flutter suite: 453 passed.
- `dart format --output=none --set-exit-if-changed lib test tool`: 205 files,
  zero changes.
- `flutter analyze --fatal-infos --fatal-warnings`: no issues.
- Strict OpenSpec validation: change `bootstrap-loquiris-offline-recorder` is
  valid.
- Manual hardcode detection over the approval catalog, license snapshots, and
  generated notice: clean. This closes the two-second pre-commit scan timeout
  observed while committing the 7 MB notice corpus.

## Scope and remaining assumptions

- Installed-byte evidence is one clean measurement on the selected Redmi
  device. OEM accounting varies, so it is not a prediction for every device;
  the gate must be rerun for changed release artifacts and shipping targets.
- The APK certificate is measurement-only and proves artifact identity during
  the clean-install test. It is not production signing evidence.
- Flutter currently emits Android Gradle Plugin/Kotlin migration warnings. They
  did not fail this gate, but the project must migrate before the deprecated
  integration is removed.
- Strict OpenSpec validation emitted an environment warning that Node TLS
  verification was disabled. Local schema validation passed, but CI should run
  without that environment override.
- No model weight is currently shipped. Adding one reopens the model-license,
  footprint, and device-performance gates.
