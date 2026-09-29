## ADDED Requirements

### Requirement: Post-session speaker analysis
Speaker diarization SHALL run as a replaceable, resumable post-session process and MUST NOT compete with or block active audio capture. Real-time diarization is not a production MVP capability.

#### Scenario: Request analysis during another recording
- **WHEN** a user requests diarization while a meeting is actively recording
- **THEN** the application SHALL defer or resource-limit diarization so canonical capture retains priority

### Requirement: Two-to-six speaker guidance
The user SHALL be able to choose automatic speaker-count estimation or provide an expected count from two through six. The supplied count SHALL guide analysis but MUST NOT prevent later correction.

#### Scenario: Expected count is incorrect
- **WHEN** the user selects four speakers but analysis finds evidence requiring correction
- **THEN** the result SHALL remain editable through merge, split, reassignment, and rename operations

### Requirement: Stable meeting-local speaker identity
Speaker clusters SHALL use stable internal IDs local to one analysis version. User-facing labels MAY be renamed to real names, but the application MUST NOT build or transfer cross-meeting voice identities by default.

#### Scenario: Re-analyze a named meeting
- **WHEN** a new diarization run generates new clusters
- **THEN** real names from the prior run SHALL NOT be attached automatically without user confirmation

### Requirement: Speaker correction workflow
The user SHALL be able to merge speakers, split or reassign segments, rename labels, and mark a segment uncertain. Corrections SHALL be revisions and SHALL NOT mutate the raw engine result.

#### Scenario: Merge duplicate clusters
- **WHEN** the user merges two labels believed to represent the same person
- **THEN** the current corrected view and exports SHALL use the merged label while preserving the original analysis version

### Requirement: Uncertainty and overlap
Overlapping speech, low-confidence assignment, far-field speech, and noisy regions SHALL be displayed as uncertain or requiring confirmation unless the selected model has calibrated evidence for the assignment.

#### Scenario: Two people overlap
- **WHEN** the engine cannot reliably attribute an overlapping interval
- **THEN** the interval SHALL be marked for confirmation rather than assigned a deceptively precise speaker identity

### Requirement: Production diarization gate
Automatic speaker labels SHALL remain experimental until the selected model achieves DER of at most 25% on the defined two-to-six-speaker non-overlap set and passes long-session memory, thermal, and stability gates.

#### Scenario: DER exceeds threshold
- **WHEN** release evidence reports DER above 25%
- **THEN** automatic diarization SHALL not be enabled by default, while manual speaker labeling SHALL remain available
