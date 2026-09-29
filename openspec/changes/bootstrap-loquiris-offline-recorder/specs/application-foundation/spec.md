## ADDED Requirements

### Requirement: Layered application architecture
The application SHALL organize Flutter code by feature, SHALL use Riverpod for feature state, GoRouter for application navigation, Drift for structured persistence, and typed results for expected boundary failures. Flutter presentation code MUST depend on abstract services rather than concrete recording or inference engines.

#### Scenario: Replace a native engine in tests
- **WHEN** a widget or view-model test supplies a fake transcription engine
- **THEN** the feature SHALL run without loading native model code or changing presentation logic

### Requirement: Explicit native service boundaries
The application SHALL define injectable boundaries for audio capture, transcription, speaker diarization, language identification, model management, thermal/performance monitoring, session persistence, and export.

#### Scenario: Native capability is unavailable
- **WHEN** a platform implementation reports an unsupported capability
- **THEN** the boundary SHALL return a structured failure and the UI SHALL remain usable without interpreting platform exception strings

### Requirement: Localized accessible design system
The application SHALL provide Loquiris-specific Material 3 tokens, simplified Chinese and English resources, semantic labels, non-color state indicators, TalkBack-compatible controls, system text scaling, and touch targets of at least 48 dp for critical actions.

#### Scenario: Stop recording with TalkBack
- **WHEN** a TalkBack user focuses and activates the stop control
- **THEN** the control SHALL announce its purpose and state and SHALL present an accessible confirmation before stopping

### Requirement: Adaptive safe layout
The primary acceptance layout SHALL target portrait phones, while all screens MUST adapt by available constraints and MUST NOT overflow or crash in landscape, large-text, tablet, or foldable window sizes.

#### Scenario: Large text on a narrow screen
- **WHEN** the system font scale is increased on a narrow recording screen
- **THEN** the timer, recording state, pause, stop, and bookmark controls SHALL remain visible and operable without clipped semantics

### Requirement: Offline continuous integration gates
CI SHALL run formatting, strict static analysis, Flutter unit/widget tests, Android JVM tests, build checks, model-manifest validation, third-party notice validation, and release privacy scans. Long-running model and physical-device tests SHALL be represented as manual signed release evidence.

#### Scenario: Release manifest gains network permission
- **WHEN** a release build merges `INTERNET` or `ACCESS_NETWORK_STATE`
- **THEN** the release privacy gate SHALL fail
