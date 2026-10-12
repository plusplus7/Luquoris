## ADDED Requirements

### Requirement: Durable meeting record
Each meeting SHALL store a stable identifier, title, creation time, media duration, the selected transcription mode, the selected language mode, optional expected speaker-count guidance, authoritative audio references, session events, processing state, structured failures, transcript versions, speaker and language labels, revisions, and model provenance.

#### Scenario: Start a meeting without a title
- **WHEN** recording begins without a user-entered title
- **THEN** the system SHALL immediately create a meeting named with a localized date/time default and SHALL allow later renaming

### Requirement: Dual timeline semantics
Transcript and playback offsets SHALL use media time with paused intervals removed, while session events SHALL preserve wall-clock timestamps and monotonic ordering.

#### Scenario: Export a meeting that was paused
- **WHEN** the user exports structured JSON for a paused meeting
- **THEN** transcript segments SHALL contain media offsets and pause events SHALL contain their real wall-clock times

### Requirement: Consistent local session detail
The session detail SHALL read the meeting, authoritative audio segments, session events, bookmarks and highlights, processing state, and structured recovery failures as one locally consistent projection. Playback controls SHALL use an injectable service boundary and SHALL NOT expose app-private absolute paths to Dart UI code.

#### Scenario: Open a finalized meeting with playable audio
- **WHEN** the current authoritative segment generation has a durably published ready playback artifact
- **THEN** the detail SHALL offer play, pause, and media-time seek controls backed only by that validated artifact
- **AND** selecting a bookmark, highlight, or search offset SHALL seek to its pause-free media timestamp

#### Scenario: Playback artifact is unavailable
- **WHEN** the playback artifact is missing, building, failed, stale, or quarantined
- **THEN** the detail SHALL keep segment, event, bookmark, processing, and failure information available
- **AND** playback SHALL remain disabled with a stable local explanation rather than consuming another artifact or raw private path

#### Scenario: Detail routes overlap during navigation
- **WHEN** a replacement detail route loads playback before the prior route is disposed
- **THEN** the prior route's release SHALL NOT stop or mutate the replacement player's session
- **AND** Flutter SHALL reject any playback snapshot whose meeting identity differs from the requested detail

#### Scenario: Large playback artifact opens or seeks
- **WHEN** Android resolves and prepares a long meeting or seeks to a media-time marker
- **THEN** hashing and preparation SHALL NOT block the platform UI thread
- **AND** a seek SHALL report success only after the native player confirms the resulting position

### Requirement: Recoverable abnormal sessions
On startup the application SHALL reconcile the database, segment manifests, and files. It SHALL present abnormal recordings for user review and SHALL never reopen the microphone automatically.

#### Scenario: Recover after process termination
- **WHEN** startup discovers committed segments for a meeting without a finalized state
- **THEN** the meeting SHALL be marked recoverable and the user SHALL be able to save it or start an explicit continuation segment

#### Scenario: Save recovered audio without continuing
- **WHEN** the user chooses to save a recoverable meeting
- **THEN** Loquiris SHALL finalize the recovered meeting without opening the microphone and SHALL retain every authoritative segment

#### Scenario: Explicitly continue a recovered meeting
- **WHEN** the user confirms continuation after reviewing a recoverable meeting
- **THEN** Loquiris SHALL preserve all published segment bytes, publish a new continuation segment, and only then reopen the microphone after permission and storage checks pass

#### Scenario: Recovery resolution fails
- **WHEN** saving or continuing cannot durably complete
- **THEN** the meeting SHALL remain recoverable and Loquiris SHALL show a retryable local failure without losing authoritative audio

### Requirement: Local bookmarks and highlights
The user SHALL be able to add bookmarks and manual highlights during recording independently of transcription availability, including from an allowed notification action.

#### Scenario: Add a highlight while draft transcription is disabled
- **WHEN** the user marks a highlight during recording-only mode
- **THEN** the highlight SHALL be durably stored at the current media time without requiring transcript text

### Requirement: Deterministic local search
The application SHALL provide on-device search across meeting titles and transcript text and within an individual meeting. Search results SHALL navigate to the corresponding meeting or media offset and MUST NOT require embeddings or a network service.

#### Scenario: Open a transcript search result
- **WHEN** the user selects a matching transcript segment
- **THEN** the session detail SHALL navigate to that segment and offer playback from its media timestamp

### Requirement: Non-destructive revision history
Text, language, and speaker corrections SHALL be stored as revisions and SHALL NOT be overwritten by re-analysis. The user MAY explicitly flatten revision history without deleting the current corrected content.

#### Scenario: Re-transcribe an edited meeting
- **WHEN** the user requests re-transcription after manually correcting text
- **THEN** the new machine output SHALL be a parallel version and the corrected version SHALL remain unchanged

### Requirement: Seven-day local trash
Deleting a meeting SHALL move it to local trash for seven days unless the user explicitly confirms permanent deletion. Storage pressure MUST NOT silently empty trash.

#### Scenario: Restore a trashed meeting
- **WHEN** the user restores a meeting before permanent deletion
- **THEN** its authoritative audio, current transcript, revisions, bookmarks, and metadata SHALL return to the normal session library with the durable lifecycle it had immediately before trashing
