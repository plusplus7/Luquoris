# Security Policy

## Supported versions

Loquiris is pre-alpha and has no supported production release yet. Security fixes target the active development branch.

## Reporting

Do not attach private meetings, audio, transcripts, names, device identifiers, model files, or unredacted diagnostic archives to public issues. Open a minimal private security report with reproduction steps and privacy-safe logs through the repository host's private vulnerability-reporting feature once enabled.

## Security invariants

- Release builds contain no Android network permissions.
- Canonical audio remains in app-private storage until explicit export.
- Optional AI failures cannot delete or block canonical recordings.
- Model and backup inputs are verified before use.
- Logs exclude audio, full transcript text, meeting titles, speaker names, and sensitive paths.
