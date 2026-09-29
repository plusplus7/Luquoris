## ADDED Requirements

### Requirement: Complete recording control
The application SHALL allow the user to start, pause, resume, and stop a recording. Start SHALL proceed immediately after required preflight checks; stop SHALL require explicit in-app confirmation.

#### Scenario: Pause and resume a meeting
- **WHEN** the user pauses an active recording and later resumes it
- **THEN** no microphone audio SHALL be captured during the pause, the media timeline SHALL exclude the pause, and wall-clock pause events SHALL be retained

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

### Requirement: Interruption-aware capture
The recorder SHALL persist audio-focus, microphone, call, and system interruption events. It MAY automatically resume after a short transient focus loss, but it MUST require user confirmation before reopening the microphone after a completed call.

#### Scenario: Phone call interrupts a meeting
- **WHEN** a phone call causes microphone capture to pause
- **THEN** Loquiris SHALL record the interruption, SHALL NOT record call audio, and SHALL request confirmation before resuming capture after the call

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
