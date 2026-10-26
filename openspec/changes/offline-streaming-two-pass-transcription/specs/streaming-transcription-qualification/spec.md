## ADDED Requirements

### Requirement: Atomic offline model bundles with legacy compatibility
Multi-file models SHALL have immutable bundle manifests identifying every required encoder, decoder, joiner, tokenizer, and configuration artifact, its safe path, exact byte length, SHA-256, role, source revision, runtime compatibility, and license snapshot. Bundle identity SHALL hash a documented canonical inventory. Import, integrity verification, and publication SHALL be atomic for the complete set. Existing v1 single-file models and durable provenance SHALL remain readable.

#### Scenario: Tokenizer file is modified while encoder bytes are valid
- **WHEN** verification detects that any required bundle artifact is absent or differs from its inventory
- **THEN** the complete dependent recognition capability SHALL be disabled before engine allocation, recording SHALL remain available, and previously verified assets SHALL not be partially replaced

### Requirement: Independent runtime and model redistribution review
Every runtime dependency and every distributed model/tokenizer/configuration artifact SHALL have pinned provenance and fixed terms permitting the required commercial use and redistribution. Unapproved candidate bundles SHALL remain behind explicit development-only gates and MUST NOT enter ordinary production imports or installable production artifacts. Production releases SHALL retain the existing 500 MiB artifact and 800 MiB installed-footprint limits, including required materialized model copies.

#### Scenario: Runtime is open source but model terms are unsuitable
- **WHEN** a candidate weight or tokenizer lacks suitable redistribution terms
- **THEN** the model pair SHALL fail production selection regardless of the runtime license or measured recognition quality

### Requirement: Verified language-stratified accuracy corpus
Qualification SHALL use at least 30 minutes each of held-out Chinese, English, and genuinely code-switched Chinese/English audio with human reference transcripts, documented rights, stable hashes, and frozen scoring rules. The mixed stratum SHALL contain both languages within utterances. Corpus coverage SHALL be established from audio and annotations, not a language hint, catalog label, or translated output. Digital-input and room-playback results SHALL be reported separately across the original acoustic matrix.

#### Scenario: Labeled bilingual smoke input contains only Chinese
- **WHEN** inspection finds that an input lacks actual English speech or within-utterance switching
- **THEN** it SHALL not count toward mixed-language acceptance duration, and its coverage annotation SHALL be audited without silently modifying immutable audio

### Requirement: Role-specific live and refined quality gates
Frozen normalized accuracy ceilings for stabilized live output SHALL be Chinese CER at most 20%, English WER at most 25%, and mixed MER at most 25%. Refined output SHALL achieve CER at most 15%, WER at most 20%, and MER at most 20%. Its equally weighted mean of those three error rates SHALL improve by at least 15% relative to the live pass, and no individual metric SHALL regress by more than two percentage points. Raw and normalized scores SHALL both be published with insertion, deletion, substitution, proper-name, and code-switch breakdowns. Formatting normalization MUST NOT erase lexical recognition errors.

#### Scenario: Second pass improves Chinese but damages English terms
- **WHEN** the refined model improves aggregate error but exceeds the allowed English regression or any required quality ceiling
- **THEN** the pair SHALL fail refinement qualification and SHALL not be advertised as the accepted higher-quality configuration

### Requirement: Repeated end-to-end live latency and sustained capacity
Qualification SHALL measure at least 30 eligible utterances per language stratum and at least ten cold starts, separating cold and warm results. The two-second first-text p95, three-second utterance-final p95, 0.7 speech-bearing sustained RTF, and two-second backlog p95 gates SHALL include actual capture, queuing, model-loading, endpointing, and display delivery. Empty hypotheses and silence-only windows SHALL not establish compliance. At least two four-hour live runs SHALL pass with measured non-growing backlog.

#### Scenario: Short warm-run benchmark meets all timing targets
- **WHEN** the model pair lacks required cold starts, language strata, or four-hour live evidence
- **THEN** it SHALL remain experimental despite the successful short result

### Requirement: Recorder and resource regression gates
Evidence SHALL be scoped to the exact `M2104K10AC`/`chopin` hardware and recorded firmware, RAM, SoC, Android, storage, battery health, ambient temperature, and power configuration. It SHALL include controlled and factory-default configurations, actual microphone capture, interruption/recovery tests, CPU, continuously sampled peak RSS/PSS, thermal, battery, backlog, and Flutter frames. Live battery use SHALL be at most 12% per hour, severe-jank frame ratio below 1%, and pause/stop feedback at most 500 ms. The complete-pass high-quality RTF ceiling SHALL remain 2.0. All existing recording reliability gates SHALL continue to pass.

#### Scenario: Recognition quality passes but capture controls stall
- **WHEN** inference causes recorder feedback to exceed 500 ms, unexplained committed-audio loss, or any required recording regression
- **THEN** the pair SHALL fail qualification even if text accuracy and average inference speed pass

### Requirement: Evidence-based availability and recommendation
The application SHALL advertise the new streaming capability as production-ready only for qualified configurations with complete quality, license, footprint, latency, resource, and stability evidence. The bundled 30–60 second first-run performance check SHALL recommend a qualified mode but MUST NOT automatically change user selections or certify accuracy/long-run stability. When no pair passes all gates, recording and independently qualified post-session modes SHALL remain available and live mode SHALL be clearly experimental or disabled.

#### Scenario: Candidate pair misses the target-device gates
- **WHEN** no evaluated bilingual pair meets all acceptance requirements
- **THEN** the release SHALL retain honest recorder/post-session availability, SHALL document failed gates, and MUST NOT substitute cloud processing or claim unmeasured live performance
