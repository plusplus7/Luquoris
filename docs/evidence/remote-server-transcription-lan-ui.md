# Capture UI and private LAN HTTP acceptance — 2026-10-22

The user's added requirement replaces the earlier phone-facing HTTPS prerequisite
for this trusted private LAN deployment. It does not claim recognition accuracy
improvement or full phone end-to-end acceptance.

## Resulting interaction

- Settings owns the default server connection and storage/privacy entry. A saved
  connection is shown directly; replacing it expands one form. No meeting or job
  is created by saving. Only already opted-in, unconfigured work can be bound.
- New recording offers remote transcription or recording only. Language is
  automatic; irrelevant language, speaker-count and local model controls are hidden.
- Remote recording keeps pause/resume, bookmark and stop. Duplicate highlight and
  local live draft controls are hidden.
- Details keep playback, bookmarks, remote task/result and historical content.
  Recording diagnostics are collapsed. Active runs expose cancellation without a
  duplicate start; terminal runs have no ineffective cancel control. The newest
  result is expanded, Save appears for changed text, and export formats share one
  menu. Text/JSON corrections and original timestamped subtitle semantics remain.

## Transport and deployment

Both Dart and Kotlin use the shared `contracts/remote_transcription/v1/endpoints.tsv`
vectors. HTTP requires canonical RFC1918 IPv4 or exact `127.0.0.1`; public HTTP,
URL credentials (including empty user-info), encoded/non-ASCII input, query,
fragment, non-root path and invalid ports are rejected. Uppercase schemes agree.
Native HTTP keeps bearer authentication, response limits and disabled redirects.
HTTPS retains normal certificate and hostname checks. HTTP transmits tokens and
audio without transport encryption; the UI/privacy text says to use a trusted LAN.

The target endpoint is `http://192.168.1.20:18000`. Windows portproxy binds only
that LAN address and forwards to `127.0.0.1:18000`, using the existing WSL localhost
forwarder. Firewall rule `Loquiris LAN Transcription 18000` allows TCP 18000 only
on the Private profile from LocalSubnet, with edge traversal blocked. WSL API
remains loopback-only. Other services and WSL networking mode were not changed.
The existing native services remain running and are not enabled at boot.

Actual LAN smoke: unauthenticated capabilities returned 401; authenticated
readiness returned 200. Upload resume/repeated chunk and a real Qwen GPU job
succeeded: 45 seconds input, 221 segments, 33.906 seconds job wall time. Result
identity/timeline were checked. See the adjacent `lan-smoke.json` for immutable
model revisions, input/result digests and metrics. This is a transport/inference
test, not an accuracy comparison.

## Fresh verification

- `flutter test`: 923 passed. Final formatting/const-only test cleanup was followed
  by the two targeted settings/export widget tests, both passed.
- `flutter analyze`: no issues.
- Gradle `:app:testDebugUnitTest :app:compileDebugAndroidTestKotlin`: passed;
  JUnit XML totals 561 tests, including shared endpoint and HTTP redirect checks.
- Gradle `:app:assembleDebug :app:assembleDebugAndroidTest`: passed.
- Physical Redmi instrumentation: 9 tests passed in `com.loquiris.remote`, covering
  real SQLite/Drift fixtures, task recovery, Keystore destination binding,
  persistent default connection and native authenticated HTTP/platform cleartext.
- Source privacy gate passed. Fresh release merged manifest generation and its
  structured policy validation passed; backup isolation remains enforced.
- Independent read-only review found no Important/Critical issues, including a
  follow-up review of URL normalization fixes. OpenSpec strict and diff whitespace
  checks passed.

The Flutter CLI referenced a missing configured JDK. The build succeeded by
invoking Gradle directly with Android Studio's installed JBR; no global Flutter
setting was changed. An initial full test run lacked Dart on PATH and retained one
obsolete HTTPS-only manifest expectation. After correcting the test environment
and requirement expectation, the complete suite passed.

## Physical app and remaining scope

`com.loquiris.debug` was installed beside `com.loquiris`; no production app or data
was uninstalled/cleared. The old test package has a different signature, so a
temporary Gradle init script assigned `com.loquiris.debug.lantest`; the separate
test package installed through the device's normal USB installation prompt.
No repository build-ID default or device security setting was changed.

Settings and new-recording pages were visually checked on the actual phone.
The real LAN connection was entered through the password form, saved, and shown
again after force-stop/relaunch. Credentials were not printed or added to files
in this checkout. Tokens remain Keystore-encrypted under noBackup; descriptors
return only origin/reference. Settings/export widget tests also check collapsed
replacement fields, dirty-only saving and one functional export menu.

APK hash/package/size are in `remote-server-transcription-lan-ui.json`. The APK is
`build/app/outputs/apk/debug/app-debug.apk`. Local screenshots were inspected at
`/tmp/loquiris-lan-capture.png` and `/tmp/loquiris-lan-saved-settings.png`; they are
not committed as user-device screenshots.

The original 8.5 accuracy corpus and 8.6 full phone capture/background/result-edit/
export sequence remain unchecked. Native loopback HTTP and an independent LAN GPU
job do not replace the full phone sequence. The change is 48/50 verified tasks.

## Scope

GitNexus full mixed-workspace detection reports CRITICAL: 394 changed symbols,
109 tracked files and 21 affected flows, including pre-existing unrelated edits.
This was reported before finishing; no commit/reset/stash was performed. Known UI
impacts before edits were LOW; new remote symbols are not indexed and return
UNKNOWN, so shared contracts, targeted tests, real-device checks and review supply
their evidence. A baseline-relative hash inventory is saved alongside this record;
it identifies this LAN/UI iteration separately from the earlier implementation.
