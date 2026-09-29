## ADDED Requirements

### Requirement: Explicit local export
The application SHALL export data only after an explicit user action through Android user-selected destinations. Supported MVP outputs SHALL include canonical or merged M4A audio, readable TXT, timestamped SRT, and complete structured JSON, optionally grouped in ZIP.

#### Scenario: Export a complete meeting package
- **WHEN** the user selects audio, transcript, and structured metadata and confirms a destination
- **THEN** the application SHALL create the selected files locally without sending them to a remote service

### Requirement: Privacy-preserving export names
Default exported filenames SHALL contain Loquiris and date/time but MUST NOT automatically include the meeting title, transcript text, or speaker names. The user MAY explicitly change the filename.

#### Scenario: Export a meeting with a sensitive title
- **WHEN** the meeting title contains a person's name
- **THEN** the proposed external filename SHALL not contain that title or name

### Requirement: Export from authoritative segments
An unavailable or failed merged file MUST NOT prevent export. The export service SHALL be able to package or rebuild from authoritative committed segments and SHALL disclose partial or failed derived artifacts.

#### Scenario: M4A merge previously failed
- **WHEN** the user requests audio export from a meeting with valid segments but no merged file
- **THEN** the application SHALL offer a rebuilt continuous export or the recoverable segments rather than reporting that no audio exists

### Requirement: Complete local backup
Backup SHALL contain meeting records, authoritative audio segments and manifests, transcript versions, corrections, speaker/language revisions, bookmarks, and necessary metadata. It MUST exclude bundled models, caches, and diagnostic logs.

#### Scenario: Create an MVP backup
- **WHEN** the user confirms backup after a sensitive-data warning
- **THEN** the application SHALL write a checksummed local package and SHALL state that the MVP package is not password encrypted

### Requirement: Deterministic restore conflict handling
Restore SHALL verify package integrity, skip content-identical meetings, and import conflicting IDs with different content as new meetings. It MUST NOT silently overwrite local meetings.

#### Scenario: Restore a changed duplicate ID
- **WHEN** a backup meeting ID matches a local ID but content hashes differ
- **THEN** the restored meeting SHALL receive a new ID and a localized restored-copy title marker

### Requirement: Export and restore progress
Long export, backup, and restore operations SHALL expose progress, cancellation where safe, durable failure reasons, and cleanup of incomplete derived output.

#### Scenario: Export is cancelled
- **WHEN** the user cancels before the destination is finalized
- **THEN** the application SHALL leave authoritative meeting data untouched and SHALL remove or identify incomplete output under platform constraints
