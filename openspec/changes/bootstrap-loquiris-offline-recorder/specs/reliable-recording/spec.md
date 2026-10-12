## ADDED Requirements

### Requirement: Complete recording control
The application SHALL allow the user to start, pause, resume, and stop a recording. Start SHALL proceed immediately after required preflight checks; stop SHALL require explicit in-app confirmation.

#### Scenario: Authoritative command completion survives asynchronous service work

- **WHEN** Flutter issues a recording command that Android accepts for service processing
- **THEN** Android SHALL persist a correlated command receipt and Flutter SHALL treat only a terminal success snapshot or typed terminal failure as completion
- **AND** intent enqueueing alone SHALL NOT be reported as successful recording state transition

#### Scenario: Stop finalization does not block the control channel

- **WHEN** stop requires encoder drain, segment finalization, or file synchronization
- **THEN** the native service SHALL persist `stopping` and perform blocking finalization on a serialized worker while retaining foreground and wake-lock ownership
- **AND** snapshot and command-receipt reads SHALL remain responsive

#### Scenario: Cold process restoration cannot revive stale capture state

- **WHEN** the application process starts with persisted active state but no live foreground-service ownership
- **THEN** the first authoritative restoration SHALL mark the session recoverable without activating the microphone
- **AND** this restoration SHALL occur even if no recording screen is opened

#### Scenario: Pause and resume a meeting
- **WHEN** the user pauses an active recording and later resumes it
- **THEN** no microphone audio SHALL be captured during the pause, the media timeline SHALL exclude the pause, and wall-clock pause events SHALL be retained

#### Scenario: Native start preflight fails
- **WHEN** setup choices were persisted but native capture fails before microphone ownership
- **THEN** Loquiris SHALL remove the zero-audio setup row through a lifecycle-and-audio guarded local transaction
- **AND** it SHALL NOT leave an ordinary library meeting that can never be resumed

#### Scenario: Meeting metadata persistence fails after capture starts
- **WHEN** native capture is active but synchronizing its authoritative snapshot to Drift fails
- **THEN** capture SHALL continue, the app-scoped coordinator SHALL retain a visible structured persistence warning, and a later snapshot or restoration SHALL retry synchronization

### Requirement: Foreground and background continuity
Active capture SHALL be owned by an Android foreground service and SHALL continue while the screen is locked, the Flutter task is backgrounded, or the recent-task entry is dismissed.

#### Scenario: Dismiss the application task
- **WHEN** the user swipes Loquiris from recent tasks during an active recording
- **THEN** the foreground service SHALL continue capture and the persistent system surface SHALL reopen the active meeting

### Requirement: Recording-first resource isolation
Canonical audio writing MUST NOT wait for Flutter UI, database queries, transcription, language identification, diarization, or other derived processing. AI backpressure or failure MUST be shed without blocking capture.

#### Scenario: Inference queue becomes full
- **WHEN** the bounded inference queue cannot accept more audio
- **THEN** the application SHALL preserve canonical audio, SHALL mark the draft as delayed or incomplete, and SHALL continue recording

### Requirement: Durable segmented storage
Audio SHALL be committed incrementally to app-private storage with an authoritative manifest. A process failure MUST lose no more than the final five seconds, and committed segments MUST remain discoverable and playable or exportable even if final merging fails.

#### Scenario: Process dies during an active segment
- **WHEN** the recording process terminates without finalization
- **THEN** previously committed audio SHALL remain intact and restart recovery SHALL identify the meeting as abnormally interrupted

### Requirement: Rebuildable continuous playback artifact
Loquiris SHALL rebuild continuous M4A playback from the authoritative manifest and only the AAC frame prefixes authorized by valid commit journals. Rebuilt timestamps SHALL follow cumulative media samples across segment boundaries. The M4A SHALL remain derived data: it MUST be written to a temporary file, durably completed, and atomically published, and callers SHALL consume it only after the current rebuild succeeds. A durable building/ready/failed status SHALL be bound to the current authoritative source generation. An interrupted building state SHALL be retried during startup reconciliation, while an explicit low-storage deferral SHALL remain failed until storage is available and the user retries.

#### Scenario: Finalized segments rebuild successfully
- **WHEN** a finalized or explicitly saved meeting has a valid manifest and journal-authorized AAC segments
- **THEN** Loquiris SHALL publish a continuous M4A whose access-unit count and timestamps cover the authoritative committed timeline
- **AND** the ready status SHALL identify the exact authoritative source generation and completed output size

