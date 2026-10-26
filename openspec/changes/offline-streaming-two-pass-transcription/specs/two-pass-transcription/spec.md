## ADDED Requirements

### Requirement: Explicit two-pass meeting selection
The application SHALL allow the user to select streaming draft plus post-session refinement before recording and SHALL persist that choice with the meeting. Engine/model roles SHALL be independent; selecting a complete-pass model MUST NOT silently substitute it for the streaming engine. Recording-only and post-session-only alternatives SHALL remain available.

#### Scenario: User selects two-pass recognition
- **WHEN** a new meeting begins with two-pass processing selected
- **THEN** its qualified streaming engine SHALL provide live text and the configured complete-pass engine SHALL be scheduled after durable recording finalization

### Requirement: Complete authoritative audio input
Refinement SHALL read every committed audio segment from the finalized, ordered authoritative recording, including intervals absent from an incomplete live draft. It MUST NOT use recognized draft text or the surviving live PCM buffer as a substitute for original audio. Missing or corrupt segments SHALL produce a structured, visible failure rather than silently shortened output.

#### Scenario: Live draft degraded halfway through a meeting
- **WHEN** the recording finalizes after live recognition stopped early
- **THEN** refinement SHALL process the entire committed recording, not only the interval represented by the draft

### Requirement: Durable and idempotent refinement jobs
Refinement SHALL be scheduled only after finalized audio inventory is durably readable. Durable job identity SHALL include meeting/audio identity, processing role, engine/runtime version, model-bundle identity, decoding settings, and parameter schema. Duplicate notifications SHALL not create duplicate identical runs. Interrupted work SHALL recover or retry without deleting original audio or completed transcript versions.

#### Scenario: Process terminates between finalization and inference
- **WHEN** the application restarts with a queued or interrupted refinement job
- **THEN** it SHALL verify the original audio and exact model provenance, resume or recompute the pending complete pass, and preserve completed historical versions

### Requirement: Draft and refined versions remain separate
Live draft and refined output SHALL be distinguishable transcript versions with separate immutable raw output, timestamps, run provenance, completeness state, and processing role. Completion of refinement SHALL notify the user that a new version is ready and MUST NOT automatically replace the current version. Search, playback text, export, and backup SHALL consistently respect explicit current-version selection and retain historical versions according to the existing portability contract.

#### Scenario: Refined output completes while the draft is current
- **WHEN** refinement finishes successfully
- **THEN** the current transcript SHALL remain unchanged until the user explicitly selects the refined version, and both versions SHALL remain accessible

### Requirement: Human corrections and bookmarks survive refinement
Human corrections SHALL remain attached to the transcript version on which they were made and SHALL preserve original model text. Refinement or version selection MUST NOT overwrite, discard, or ambiguously auto-merge corrections. Bookmarks and highlights SHALL retain recording-media anchors across different model segmentations.

#### Scenario: User corrects a name before refinement completes
- **WHEN** the refined model emits different text and segment boundaries for the corrected interval
- **THEN** the existing correction SHALL remain available on its source version, the raw refined result SHALL be stored separately, and the user SHALL choose the preferred version without losing bookmarks

### Requirement: Capture-priority refinement resource policy
Complete-pass inference SHALL not run concurrently with active recording. A new recording SHALL defer queued refinement and pause or cancel active refinement at a safe boundary without delaying microphone startup or recorder controls. Thermal, battery, and memory protection SHALL produce visible job states and preserve an actionable resume/retry path.

#### Scenario: A new meeting starts during refinement
- **WHEN** the user starts recording while a previous meeting is being refined
- **THEN** the new recording SHALL take priority, refinement SHALL safely yield resources, and its durable pending state SHALL be retained for later continuation

### Requirement: Original-language faithful refinement
Refined transcription SHALL preserve Chinese and English lexical content in their original languages. Deterministic punctuation and numeric formatting SHALL retain separate raw model text. Translation, automatic simplified/traditional conversion, and generative semantic rewriting MUST NOT be applied as implicit correction.

#### Scenario: English term appears inside a Chinese sentence
- **WHEN** the complete-pass model recognizes a code-switched utterance
- **THEN** the output SHALL preserve the English term rather than translating it into Chinese or replacing the utterance with a generated paraphrase
