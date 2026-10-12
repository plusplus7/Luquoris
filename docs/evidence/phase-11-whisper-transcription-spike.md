# Phase 11 offline Whisper transcription spike evidence

**Evidence date:** 2026-10-12

**Implementation base:** `e8da984590a49cba1847435c0c7681636d90dfa7`

**Release-footprint revalidation:** `2b8cf015ac6f251e78fe783eb629ddf084a4f8d2`

**Target device:** Xiaomi/Redmi `M2104K10AC` (`chopin`), Android 13 / API 33

**Decision:** OpenSpec Tasks 11.1–11.4 are implemented. Near-real-time remains experimental; Tasks 11.5–11.8 and 12.8 remain open.

## Scope and claim boundary

This phase establishes the replaceable offline engine, reviewed multilingual base-q5 model, durable post-session workflow, and bounded live-draft experiment. It does not establish production accuracy or near-real-time eligibility.

The physical-device smoke used the single authorized 45-second `zh-en-mixed-v1` fixture, which contains Mandarin, English, and code switching. It is not the held-out 30-minute-per-language evaluation corpus. No CER, WER, MER, p95 latency, sustained RTF, continuously sampled peak PSS, controlled energy, Flutter frame timing, or long-run claim is made. Separate microphone-recorded Chinese, English, and mixed meetings were not produced because no separately authorized controlled samples or human speaker were available; this missing matrix remains part of Task 11.5.

## Implemented surface

| OpenSpec task | Evidence-backed implementation |
|---|---|
| 11.1 | `whisper.cpp` 1.9.4 is pinned and built for arm64 CPU/NEON behind the versioned Dart `TranscriptionEngine`, Android channel controller, JNI adapter, and isolated inference executors. Release privacy checks find no network permission. |
| 11.2 | `whisper-base-q5_1` is imported through the fail-closed model workflow at exactly 59,707,625 bytes and SHA-256 `422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898`. Runtime materialization verifies the same values before native loading. |
| 11.3 | Finalized meetings are idempotently queued into durable processing jobs and versioned transcript runs. The native path inventories authoritative audio, decodes AAC to 16 kHz mono PCM, normalizes timestamps, reports progress, supports cooperative cancellation, resumes/recomputes after process loss, persists structured failures, and retains parallel transcript versions. |
| 11.4 | The live experiment uses the lower-priority bounded PCM branch, one in-flight sliding-window decode, stable/unstable reconciliation, backlog/degradation events, owner epochs, thermal fallback, and a mandatory complete post-session pass. Drafts are read-only and explicitly experimental. |

Implementation commits, in order:

1. `90e7088` — pinned native runtime and reviewed model
2. `560eb76` — native post-session runtime
3. `7bb86d4` — versioned engine channel
4. `e5ccbf5` — resumable durable jobs
5. `e808e63` — automatic finalization coordinator
6. `a648f19` — durable status and results UI
7. `f268bc5` — bounded live draft runtime
8. `e8da984` — experimental live draft UI

## Physical-device smoke

The focused runner `tool/run_whisper_transcription_device_test.sh` rebuilt and installed the exact debug APK and Android-test APK, passed the locally calculated APK SHA-256 into instrumentation, and re-hashed the installed base APK from the app process before inference. The raw machine-readable result is `docs/evidence/phase-11-whisper-transcription-device.json`.

| Measurement | Observed result | Interpretation |
|---|---:|---|
| Installed debug APK SHA-256 | `811bb7764dd5547f0136f5cfd5097920f39938d5d8a4694b17dd94f61a9adf3f` | Exact installed artifact verified by the instrumented process |
| Model materialization | 340 ms | Existing/cold-state details are not separated; integrity verification still ran |
| Live first visible text | 10,934 ms | One run; misses the balanced ≤5 s gate, falls within the power-saving ≤12 s point threshold, but is not p95 evidence |
| Live draft output | 1 unstable update, 0 native failures | Confirms real device event emission; does not establish sustained quality |
| Post-session decode | 15,618 ms for 45,000 ms audio | Single-run RTF 0.347; timestamp order and visible output passed |
| Thread CPU time | 21,674 ms | Test-thread checkpoint only |
| PSS checkpoints | 45,233 / 288,922 / 47,611 KiB | Before / after live / after post-session; 288,922 KiB is not a continuously sampled peak |
| Thermal and battery | status 0→0; 30.7→30.9 °C | Short smoke only |
| Energy | Android energy counter unavailable | Returned the platform unsupported sentinel; the charge counter moved while connected, so no energy claim is valid |
| Native lifetime | 0 contexts, 0 runs, 0 results after completion | No leaked native handles |

