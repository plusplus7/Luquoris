## ADDED Requirements

### Requirement: Durable meeting record
Each meeting SHALL store a stable identifier, title, creation time, media duration, authoritative audio references, session events, processing state, structured failures, transcript versions, speaker and language labels, revisions, and model provenance.

#### Scenario: Start a meeting without a title
- **WHEN** recording begins without a user-entered title
- **THEN** the system SHALL immediately create a meeting named with a localized date/time default and SHALL allow later renaming

### Requirement: Dual timeline semantics
Transcript and playback offsets SHALL use media time with paused intervals removed, while session events SHALL preserve wall-clock timestamps and monotonic ordering.

#### Scenario: Export a meeting that was paused
- **WHEN** the user exports structured JSON for a paused meeting
- **THEN** transcript segments SHALL contain media offsets and pause events SHALL contain their real wall-clock times

### Requirement: Recoverable abnormal sessions
On startup the application SHALL reconcile the database, segment manifests, and files. It SHALL present abnormal recordings for user review and SHALL never reopen the microphone automatically.

#### Scenario: Recover after process termination
- **WHEN** startup discovers committed segments for a meeting without a finalized state
- **THEN** the meeting SHALL be marked recoverable and the user SHALL be able to save it or start an explicit continuation segment

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
