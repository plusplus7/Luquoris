## ADDED Requirements

### Requirement: Recording remains independent of remote processing
The mobile application SHALL durably capture audio without requiring network availability, a remote worker, or a local ASR model. Remote processing SHALL consume only finalized, verified audio in the first release.

#### Scenario: Network unavailable during capture
- **WHEN** the device is offline or the server is unavailable
- **THEN** recording, pause, stop and recovery remain available, and remote work waits durably without blocking capture

### Requirement: Resumable authenticated upload
The system SHALL persist upload identities and confirmed offsets, authenticate every resource access, validate lengths and digests, and reject incomplete uploads for transcription.

#### Scenario: Process restart during upload
- **WHEN** a client restarts after a partially acknowledged upload
- **THEN** it resumes from server-confirmed offsets, and retries of acknowledged identical chunks do not corrupt or duplicate audio

#### Scenario: Conflicting or unauthorized upload
- **WHEN** chunk contents conflict at an acknowledged offset or a token does not own the upload
- **THEN** the server rejects the operation without changing the stored audio

### Requirement: Durable idempotent transcription jobs
The server SHALL persist job state and request identity, isolate inference from API handling, and recover abandoned worker leases. Only the current uncancelled attempt SHALL commit a result.

#### Scenario: Lost submission response
- **WHEN** a client repeats a submission with the same idempotency key and request body
- **THEN** the server returns the same job identity, and a conflicting body is rejected

#### Scenario: Worker dies or cancellation races completion
- **WHEN** a running worker dies or submits after its job was cancelled or reclaimed
- **THEN** expired work can be recovered and stale completion cannot publish a successful result

### Requirement: Verifiable timestamped transcript versions
Remote results SHALL identify the audio manifest, job/run and model revision, carry bounded media timestamps, and be imported atomically as a distinct version without overwriting human edits.

#### Scenario: Long recording with pauses
- **WHEN** a long paused/resumed recording is split for inference and alignment
- **THEN** the server restores offsets to the original recorded-media timeline and tests cover missing or duplicated boundary speech

#### Scenario: Stale response or existing edits
- **WHEN** a result belongs to another manifest/run or a human-edited version is current
- **THEN** mismatched results are rejected and matching remote output does not overwrite the human-edited text

### Requirement: Explicit remote policy and deployable service
The release SHALL disclose remote audio transfer and actual retention, support authenticated HTTPS connections and explicitly configured private-LAN HTTP connections, provide reproducible server deployment instructions, and avoid uploading legacy recordings automatically.

#### Scenario: Migration from local transcription
- **WHEN** an existing installation upgrades
- **THEN** old recordings and transcript versions remain readable, old jobs retain their backend, and no prior recording is uploaded without a user remote-processing action

#### Scenario: Retention expires
- **WHEN** configured remote retention expires
- **THEN** server audio and results are cleaned up, the client exposes expiry, and local original audio remains available for resubmission

### Requirement: Bounded inference on the target server
The initial deployment SHALL target the user's RTX 3080 Ti with 12 GB VRAM, 8 CPU cores and 32 GB RAM. It SHALL admit one GPU task at a time, use batch size one and bounded audio chunks, and run recognition and forced alignment in separate sequential processes. It SHALL preserve the selected model identity on failure rather than silently substitute another model.

#### Scenario: Long recording exceeds a single model input budget
- **WHEN** a recording is longer than the configured chunk budget
- **THEN** the worker processes bounded chunks, persists their media offsets and does not load the entire recording as one GPU input

#### Scenario: GPU memory exhaustion
- **WHEN** inference fails with insufficient GPU memory
- **THEN** the job exposes a typed recoverable failure with bounded retries, releases the failed stage process and does not silently change models

### Requirement: Model selection uses measured target quality
The implementation SHALL evaluate candidate remote models on representative authorized audio with human references and record model/runtime revisions, CER/WER, omissions, boundary errors, elapsed time and peak memory before declaring accuracy or capacity improvements.

