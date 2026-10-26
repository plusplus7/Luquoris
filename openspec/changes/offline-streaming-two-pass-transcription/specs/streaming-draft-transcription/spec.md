## ADDED Requirements

### Requirement: Entirely offline incremental recognition
The application SHALL offer a replaceable streaming engine that consumes captured PCM incrementally and preserves recognizer state within a live session. Chinese, English, and within-utterance Chinese/English switching SHALL be supported by the selected qualified model. Recording and advertised recognition MUST operate with networking unavailable and without runtime model downloads.

#### Scenario: Bilingual meeting without connectivity
- **WHEN** a qualified live configuration records speech containing both Chinese and English with all networking disabled
- **THEN** incremental text SHALL appear locally in the original languages without requiring a remote service or translating the utterance

### Requirement: Live experience latency and headroom
On the declared evidence device, qualified live mode SHALL achieve first-visible-text p95 at most two seconds from the first voiced captured sample, utterance-final-result p95 at most three seconds after the last voiced sample, and sustained effective RTF at most 0.7 in speech-bearing non-overlapping 60-second windows and the run aggregate. Unique-audio backlog p95 SHALL remain at most two seconds and MUST NOT grow throughout a sustained meeting. Measurements MUST include cold-start/model-loading, input queuing, and endpointing costs where applicable.

#### Scenario: Model is fast in a short batch but slow to display text
- **WHEN** a candidate passes a short batch RTF comparison but fails cold-start first-text latency, stabilized latency, or sustained backlog limits
- **THEN** the candidate SHALL fail live qualification and SHALL remain experimental or available only in an independently qualified non-live role

### Requirement: Identifiable provisional and finalized utterances
Live events SHALL identify meeting, run, owner epoch, monotonic sequence, utterance, and provisional/final status. Provisional text SHALL be revisable only within its live utterance. Finalized utterances SHALL retain stable identities and capture-time intervals within the draft run. During recording, draft text SHALL remain read-only while timestamped bookmarks and highlights remain available.

#### Scenario: Partial text changes while another callback arrives late
- **WHEN** the recognizer revises a provisional utterance and an older event subsequently arrives
- **THEN** the UI SHALL keep the newest valid hypothesis and SHALL reject the stale event without changing finalized utterances or human-authored data

### Requirement: Canonical capture-time alignment
Recognition SHALL consume the recorder's canonical PCM fan-out and SHALL anchor segment times to captured media rather than processing wall time. Pause/resume, audio-focus interruptions, and PCM discontinuities SHALL reset or close affected recognizer utterances and preserve explicit timing gaps. Text MUST NOT be synthesized for missing captured media.

#### Scenario: User pauses before an utterance is complete
- **WHEN** recording pauses with an unstable live hypothesis and later resumes
- **THEN** the previous utterance SHALL be finalized or marked incomplete, a new recognition epoch/utterance SHALL begin as required, and displayed text SHALL retain correct media-time alignment across the pause

### Requirement: Recording-first bounded degradation
Inference input SHALL be bounded and non-blocking for capture. If unprocessed unique captured audio exceeds five seconds for three consecutive one-second observations, or severe thermal status, unrecoverable memory pressure, model failure, or engine failure occurs, live recognition SHALL stop or pause safely. Original recording SHALL continue; the UI SHALL preserve the draft, report incomplete live coverage and the cause, and retain complete-pass processing availability. Recorder pause/stop feedback SHALL remain within 500 ms.

#### Scenario: Streaming recognizer falls behind
- **WHEN** the backlog remains above five seconds at three consecutive one-second checks
- **THEN** inference resources SHALL be released or safely paused, capture SHALL continue without waiting on the recognizer, and the user SHALL see that full transcription will be performed after recording

### Requirement: Session lifecycle isolation
At most one live recognizer SHALL own a recording session. Stop, cancellation, owner replacement, or process recovery SHALL close its native state, and all events from the previous run or epoch SHALL be rejected. Streaming model resources MUST NOT remain allocated after the run is closed.

#### Scenario: Previous session returns text after a new session starts
- **WHEN** a delayed native callback belongs to an already closed live run
- **THEN** it SHALL be ignored and MUST NOT populate the new meeting's draft or change its processing state
