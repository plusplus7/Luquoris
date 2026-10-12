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

The MVP backup SHALL be a versioned ZIP whose first entry is `manifest.json`. The manifest SHALL contain independent `formatVersion` and database `schemaVersion` values, application version provenance, an injected UTC export instant, an explicit `encrypted: false` disclosure, and a SHA-256 over the exact canonical bytes of `payload/checksums.json`. The checksum index SHALL list every other payload entry by safe archive path, byte length, and lowercase SHA-256. Payload collection SHALL be allowlist-based: a WAL-safe SQLite snapshot, authoritative recording manifests and journal prefixes, and exact committed audio prefixes only. Bundled model weights, derived M4A/waveform/index files, caches, temporary files, and diagnostic logs MUST NOT be package candidates. Model provenance rows stored in the database remain necessary metadata and are not bundled model weights.

#### Scenario: Create an MVP backup
- **WHEN** the user confirms backup after a sensitive-data warning
- **THEN** the application SHALL write a checksummed local package and SHALL state that the MVP package is not password encrypted

#### Scenario: Unrelated private files exist
- **WHEN** model weights, caches, diagnostics, or failed-job temporary files exist beside authoritative application data
- **THEN** the backup SHALL omit them because only explicitly planned payload entries are eligible

### Requirement: Deterministic restore conflict handling
Restore SHALL verify package integrity, skip content-identical meetings, and import conflicting IDs with different content as new meetings. It MUST NOT silently overwrite local meetings.

#### Scenario: Restore a changed duplicate ID
- **WHEN** a backup meeting ID matches a local ID but content hashes differ
- **THEN** the restored meeting SHALL receive a new ID and a localized restored-copy title marker

### Requirement: Export and restore progress
Long export, backup, and restore operations SHALL expose progress, cancellation where safe, durable failure reasons, and cleanup of incomplete derived output.

For direct Android Storage Access Framework exports, durable operation records SHALL contain only the operation identity, meeting identity, requested format, timestamps, terminal state, completed byte count, and a stable privacy-safe failure code. They MUST NOT persist the destination URI, user-edited external filename, meeting title, transcript content, or speaker names. Live progress SHALL distinguish destination selection, writing, and finalization. Cancellation SHALL be cooperative after destination selection and SHALL never mutate authoritative meeting data. If Android cannot remove an incomplete destination, the terminal failure SHALL explicitly identify that an incomplete external file may remain.

#### Scenario: Export is cancelled
- **WHEN** the user cancels before the destination is finalized
- **THEN** the application SHALL leave authoritative meeting data untouched and SHALL remove or identify incomplete output under platform constraints

#### Scenario: Incomplete destination cannot be removed
- **WHEN** export writing or cooperative cancellation leaves an incomplete document and the provider refuses cleanup
- **THEN** the application SHALL durably record a privacy-safe cleanup failure and SHALL tell the user that an incomplete external file may remain
