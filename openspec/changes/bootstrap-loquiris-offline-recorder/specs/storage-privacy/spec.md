## ADDED Requirements

### Requirement: Private offline storage
Meetings, models, database files, and work products SHALL default to application-private storage. Android cloud backup SHALL be disabled, and no file SHALL leave private storage without explicit export or backup action.

#### Scenario: Normal meeting completion
- **WHEN** a recording is finalized
- **THEN** its files SHALL remain private to Loquiris until the user explicitly chooses an external destination

### Requirement: No runtime networking or telemetry
Release artifacts MUST NOT request Android network permissions and MUST NOT include advertising, analytics, remote configuration, account, cloud inference, remote crash upload, or hidden model-download behavior.

#### Scenario: Third-party dependency introduces telemetry
- **WHEN** release dependency inspection detects a telemetry or remote-upload SDK
- **THEN** the privacy release gate SHALL fail

### Requirement: Sensitive-log exclusion
Logs MUST NOT contain audio, full transcript content, meeting titles, speaker names, or sensitive export paths. Diagnostic logs SHALL roll at seven days or 10 MiB, whichever limit is reached first.

#### Scenario: User creates a diagnostic package
- **WHEN** diagnostics are exported after an AI failure
- **THEN** the package SHALL contain error codes, state transitions, device/model metadata, and resource metrics without the prohibited content

### Requirement: Explainable storage accounting
The storage UI SHALL separately report application/models, active meetings, rebuildable cache, trash, and available device space. It SHALL explain that bundled models cannot be individually removed in the all-model release.

#### Scenario: User reviews a large installation
- **WHEN** the user opens storage settings
- **THEN** the UI SHALL distinguish fixed bundled models from meeting content and safely clearable cache

### Requirement: Safe automatic cleanup
The application MAY automatically remove only rebuildable PCM intermediates, waveform caches, search caches, and failed-job temporary files. It MUST NOT automatically remove authoritative audio, current transcripts, human revisions, bookmarks, backup files, or trash.

#### Scenario: Device reports storage pressure
- **WHEN** automatic cache cleanup is invoked
- **THEN** meeting audio and user-authored information SHALL remain unchanged

### Requirement: Clear deletion and uninstall semantics
The application SHALL enumerate the audio, transcripts, revisions, exports under its control, and metadata affected by permanent meeting deletion. It SHALL state that uninstall removes app-private data and that external exports/backups remain outside application control.

#### Scenario: Permanently delete from trash
- **WHEN** the user confirms permanent deletion
- **THEN** the application SHALL remove private authoritative files and records for that meeting and SHALL not claim to delete copies previously exported elsewhere

#### Scenario: Permanent deletion is interrupted
- **WHEN** permanent deletion has been confirmed but file or database removal does not finish
- **THEN** the meeting SHALL remain in a durable non-restorable deleting state with enough metadata to retry cleanup, and the application SHALL NOT restore metadata whose authoritative audio may already be deleted

### Requirement: Recording consent visibility
The application SHALL present a first-use reminder that the user is responsible for required recording consent and SHALL display an unambiguous recording indicator and timer during active capture. It MUST NOT provide a stealth recording mode.

#### Scenario: Begin the first recording
- **WHEN** the user starts recording for the first time
- **THEN** the application SHALL show the consent responsibility notice before capture and SHALL display the active state thereafter
