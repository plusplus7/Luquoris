## ADDED Requirements

### Requirement: Replaceable offline transcription engine
Transcription SHALL run through an injectable engine interface with no UI dependency on a concrete runtime. A production engine and all required weights MUST operate without network access.

#### Scenario: Select a different compliant engine
- **WHEN** an alternative engine implementation is configured
- **THEN** recording, session persistence, progress, editing, and export SHALL continue through the same domain contract

### Requirement: User-selected processing mode
Before recording, the user SHALL be able to select near-real-time draft or post-session transcription and the application SHALL remember the default. During recording, the application MAY degrade from real-time to post-session but MUST NOT silently change modes.

#### Scenario: Thermal protection pauses live inference
- **WHEN** the device reaches the configured severe thermal state
- **THEN** live inference SHALL pause, recording SHALL continue, and the user SHALL be told that post-session processing remains available

### Requirement: Incremental immutable draft
Near-real-time mode SHALL display timestamped incremental draft segments and backlog state. Draft text MUST NOT be directly editable during active recording, while bookmarks and highlights SHALL remain available.

#### Scenario: Partial hypothesis changes
- **WHEN** the engine revises an unstable partial hypothesis
- **THEN** the draft view MAY replace the unstable text without modifying any human-authored revision

### Requirement: Versioned post-session analysis
Every transcription run SHALL persist engine version, model hash, parameters, progress, timing, output segments, and structured failure. Re-analysis SHALL create a new version and SHALL require explicit selection before becoming current.

#### Scenario: A second model completes
- **WHEN** a user runs a higher-quality model on an existing meeting
- **THEN** both transcript versions SHALL remain identifiable and the user SHALL choose which version is current

### Requirement: Timestamped editable output
Stable transcript segments SHALL contain stable IDs within their version, start/end media times, displayed text, raw model text, revision state, language reference, and optional speaker reference.

#### Scenario: Correct a stable transcript segment
- **WHEN** the user edits finalized text
- **THEN** the application SHALL preserve the original model output and SHALL store the correction as a revision

### Requirement: Measurable preview eligibility
Near-real-time balanced mode SHALL require first-segment p95 latency of at most five seconds and sustained RTF at most 0.8. Power-saving draft mode SHALL require first text within 12 seconds and RTF at most 1.2. Post-session balanced and high-quality modes SHALL require RTF at most 1.0 and 2.0 respectively on the target evidence configuration.

#### Scenario: Engine misses the real-time gate
- **WHEN** a model exceeds the latency, RTF, stability, energy, thermal, or accuracy gate
- **THEN** it SHALL NOT be enabled as a default near-real-time capability and recording/post-session alternatives SHALL remain available

### Requirement: No automatic linguistic rewriting
Transcription MAY apply deterministic punctuation and number formatting but MUST preserve original languages, MUST NOT translate, MUST NOT automatically convert simplified/traditional Chinese, and MUST retain raw output separately.

#### Scenario: Mixed-language utterance
- **WHEN** a segment contains Chinese and English words
- **THEN** the stable transcript SHALL preserve both languages rather than translating one into the other
