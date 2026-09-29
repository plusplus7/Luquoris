# Architecture

Loquiris uses a feature-first Flutter application around strict native and persistence boundaries:

```text
Flutter UI → Riverpod feature view models → typed service/repository interfaces
                                              │
                         ┌────────────────────┼────────────────────┐
                         ▼                    ▼                    ▼
                    Drift data        Android recorder      isolated AI jobs
```

The Android foreground recorder owns microphone capture, monotonic time, durable audio commits, interruption state, and recovery metadata. Flutter is an observer/controller, not the capture authority. One PCM input fans out to a priority recording path and a bounded disposable AI path.

Canonical audio segments and their manifest are authoritative. Merged audio, PCM intermediates, waveforms, indexes, transcripts, language labels, and speaker labels are derived or versioned products with explicit provenance.

See the active OpenSpec [design](../../openspec/changes/bootstrap-loquiris-offline-recorder/design.md) for decisions and alternatives.
