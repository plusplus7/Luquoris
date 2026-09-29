# Phase Evidence: Flutter and Android Foundation

## Scope

- OpenSpec change: `bootstrap-loquiris-offline-recorder`
- Task IDs: 2.1–2.8
- Commit/build identifier: repository has no initial commit; Flutter build `0.1.0+1`
- Date and operator: 2026-09-28, Codex

## Completed

- Created a single-package Flutter application with production identity `com.loquiris`, Android API 29 minimum, compile/target API 36, Java 17, and NDK 28.2.
- Added the feature-first directory foundation, strict analysis, Riverpod, GoRouter, Drift, localization, deterministic code generation, and pinned dependency lockfile.
- Added hand-written typed results, boundary-specific sealed failures, eight injectable service interfaces, throwing providers, and hand-written fakes with success, failure, and live-stream behavior.
- Added the ordered bootstrap sequence, two top-level error handlers, Riverpod exception unwrapping, root lifecycle flush/refresh coordination, and an app-private structured diagnostic sink whose schema accepts no user-authored strings.
- Added release manifest hardening, structured XML policy validation, a strict resolved-dependency allowlist, source/native dependency scans, and final APK permission inspection.
- Replaced the generated counter with a minimal Loquiris offline shell. Design-system and navigation behavior remain phase 3 work.

## Verification

| Command or procedure | Environment | Result | Evidence path |
|---|---|---|---|
| `dart format --output=none --set-exit-if-changed .` | Flutter 3.44.0 / Dart 3.12.0, macOS | Passed; 17 files, 0 changes | Command output in implementation session |
| `flutter analyze --fatal-infos` | Pinned Flutter toolchain | Passed; 0 issues | Command output in implementation session |
| `flutter test --test-randomize-ordering-seed=random --reporter=expanded` | Flutter host test runner | Passed; seed `609970990`, 22 tests | `test/` |
| Structure and import-boundary skill scripts | macOS workspace | Both passed | `lib/` |
| `dart run build_runner build --delete-conflicting-outputs` | build_runner 2.15.1 | Passed; 0 generated outputs; tool reports the legacy option is ignored | `build.yaml` |
| `flutter build apk --debug` | Temurin 17.0.20.1, Android SDK 36.1 | Passed | `build/app/outputs/flutter-apk/app-debug.apk` |
| `flutter build apk --release` | Temurin 17.0.20.1, Android SDK 36.1 | Passed; 49.5 MB | `build/app/outputs/flutter-apk/app-release.apk` |
| `bash tool/check_release_privacy.sh build/app/outputs/flutter-apk/app-release.apk` | Android `aapt2` 36.1.0 | Passed; no `INTERNET` or `ACCESS_NETWORK_STATE` in release APK | `tool/check_release_privacy.sh` |
| Direct `aapt2 dump badging` inspection | Release APK | Only app-scoped dynamic-receiver permission present; package `com.loquiris` | Release APK |
| `openspec validate bootstrap-loquiris-offline-recorder --strict` | OpenSpec CLI | Passed | Active OpenSpec change |

## Unverified assumptions

- No microphone capture, foreground service, database schema, recovery flow, transcription engine, language model, or diarization model is implemented or claimed by this phase.
- The minimal shell has not been visually validated on a physical device; phase 3 owns the design system, localization, routing, accessibility, and layout evidence.
- Diagnostic retention limits of seven days or 10 MiB remain task 14.4. This phase proves only local structured writes and a schema that cannot accept exception messages or user-authored content.
- The resolved dependency allowlist proves dependency drift is reviewed; it does not replace the later license/provenance audit or dynamic on-device traffic inspection.
- Android backup attributes are disabled in the merged manifest, but task 9.8 retains the full Android-version-specific backup/uninstall verification.
- No performance, battery, thermal, four-hour stability, or target-device compatibility claim has been made.

## Risks

- R-19 is partially mitigated by a typed diagnostic schema and tests; retention and full diagnostic-package scanning remain open.
- R-20 is partially mitigated by release permission, resolved dependency, source, Gradle, and APK gates; later native/model license and runtime audits remain open.
- R-01 through R-17 and R-21 through R-25 remain open because this phase does not implement or physically validate those behaviors.

## Recommendation

- Proceed to phase 3 design-system and navigation shell work.
- Keep every AI capability disabled and experimental until its later model, license, and target-device gates pass.
- Do not begin production recorder implementation before the phase 5 native audio spike closes the five-second recoverability and back-pressure gates.
