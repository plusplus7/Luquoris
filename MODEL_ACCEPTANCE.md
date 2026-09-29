# Model Acceptance Policy

A model may enter a production Loquiris artifact only when all checks below have recorded evidence.

## License and provenance

- Fixed license terms permit use, redistribution, modification where applicable, and commercial use.
- Source URL, immutable version, byte length, SHA-256, training/provenance statement, and license snapshot are recorded.
- A source-available or non-commercial license is not classified as open source.

## Product and safety

- The model operates fully offline and requires no hidden download, account, or remote service.
- Failure disables only its derived capability and never blocks recording or access to original audio.
- User-visible confidence is shown only after calibration.

## Evidence

- Accuracy, RTF, latency, peak memory, CPU, thermal, energy, UI responsiveness, and long-run stability are measured on the declared target configuration.
- Package and installed footprints remain within the accepted budgets.
- `THIRD_PARTY_NOTICES.md` and the machine-readable model manifest are updated and independently reviewed.

Unapproved candidates may exist only behind development-only experimental flags and must not be bundled into production artifacts.