The companion production fan-out isolation test deliberately blocked the inference consumer while publishing 250 paced frames. Canonical processing accepted all 250 frames with byte-identical PCM and zero rejections; 249 inference frames were dropped, publish p95 was 2,045 µs, maximum was 2,415 µs, and shutdown took 1 ms. This proves the bounded branch can sacrifice inference work without back-pressuring the canonical memory sink. It is synthetic PCM and does not replace AudioRecord/AAC or long-duration evidence.

The existing native smoke suite also passed on this device: the authorized WAV produced visible monotonic segments, the invalid-model path returned a stable failure, and both cases released every native handle. Together with the earlier real Dart-to-Android cancellation round trip, these checks cover the physical channel/JNI boundary without treating draft text as authoritative output.

## Release, privacy, and provenance gates

`tool/measure_release_footprint.sh` rebuilt the release artifacts with the bundled model and arm64 native libraries, verified AAB native-symbol metadata, signed a measurement-only APK, performed a clean install on the target device, and updated `phase-10-release-footprint.json`.

| Artifact | Bytes | SHA-256 | Limit |
|---|---:|---|---:|
| Release APK | 85,326,201 | `db4713f84b5732773c2ea7514066231768e54b0f54602e305c88a0fd12d7ec98` | 524,288,000 |
| Release AAB | 81,192,415 | `a53b3f2c95cb9a9834998a3940aeb52e357b33dbfcd64719a1c1aedd8bb80ef5` | 524,288,000 |
| Clean installed measurement | 85,476,864 | tied to the APK hash above | 838,860,800 |

The original immediate post-install query returned a stale 132,608-byte
`StorageStats.appBytes` value and has been invalidated. The revalidated workflow
uses the exact installed APK byte length as a lower bound, waits for Android's
package storage accounting to include that APK, and independently rejects an
underreported result in the host adapter. The clean measurement reported
85,476,864 installed bytes for the exact 85,326,201-byte APK. The policy
decision is `passed` with no violations.

The structured source/dependency/manifest policy and final APK scan passed with no `INTERNET` or `ACCESS_NETWORK_STATE` permission. Model import re-verified one 59,707,625-byte artifact. The third-party notice workflow inventoried and rechecked 115 reviewed components; `THIRD_PARTY_NOTICES.md` was byte-identical after regeneration.

## Verification record

| Gate | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test tool` | Passed; 225 files, 0 changes after formatting two inherited test files |
| `flutter analyze --fatal-infos --fatal-warnings` | Passed; no issues |
| Full `flutter test` | Passed; 528/528 |
| Android `testDebugUnitTest` | Passed; 306/306 across 76 XML suites |
| Focused model import tests | Passed; 21/21 |
| Focused third-party notice tests | Passed; 12/12 |
| Device evidence instrumentation | Passed; 1/1 in 27.631 s |
| Native smoke + stalled-inference isolation | Passed; 3/3 in 25.372 s |
| Release APK merged policy and permission scan | Passed; no network permission |
| Release footprint policy | Passed; no violations |
| Reviewed third-party notice check | Passed; 115 components |

## Deferred gates and recommendation

Tasks 11.5–11.8 remain incomplete. Required follow-up includes held-out Chinese CER, English WER, and mixed MER; repeated first-text/RTF distributions; continuously sampled peak PSS, energy, thermal, backlog, and Flutter frame timing; controlled separate-language microphone recordings through both modes; restart/retry/playback checks on those recordings; the `small q5` comparison; four-hour stability; normalized scoring scripts; and an evidence-based model/mode recommendation.

Task 12.8 also remains incomplete. The current product must keep near-real-time visibly experimental and non-default. Post-session processing is the only model mode recorded in the reviewed manifest; recording-only and post-session fallback remain available whenever live inference is delayed, incomplete, thermally blocked, or fails.