#### Scenario: M4A rebuild fails
- **WHEN** parsing, muxing, syncing, or publication of the derived M4A fails
- **THEN** Loquiris SHALL report a structured local failure, SHALL remove the incomplete temporary artifact, and SHALL leave the manifest, journals, and segment files unchanged and usable for retry or raw-segment export
- **AND** a caller SHALL NOT resolve an earlier or visible-but-not-durably-confirmed ready artifact as the result of the failed rebuild

#### Scenario: Rebuild is interrupted after recording finalization
- **WHEN** startup reconciliation finds a non-live meeting whose playback status remains building
- **THEN** Loquiris SHALL retry the rebuild from the authoritative segment evidence without acquiring the microphone
- **AND** a rebuild explicitly deferred for critical low storage SHALL NOT be automatically retried

### Requirement: Partial recovery diagnostics and raw-segment fallback
Startup recovery SHALL classify a session as partial when its authoritative timeline contains a gap, a missing or corrupt segment, or discarded uncommitted bytes. Diagnostics SHALL use privacy-safe stable codes and optional manifest segment sequence numbers without audio, titles, names, or private absolute paths. A raw-segment export fallback plan SHALL list only journal-authorized byte prefixes in manifest order and SHALL disclose whether the session is partial. User-selected destination writing remains part of the explicit export workflow.

#### Scenario: Manifest timeline contains a gap
- **WHEN** a segment starts after or before the journal-authorized end of its predecessor
- **THEN** startup recovery SHALL mark the session partial and report `recording_recovery_timeline_gap` for that segment
- **AND** it SHALL NOT fabricate silence or rewrite authoritative files

#### Scenario: One segment is damaged but another remains usable
- **WHEN** a manifest references a missing file or a journal/data pair has no valid committed prefix
- **THEN** startup recovery SHALL preserve the damaged segment as missing or corrupt and mark the session partial
- **AND** the fallback plan SHALL include each other usable committed segment with its exact authorized byte limit

#### Scenario: Abrupt termination leaves an uncommitted tail
- **WHEN** bytes exist after the latest valid journal commit
- **THEN** startup recovery SHALL report the discarded tail and mark the session partial
- **AND** the fallback plan SHALL expose only the committed prefix rather than the trailing bytes

### Requirement: Interruption-aware capture
The recorder SHALL persist audio-focus, microphone, call, and system interruption events. It MAY automatically resume after a short transient focus loss, but it MUST require user confirmation before reopening the microphone after a completed call.

Call interruption detection MUST NOT require `READ_PHONE_STATE`; it SHALL use capture-local audio focus, call-like audio mode, and own-session microphone-silence signals without accessing phone numbers, call logs, or subscription data. Auto-resume SHALL be allowed only for an unambiguously transient focus interruption. A call-like or ambiguous microphone interruption SHALL require explicit user confirmation before capture resumes.

#### Scenario: Phone call interrupts a meeting
- **WHEN** a phone call causes microphone capture to pause
- **THEN** Loquiris SHALL record the interruption, SHALL NOT record call audio, and SHALL request confirmation before resuming capture after the call

#### Scenario: Interruption cause is ambiguous
- **WHEN** the platform silences Loquiris capture and the recorder cannot safely exclude a call-like interruption
- **THEN** Loquiris SHALL persist an ambiguous microphone interruption and SHALL require confirmation instead of silently reopening the microphone

### Requirement: Storage preflight and active warning
Before recording, the application SHALL estimate four-hour storage for the selected mode and reserve at least 512 MB of safety space. During recording it SHALL warn when remaining space is below the expected 30-minute requirement plus 256 MB and SHALL finalize safely if another segment cannot be written.

#### Scenario: Storage becomes critically low
- **WHEN** free space cannot safely hold the next durable audio commit
- **THEN** the recorder SHALL stop and preserve committed audio with a structured low-storage reason and SHALL NOT delete existing meetings automatically

### Requirement: Honest notification controls
The foreground notification SHALL expose recording state, duration, pause/resume, bookmark, and return-to-app behavior. It MUST NOT provide a one-tap destructive stop action.

#### Scenario: Notification permission is denied
- **WHEN** Android permits the foreground service but the user denies notification permission
- **THEN** the application SHALL warn that persistent visibility is reduced and MAY continue recording without misrepresenting the risk
