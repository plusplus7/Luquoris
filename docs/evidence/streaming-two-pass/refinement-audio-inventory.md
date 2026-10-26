# Refinement audio inventory v1

This is a worker-only implementation boundary, not evidence that durable
scheduling, native refinement, microphone streaming, or device qualification
is complete. The new reader is not yet installed in the application bootstrap.

`RefinementAudioInventoryReader` rejects every partial resolution. Its strict
resolver rejects incomplete/corrupt journal suffixes, fallback to an older
commit, and a journal frame count that does not exactly cover the ADTS bytes.
The existing post-session resolver keeps its default recoverable-prefix policy.
Neither path is changed into a repair operation: original files are read only.

Each strict segment carries the SHA-256 of the same bytes checked against its
journal. The inventory reader streams the file again and requires its SHA-256
to match that verified digest, detecting same-length changes between validation
and hashing. Execution must inspect again with the expected inventory digest;
this inspection is not a filesystem lock or a proof against later mutation.
The new unwired execution core therefore copies and verifies the same compressed
bytes into a private read-only temporary snapshot before decoding, rather than
relying on pre/post hashes alone. It rechecks originals before accepting output
and cleans its own copies after releasing native handles. An exclusive process /
OS lease protects active copies; the next owner reclaims only marked, recognized
abandoned snapshot files after process death. Unknown entries and symbolic links
are never followed or deleted. Production execution wiring remains pending.

The read-only `refinement_audio_v1` channel also returns each original segment's
index, start/committed samples, committed bytes, and verified data SHA-256.
`referenceSha256` is SHA-256 of the UTF-8 app-relative reference
`recordings/<session-directory>/<manifest-data-file>`. This opaque local binding
lets scheduling compare the actual persisted reference without sending paths
over the channel. It is separate from the core audio digest: relocation can
change this local binding while preserving content identity. Dart validates
integer types, all segment boundaries, count/total agreement, and digest shapes;
scheduling compares every segment against the durable database inventory.

## Canonical identity

SHA-256 is computed over this binary sequence, with signed big-endian 32-bit
integers (`i32`) and signed big-endian 64-bit integers (`i64`). All represented
counts, positions, and lengths are nonnegative. Digests are raw 32-byte values,
not their hexadecimal text. No platform-specific serialization is used.

1. UTF-8 bytes of `Loquiris.refinement-audio.v1` followed by one zero byte.
2. Sample rate (`i32`), channel count (`i32`, currently 1).
3. Codec-specific-data item count (`i32`), followed by each item's byte length
   (`i32`) and exact bytes, in manifest order.
4. Ordered segment count (`i32`), followed by each segment's index (`i32`),
   start sample (`i64`), committed sample count (`i64`), committed byte count
   (`i64`), and raw SHA-256 of its complete committed ADTS data.

Meeting IDs, directory/file names, timestamps, and journal flush grouping are
excluded. A restored relocation retains audio identity; the durable job must
separately include its owning meeting, processing role, runtime/model identity,
and canonical decoding parameters. Journals still authorize all input bytes.

Independent Python `struct.pack`/`hashlib` vectors, also asserted by native tests:

- 16 kHz mono, CSD `1408`, one segment at sample 0, 1024 samples, ADTS bytes
  `fff16040017ffc01020304`:
  `837d745d71771f720eac84b4e343b5a3e93dc48ff61bf2ad132a92fecc97d873`.
- Same format, second segment at sample 1024 with 1024 samples and ADTS bytes
  `fff16040017ffc05060708`:
  `561a6fd703366e0cad34d0b109f3d559969ece53872b4a09a2b1b657e03983d3`.

## Verification scope

The native JVM suite now passes 353 tests in 82 suites. The 12 strict real-file tests
cover valid strict input, journal truncation/corruption, latest-commit loss,
actual-frame undercount, path-independent one/two-segment vectors, missing or
uncommitted audio, expected-identity mismatch, same-length concurrent change,
and early/mid-read recording-priority yield without modifying source files.
The two review-discovered regressions were reproduced before their fixes.
Five plain-controller tests cover worker/reply dispatch, invalid requests,
typed deferral/cancellation, process capture ownership, and sanitized worker or
closed-executor failure. Six Dart channel tests include strict scalar and
per-segment validation. On 2026-10-15 the read-only device round-trip test passed
on the connected M2104K10AC: a deliberately absent meeting returned the actual
native strict resolver's `transcription_audio_missing`, not a missing-plugin
fallback. Only the separate `com.loquiris.debug` test package was replaced;
the test did not run Dart application bootstrap, open its database, or activate
the microphone. Log: `build/streaming_spike/refinement-audio-device-round-trip.log`.
This negative-path round-trip is not complete-inventory or model-inference
device evidence; host unit tests do not replace those checks.

Recording-priority callbacks are injectable. This does not yet establish the
production gate, cancellation during the resolver's bounded segment read,
or safe worker/model preemption. Those remain
required integration work before tasks 5.2–5.4 can be marked complete.
