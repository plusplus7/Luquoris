## ADDED Requirements

### Requirement: Scoped target-device evidence
The initial physical-device release gate SHALL use the connected mainland-China Redmi Note 10 Pro identified as `M2104K10AC`/`chopin`, in its observed 6GB+128GB-class configuration. Every evidence record SHALL include exact model identifier, device codename, RAM, SoC/platform, Android API, OEM system and MIUI build, security patch, storage, battery health, ambient temperature, and test configuration. Claims MUST be scoped to that configuration.

#### Scenario: Target device passes all gates
- **WHEN** the selected SKU and firmware complete the release suite
- **THEN** documentation MAY state that this exact configuration passed and MUST NOT generalize the result to all low-cost Android devices

### Requirement: Repeated four-hour recorder evidence
Recorder release evidence SHALL include at least three four-hour recording-only runs and one four-hour stress flow containing pause/resume, lock/background operation, audio-focus or call interruption, low-power and low-storage handling, and abnormal process recovery.

#### Scenario: One run loses a committed segment
- **WHEN** any required run reports an unexplained audio gap, corrupt committed segment, or loss beyond five seconds after simulated failure
- **THEN** the recorder stability gate SHALL fail

### Requirement: Repeated real-time evidence
If near-real-time transcription is proposed for release, evidence SHALL include at least two four-hour near-real-time runs on the target configuration. If these are not complete or do not pass, the capability SHALL remain disabled or experimental.

#### Scenario: Only short benchmark passes
- **WHEN** a model passes a short RTF test but lacks the required four-hour runs
- **THEN** it SHALL not be described as four-hour-stable near-real-time transcription

### Requirement: Reproducible acoustic matrix
Evaluation SHALL include fixed authorized Chinese, English, and mixed-language material; two-to-six-speaker meetings; ordinary meeting-room distance; quiet and fan/air-conditioner noise; and light overlap. Fixed speaker position, phone position, volume, and room conditions SHALL be recorded, and direct digital input SHALL be evaluated separately.

#### Scenario: Compare model and acoustic failures
- **WHEN** room playback accuracy is worse than direct-input accuracy
- **THEN** the report SHALL retain both results rather than attributing the complete difference to the model or microphone alone

### Requirement: Accuracy evaluation discipline
Quality evaluation SHALL use at least 30 minutes each of held-out, human-verified Chinese, English, and mixed-language audio with documented normalization. It SHALL report Chinese CER, English WER, mixed MER/token error rate, raw and normalized results, and committed evaluation scripts.

#### Scenario: Formatting changes the score
- **WHEN** punctuation, case, or equivalent number formatting affects an output
- **THEN** the report SHALL show raw and normalized metrics without deleting lexical recognition errors

### Requirement: Performance and experience metrics
Each AI run SHALL record first-text latency, sustained RTF, CPU, peak RSS/PSS memory, thermal state and temperature when available, energy use per hour, backlog, failures, and Flutter frame timing. Balanced live mode SHALL target at most 12% battery per hour, recording-only at most 5% per hour, critical-control feedback within 500 ms, and severe-jank frame ratio below 1%.

#### Scenario: Recording succeeds but UI is blocked
- **WHEN** pause or stop feedback exceeds 500 ms because inference blocks the Flutter isolate
- **THEN** the AI configuration SHALL fail the user-experience gate even if its transcript accuracy passes

### Requirement: Controlled environment and default-state regression
Formal performance gates SHALL run at 22–26°C, off charger, with memory extension disabled and unrelated background work removed. A separate regression SHALL cover the device's ordinary factory-default memory configuration and OEM battery policy.

#### Scenario: Optimized setup passes but default setup fails
- **WHEN** the controlled configuration passes and the factory-default regression terminates recording
- **THEN** the release report SHALL disclose the failure and the product SHALL provide honest OEM-settings guidance rather than claiming unconditional reliability

### Requirement: Separate release labels
Release evidence SHALL independently declare `Recorder MVP`, `Offline Transcription Preview`, language identification, and speaker diarization status. A failed or absent AI gate MUST NOT be represented as a recorder failure and MUST NOT be hidden by a higher-performance comparison device.

#### Scenario: Recorder passes and transcription fails
- **WHEN** all recording gates pass but no model passes AI gates
- **THEN** the release MAY carry the Recorder MVP label while transcription remains disabled or explicitly experimental
