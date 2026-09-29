# Risk Register

This register is part of the proposal evidence. A risk is closed only by recorded evidence or an accepted product downgrade, not by implementation completion alone.

| ID | Risk | Consequence | Trigger / Evidence | Mitigation and Gate |
|---|---|---|---|---|
| R-01 | Active AAC container cannot survive abrupt termination | More than five seconds lost or entire current segment unreadable | Force-stop/truncation spike produces corrupt or missing committed audio | Select a recoverable commit/container strategy before recorder implementation; retain authoritative segment manifest and raw-segment export |
| R-02 | Encoder or file I/O starves microphone capture | Gaps in the only authoritative record | Input overrun, timestamp discontinuity, silent/corrupt segment | Dedicated priority path, bounded buffers, short commits, underrun telemetry, artificial-stall tests |
| R-03 | AI work back-pressures capture | Recording failure caused by optional inference | Recorder latency/gaps grow when inference queue stalls | One PCM source with independent bounded consumers; discard/defer AI work only; isolate inference execution |
| R-04 | MIUI/HyperOS OEM policy kills the foreground service | Long meeting silently terminates | Default-policy physical test ends service | Test the selected target on MIUI 14 default and unrestricted modes, treat HyperOS as unverified extension risk, persist continuously, provide honest system-setting guidance, and bind claims to the tested build |
| R-05 | Audio focus/call behavior differs by firmware | Unexpected audio gaps or privacy breach | Call/focus matrix produces auto-resume or call capture outside policy | Persist all interruptions, never record call audio, require post-call confirmation, test exact firmware |
| R-06 | Low storage corrupts current segment | Audio cannot finalize or database/file state diverges | Free-space fault injection near thresholds | Four-hour preflight plus safety reserve, active warning, atomic manifest updates, safe stop without auto-deletion |
| R-07 | Database and filesystem diverge after crash | Meeting is hidden, duplicated, or undeletable | Reconciliation finds orphan records/files | Manifest is audio authority; idempotent startup reconciliation; recovery fixtures and process-death tests |
| R-08 | Whisper is too slow/hot for near-real-time on the target phone | Core positioning cannot be claimed | RTF, latency, energy, or thermal gate fails | Release recorder/post-session mode; disable or clearly mark live preview; do not substitute flagship results |
| R-09 | Whisper accuracy is inadequate for Chinese or mixed speech | Transcript creates more work than value | CER/WER/MER gates fail on held-out data | Compare base/small within size and RTF budgets; keep raw audio primary; allow correction; withhold transcription label |
| R-10 | Community streaming model license/provenance is unclear | Project ceases to be fully open source or cannot redistribute releases | Missing fixed license, training provenance, or redistribution right | Keep model out of artifacts; document as research only; require manifest/license approval before integration |
| R-11 | Bundled model set exceeds 500/800 MiB budgets | Installation/update becomes impractical on low-cost devices | Measured package or installed footprint exceeds gate | Remove models that fail value gates, avoid duplicate extraction, retain all-model/no-download policy only for approved production set |
| R-12 | Native inference crashes or exhausts memory | Analysis lost; OS may kill recorder if isolation is wrong | PSS/LMK/native-crash stress test fails | Separate resumable job boundary/process, hard resource admission, recorder priority, structured recovery |
| R-13 | Thermal status pauses AI repeatedly | Draft falls far behind and battery drains | MODERATE/SEVERE events or sustained RTF >1 | Explicit degradation, reduced concurrency, post-session fallback, no automatic resume loop without hysteresis |
| R-14 | Diarization fails with six speakers, overlap, distance, or noise | Misleading labels and incorrect names | DER >25%, label drift, uncertain overlap | Keep post-session/experimental, show uncertainty, preserve corrections, never transfer names automatically |
| R-15 | Language confidence is not calibrated | Incorrect silent language switching | Accuracy <90% or raw scores differ across engines | Permit uncertain status, treat mode as hint, expose manual correction, display confidence only after calibration |
| R-16 | One-device evidence is overgeneralized | Users on other phones experience failures | Marketing/docs use broad “budget phone support” claim | Bind evidence to SKU/firmware/environment; maintain optional community matrix; forbid broader claim without data |
| R-17 | Four-hour tests are not reproducible | Passing result cannot be trusted or compared | Missing room/device/audio/environment metadata | Fixed authorized samples, controlled layout, scripted flows, raw metric export, signed evidence |
| R-18 | Unencrypted backup leaks sensitive meetings | External destination exposes content | User exports backup to shared/insecure storage | Explicit sensitive-data warning, user-selected destination, privacy-safe name, document lack of encryption |
| R-19 | Diagnostics leak transcript or identity | Privacy promise is violated | Log scan finds prohibited strings/content | Structured codes/metrics only, redaction tests, seven-day/10 MiB cap, local-only export |
| R-20 | Model/runtime dependency introduces network or telemetry | Offline guarantee is false | Manifest/dependency scan or runtime inspection detects capability | No network permissions, CI dependency denylist/audit, release merged-manifest check, manual provenance review |
| R-21 | Restore overwrites a local meeting | Irrecoverable user-data loss | Same ID with divergent content | Hash-based identical skip; conflicting content gets a new ID; never silent overwrite |
| R-22 | Automated cleanup removes user data | Permanent loss during storage pressure | Cleanup touches authoritative/trash files | Whitelist rebuildable cache classes only; fault tests; trash deletion always explicit |
| R-23 | Timeline drift accumulates across pauses/segments | Transcript, bookmark, and playback offsets disagree | Long-run offset exceeds one second | Monotonic clock authority, explicit segment offsets, deterministic pause mapping, four-hour validation |
| R-24 | Accessibility regressions make stop/pause unsafe | Users cannot control an active recording | TalkBack/large-text/target-size tests fail | Semantic controls, ≥48 dp targets, non-color indicators, critical widget and instrumented tests |
| R-25 | Scope expands into summaries, sync, or cross-meeting identity | Recorder reliability and privacy gates slip | Tasks/dependencies add cloud, LLM, or biometric identity work | Treat as explicit non-goals; require a separate future OpenSpec change |

## Top Pre-Implementation Gates

1. R-01 through R-03 require a passing native audio architecture spike before production capture code is accepted.
2. R-08 through R-10 require real target-device and license evidence before near-real-time is enabled.
3. R-11 requires release and installed-size measurement with every selected production model present.
4. R-14 requires six-speaker and overlap evidence before automatic speaker labels leave experimental status.
5. R-16 and R-17 constrain every public compatibility claim to the signed validation report.
