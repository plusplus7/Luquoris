## ADDED Requirements

### Requirement: Bundled production models
Every production model required by an enabled capability SHALL be bundled in the installable release and MUST NOT be downloaded at runtime. Research models that fail provenance, license, quality, or performance review MUST NOT be included.

#### Scenario: Device is permanently offline
- **WHEN** the user installs a complete release and never grants network access
- **THEN** every advertised production inference capability SHALL have its required model bytes locally available

### Requirement: Model integrity and provenance
Each bundled model SHALL have an immutable manifest containing identifier, engine compatibility, source, version, byte size, cryptographic hash, license snapshot, and enabled modes. Integrity failure SHALL disable only dependent AI capabilities.

#### Scenario: Model hash is invalid
- **WHEN** validation finds a bundled model does not match its declared SHA-256
- **THEN** the application SHALL report a structured model failure, SHALL NOT load it, and SHALL preserve recording functionality

### Requirement: Open redistribution license
All distributed application code and model weights MUST have fixed terms permitting use, modification where applicable, commercial use, and redistribution. Project non-commercial intent MUST NOT be used to classify a non-commercial/source-available model as open source.

#### Scenario: Candidate weight has custom non-commercial terms
- **WHEN** license review finds that a candidate forbids commercial use or does not permit redistribution
- **THEN** the candidate SHALL remain outside production artifacts and third-party release manifests

### Requirement: First-run reproducible recommendation
The application SHALL offer a 30–60 second on-device performance check using bundled, redistributable fixed audio without activating the microphone. It SHALL recommend but MUST NOT automatically select a mode or model.

#### Scenario: Benchmark indicates weak performance
- **WHEN** the fixed benchmark fails the balanced-mode thresholds
- **THEN** the application SHALL recommend post-session, power-saving, or recording-only mode with an explanation and user override

### Requirement: Explicit operating modes
The application SHALL expose high-quality, balanced, power-saving, recording-only, and post-session modes where supported. Each automatic degradation SHALL be visible, explain its cause, and retain an actionable recovery path.

#### Scenario: Live inference cannot keep up
- **WHEN** sustained processing falls behind audio beyond its supported backlog
- **THEN** the application SHALL continue canonical recording and SHALL visibly switch or offer switching to post-session processing

### Requirement: Thermal and resource protection
At Android thermal status `MODERATE`, the application SHALL reduce AI concurrency; at `SEVERE`, it SHALL pause AI while continuing safe recording. Memory pressure, low battery policy, or engine failure SHALL follow the same recording-first priority.

#### Scenario: Device reaches severe thermal status
- **WHEN** the system reports severe thermal pressure during live transcription
- **THEN** inference SHALL pause, recording SHALL continue, and the user SHALL see the reason and pending post-session work

### Requirement: Size budgets and artifact variants
The selected production model set and application SHALL target a release artifact no larger than 500 MiB and an installed footprint no larger than 800 MiB. Releases SHALL provide an AAB, ABI-specific signed APKs, and an explicitly identified universal APK.

#### Scenario: Candidate models exceed installed budget
- **WHEN** a release measurement exceeds 800 MiB before user meetings are stored
- **THEN** the production model set SHALL fail the size gate and SHALL be reduced or redesigned before release
