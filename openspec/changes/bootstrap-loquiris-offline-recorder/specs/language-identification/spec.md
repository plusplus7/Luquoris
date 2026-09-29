## ADDED Requirements

### Requirement: Explicit language modes
The user SHALL be able to select Chinese, English, or mixed mode for each meeting. Chinese and English SHALL act as strong recognition hints without deleting clearly spoken words from the other language.

#### Scenario: English term in Chinese mode
- **WHEN** a Chinese-mode segment contains a recognizable English product name
- **THEN** the system SHALL preserve the English term when the engine can recognize it

### Requirement: Segment-level local identification
In mixed mode, the application SHALL assign Chinese, English, mixed, or uncertain language metadata to each stable segment using only on-device processing.

#### Scenario: Low-confidence language evidence
- **WHEN** a segment does not meet a calibrated language threshold
- **THEN** the application SHALL retain the current/hinted mode or mark the segment uncertain rather than force a language switch

### Requirement: Manual language correction
The user SHALL be able to correct the language label of a finalized segment, and re-analysis MUST NOT overwrite that correction.

#### Scenario: Correct a mislabeled segment
- **WHEN** the user changes a segment from Chinese to mixed
- **THEN** the change SHALL be recorded as a revision and used by the current display/export version

### Requirement: Language quality gate
On the defined labeled evaluation set, principal-language classification for Chinese and English SHALL reach at least 90% accuracy before automatic labels are treated as production quality. Mixed and uncertain results SHALL be reported separately.

#### Scenario: Classifier misses the gate
- **WHEN** measured accuracy is below the threshold
- **THEN** automatic language labels SHALL be marked experimental and manual selection SHALL remain available
