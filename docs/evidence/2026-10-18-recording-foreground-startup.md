# Recording foreground-startup repair — 2026-10-18

## Outcome and boundary

Source-level startup hardening is implemented and locally verified. The physical phone still runs its original APK: no installation, uninstall, clear-data operation, or microphone capture was performed on it during this repair.

The confirmed phone failure was `ForegroundServiceDidNotStartInTimeException`. Its precise blocking call was not established. The old installed APK starts successfully in an empty API-34 emulator; that does not reproduce the phone's Android-13 vendor/persistent-state conditions.

## Changed behavior

- `onCreate` no longer loads or recovers persisted recording state.
- A valid, permitted, unowned start posts a transient non-persisted preparing foreground notification before state load, recovery commit, storage preflight, or start commit.
- Failed promotion never enters preparation. Preparation exceptions remain separate from promotion failure.
- Rejected unowned starts remove only the transient foreground notification; active recording ownership still prevents demotion/stopping.
- Rejection receipt construction and persistence run on a dedicated serial worker, so a rejected request cannot block a newer queued request's foreground promotion. Service teardown drains accepted receipt tasks; abrupt process death retains best-effort receipt behavior.

Android permits `stopSelfResult(startId)` to return false when a newer start exists, including one not yet delivered to the callback. Calling it before synchronous receipt I/O was therefore insufficient. See the [Service contract](https://developer.android.com/reference/android/app/Service#stopSelfResult(int)) and [foreground startup timeout guidance](https://developer.android.com/develop/background-work/services/fgs/troubleshooting).

## Verification

Evidence directory: `build/recording-start-crash-fix-1X8ZkU/`.

| Check | Directly inspected result |
| --- | --- |
| Preparation-first mutation | 4 ordering/preparation test failures, then GREEN with promotion first |
| Synchronous rejected-receipt mutation | 2 dispatcher test failures, then GREEN with worker dispatch |
| Full native suite | 550 tests; 0 failures; 0 errors |
| Android lint | 0 errors; 20 warnings; Gradle exit 0 |
| Flutter | 880 tests passed |
| Flutter analysis | No issues in `lib test integration_test test_driver` |
| Final API-34 service instrumentation | 4 tests passed in 19.971 seconds |
| Ordinary main-entry UI | Start → pause → resume → stop-and-save; meeting details show a 20-second recording; service list empty afterward |
| Emulator crash buffer | Empty after the ordinary flow |
| `git diff --check` | Exit 0 |

Primary logs: `promotion-order-red.log`, `rejection-dispatch-red.log`, `rejection-dispatch-green.log`, `emulator-service-final-test.log`, `flutter-final.log`, `analyze-final.log`. Full native counts were read from JUnit XML rather than inferred from Gradle's exit status.

Tests ran only on this task's read-only `emulator-5580`, with audio input/output disabled. Its destructive instrumentation fixture was never run on the physical device. The emulator has been stopped. No real audio quality or transcription claim follows from synthetic emulator capture.

## Artifact identity — local verification only

Normal `lib/main.dart` entry; `LOQUIRIS_STREAMING_NATIVE_SPIKE=false`.

- Debug app: `build/app/outputs/apk/debug/app-debug.apk`
- Package: `com.loquiris.debug`; version `0.1.0+1`; debuggable; not a production replacement.
- APK SHA-256: `284b2ec658e9d153bdf562596846e511b561e663af6b6acce09be5d5c4d33ac4`
- Debug certificate SHA-256: `6a50cd66bb35154165a622fe3116673dac2c072eec743aeb123228c558993bfa`
- Test APK SHA-256: `518e521b79721a48469040e0188942741ad9b277a63388094df11bd3906028fa`
- Manifest inspected: recorder service not exported, microphone foreground type, backup disabled, cleartext disabled. Debug includes INTERNET and non-exported probe services; this is not evidence of a release permission/privacy gate.

Installed production package `com.loquiris` uses certificate SHA-256 `86025ec572ad5073b2481883cafd7e7cd3c0222bd3e5321666a79167960e6bd6`. Its original measurement signing private key is unavailable. Its private release data cannot be read through `run-as`; no complete checked backup exists. Installing a different certificate cannot update it in place. No release build, signing-key creation, publication, or physical installation was attempted here.

## Review, rulings and deferred minor

A fresh-context read-only review found no Critical issue, one Important rejected-receipt race (fixed with RED→GREEN and full green suite), and one Minor. The final fix was verified by tests, not a second review.

Deferred minor: the recoverable-rejection instrumentation test uses a fixed command ID and does not reset receipt preferences. On reruns its receipt wait may observe an earlier result; snapshot and notification assertions still run, but receipt-based synchronization is weaker. Use a fresh UUID and an initially-absent receipt in a follow-up.

Decisions and costs:

1. Preserve the dirty current checkout on `fix/recording-foreground-startup-20261018`, rather than losing untracked implementation dependencies in a clean worktree. Less isolation; scoped source review is required.
2. No commit, staging, merge, push, workspace deletion, or unrelated cleanup. User retains the work and must choose integration later.
3. Dedicated serial rejection receipts drain on close, without unconditional `stopSelf()` or microphone promotion for denied requests. Failure feedback can still be lost on process death; it is not a new durable queue.
4. Emulator-only destructive fixtures. No phone data touched; emulator validation is not vendor-device validation.
5. Precise phone blocking call remains unknown; source hardening is not a claim that the installed APK or physical symptom is fixed.
6. Reviewer did not independently rerun tests; results here come from the implementer's actual logs and inspected outputs.
7. Cumulative streaming/inference/queue/finalization edits are preserved but excluded from this narrow review. No whole-worktree readiness claim.
8. Post-promotion main-thread storage responsiveness is unchanged; slow storage can still delay later work.
9. Recovery/finalization/audio integrity are not separately audited; the new rejection test checks snapshots, not real recorded-media contents.
10. Privacy/resource/performance qualification and transcription accuracy remain outside this repair's evidence.
11. Local ordinary-entry debug artifact only; no release or safe same-signature install is available until the original signing key or a separately approved, checked export/migration path is available. Do not uninstall the original app merely to install this repair.

Full execution ledger retained at `.superpowers/sdd/2026-10-18-recording-foreground-startup/progress.md`.
