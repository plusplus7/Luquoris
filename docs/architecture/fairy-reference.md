# Fairy read-only reference boundary

`/Users/bytedance/workspace/Fairy` is a read-only local reference and is not a project dependency.

## Patterns that may be reimplemented

- Android foreground-service recording and notification lifecycle.
- Incremental audio segments, recovery manifests, monotonic duration, and input-health checks.
- WorkManager-based resumable analysis and local export.
- Private storage, disabled Android backup, release permission/dependency scans.
- Unit, widget, golden, JVM, instrumented, and process-recreation test shapes.
- Token → theme → shared-widget design-system organization.

## Prohibited reuse

- Sleep, snoring, YAMNet, sound-category, report, or timeline domain code and data models.
- Noctis names, colors, copy, imagery, theme packs, or other sleep-business visual semantics.
- Fairy package/application identity, signing material, OpenSpec changes, Git history, database schema, migrations, or user data.
- Assumptions that Fairy already supplies Riverpod, GoRouter, Drift, typed results, strict feature-first architecture, or CI; it does not.

Any code-level adaptation must be independently reviewed, tested against Loquiris requirements, and carry compatible attribution where required. Fairy itself must never be modified by Loquiris tasks.