#### Scenario: Candidate evaluation
- **WHEN** a candidate model is proposed as the production default
- **THEN** a reproducible comparison against the existing local baseline and remote alternative supports that choice, and unmeasured hardware or quality claims remain explicitly unverified

### Requirement: Remote versions remain portable without fictional local models
The mobile application SHALL store remote task and transcript provenance independently of the bundled-model catalog. Remote versions and human corrections SHALL be readable and exportable locally after server expiry. Backups SHALL preserve those versions while excluding credentials and disabling automatic remote work on restore. Native background work and database migrations SHALL not write concurrently during a closed-file migration snapshot.

#### Scenario: Remote transcript on a device without local models
- **WHEN** a validated remote result is imported without any local ASR model installed
- **THEN** it is stored as a remote version with actual server model provenance, supports local reading/editing/export, and creates no fictional bundled model entry

#### Scenario: Restore cannot initiate a remote upload
- **WHEN** a backup containing remote versions and task metadata is restored
- **THEN** text and human edits remain available while credentials are absent and restored remote work requires a new explicit user action

### Requirement: Preserve zero-duration aligned tokens without fabricated intervals
The server SHALL preserve recognized text when an aligner emits zero-duration tokens by coalescing them with an adjacent positive-duration token inside the same chunk using the envelope of existing model time boundaries. It SHALL record the coalescing policy in provenance and reject reversed, out-of-bounds or entirely unanchored timestamps.

#### Scenario: Chinese aligner emits a point token
- **WHEN** aligned Chinese characters include equal start and end times among valid positive-duration tokens
- **THEN** all characters remain in order in bounded positive-duration output segments, without inventing per-character durations or dropping text

### Requirement: Resolve competing boundary hypotheses with recorded context ownership
The server SHALL resolve temporally overlapping hypotheses from distinct windows by selecting one complete group's original text and timestamps with the greatest minimum distance from its source window edges, preferring the earlier window on ties. It SHALL record the policy and conflict-group count in provenance. It SHALL NOT synthesize text or time intervals or claim the selected hypothesis is ground truth.

#### Scenario: Adjacent windows recognize different boundary words
- **WHEN** valid adjacent-window hypotheses conflict over the same media interval
- **THEN** one complete context-owned hypothesis is emitted with disjoint bounded timestamps, the conflict is counted, and the rest of the recording remains publishable

### Requirement: Private LAN HTTP is explicit and bounded
The client SHALL accept HTTP only to canonical RFC1918 IPv4 literals or 127.0.0.1, retain authentication, reject redirects and unsafe URL components, and keep normal certificate validation for HTTPS. Dart and native endpoint policy SHALL agree.

#### Scenario: LAN server without certificates
- **WHEN** the user configures `http://192.168.1.20:18000` with a valid token
- **THEN** upload, polling and result retrieval use the authenticated LAN connection without requiring a certificate

#### Scenario: Public HTTP or redirected endpoint
- **WHEN** an HTTP origin is public, hostname-based, includes URL secrets, or redirects
- **THEN** the client rejects it and never forwards the bearer token to the redirect destination

### Requirement: Capture-focused mobile interaction
Remote-mode screens SHALL expose useful recording and remote-result actions, omit ineffective language/speaker/local-model/benchmark/live-draft controls, and store server connection settings centrally outside backups. Saving a connection SHALL NOT create new transcription work; it MAY bind previously opted-in unconfigured work, excluding restored tasks. Active tasks SHALL not expose duplicate rerun actions.

#### Scenario: Save server before first recording
- **WHEN** the user saves a LAN origin and token in Settings
- **THEN** the configuration survives app restart, no meeting/job is created, and future explicitly remote recordings reuse it

#### Scenario: Simplified recording and result view
- **WHEN** the user records in remote mode and later opens the meeting
- **THEN** recording controls, one appropriate transcription action, progress, versions/edit/export and playback remain available without unrelated model or unused configuration controls
