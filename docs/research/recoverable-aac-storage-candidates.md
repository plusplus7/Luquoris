# Recoverable AAC Storage Candidates

## Decision status

No production container or commit design is selected yet. This document records
the host-verifiable comparison for OpenSpec task 5.3 and the measurements that
must still run on the selected Redmi Note 10 Pro (`M2104K10AC`/`chopin`,
6GB+128GB class). The leading
hypothesis is append-only ADTS AAC-LC plus a durably committed index/manifest,
with a derived M4A rebuilt after capture. It remains experimental until tasks
5.2, 5.4, and 5.5 produce physical-device evidence.

The authoritative recording must survive independently of final M4A creation.
The five-second recovery limit applies to media not durably committed before an
abrupt failure, not merely to metadata reporting.

## Fixed input and storage calculations

The spike evaluates mono, 16 kHz PCM16 input and AAC-LC at 64 kbit/s. Payload
figures below exclude container headers, indexes, manifests, filesystem
allocation, and temporary files.

| Encoding | Four-hour payload | Decimal MB | MiB |
|---|---:|---:|---:|
| PCM16, mono, 16 kHz | 460,800,000 bytes | 460.8 MB | 439.45 MiB |
| AAC-LC, 64 kbit/s | 115,200,000 bytes | 115.2 MB | 109.86 MiB |
| AAC-LC, 32 kbit/s | 57,600,000 bytes | 57.6 MB | 54.93 MiB |

At 16 kHz, an AAC-LC frame represents 1,024 samples, or 64 ms. A group of 78
frames represents 4.992 seconds, remaining inside the five-second commit
target. Sixty such commit groups represent 299.52 seconds, close to one
five-minute logical segment. These are planning values, not proof of the loss
bound: the device test must show that encoded bytes and the corresponding
manifest entry are both durable after each commit.

## Candidate comparison

| Candidate | Short durable commits | Five-minute logical segmentation | Gap-free playback | Final M4A | Assessment before device testing |
|---|---|---|---|---|---|
| One long M4A written by `MediaMuxer` | Weak. The active file is not safe to consume until `stop()` completes. | Natural as one file, but the active container is a large failure domain. | Standard player behavior after clean finalization. | Already M4A after a clean stop. | Reject as the authoritative active recording. It can remain a derived final artifact. |
| Standalone M4A file per commit (at most 5 s) | Stronger once every tiny file is stopped, synced, and its manifest entry committed. | About 2,885 files for four hours at 4.992 s per file, unless hidden behind a second grouping layer. | Must measure encoder delay/padding and timestamp continuity at every boundary. | Requires remux/rebuild from thousands of inputs. | Retain as a fallback experiment, not the preferred design. File count, finalization overhead, and gapless risk are high. |
| Standalone M4A per logical segment (about 5 min) | Weak without an additional fragment/journal scheme; abrupt loss can approach the active segment length. | Direct match. | Standard after each segment finalizes; boundaries still require measurement. | Straightforward remux after clean segment finalization. | Reject by itself because it cannot satisfy the five-second loss requirement. |
| Append-only ADTS AAC plus durable commit index | Promising. Complete frame prefixes can be found after a truncated tail; the index can expose only synced commit boundaries. | Rotate an authoritative ADTS file after 60 commit groups, while keeping commit records inside each logical segment. | Must be measured across commit and file boundaries; host parsing alone cannot prove audible continuity. | Rebuild by parsing frames, deriving monotonic sample timestamps, supplying AAC codec configuration, and muxing into a new M4A. | Provisional leading candidate. Device encoder output, sync ordering, playback, and remux equivalence remain unverified. |
| Fragmented MP4 | Potentially strong if every fragment is independently durable. | Possible. | Potentially good with correct fragment timestamps. | Already an ISO-BMFF family artifact or remuxable. | Do not select for the MVP spike. Android `MediaMuxer` does not expose fragmented MP4 as an output format, so this needs a separate muxer and larger native/repair surface. |
| Hybrid: authoritative ADTS/index plus derived M4A | Same recovery properties as the ADTS authority. | Five-minute authoritative files with sub-five-second commit records. | Application playback may use a rebuilt M4A or a segment-aware player; both require device proof. | Derived and safely replaceable; merge failure never invalidates ADTS. | Preferred hypothesis, not a decision. Select only if all device gates below pass. |

Android documents that `MediaMuxer` writes conventional output formats such as
MP4, WebM, 3GP, HEIF, and Ogg and that clients must not use the output file
before `stop()` completes. It also requires samples to be written in
chronological order. See the official
[`MediaMuxer` API reference](https://developer.android.com/reference/android/media/MediaMuxer).
AAC output configuration data and media timestamps must be handled according
to the official
[`MediaCodec` API reference](https://developer.android.com/reference/android/media/MediaCodec).
Local rebuilt files can be inspected through the APIs described by
[`MediaExtractor`](https://developer.android.com/reference/android/media/MediaExtractor).

The Android references do not guarantee that an arbitrary truncated ADTS file
is durable, gap-free, or accepted uniformly by device codecs. Those properties
are hypotheses to verify, not platform promises.

## Provisional commit protocol to test

1. Feed PCM to one configured AAC-LC encoder and keep codec configuration data
   separately in the segment manifest.
2. Append complete encoded AAC access units with ADTS headers to the current
   authoritative logical-segment file.
3. After no more than 78 AAC frames, flush and `fsync` the ADTS file.
4. Atomically persist and sync a commit record containing segment identity,
   first/last frame sequence, byte end offset, cumulative sample count, media
   start/end, and a checksum for the committed byte range.
5. On recovery, trust only the intersection of a valid complete-frame prefix
   and the latest valid committed byte offset. Ignore or quarantine a trailing
   partial frame or uncommitted complete frames.
6. Rotate after 60 commit groups (299.52 seconds) and atomically publish the
   next logical segment identity.
7. Build continuous M4A as derived data by assigning timestamps from cumulative
   sample counts, not wall-clock arrival time.

This ordering deliberately prefers losing a final uncommitted group over
claiming bytes durable when the manifest is not durable. The exact atomic-write
and directory-sync behavior must be demonstrated on the target filesystem.

## Physical-device acceptance matrix

The candidate cannot be selected until a connected, fingerprinted target
device produces the following evidence:

- AAC-LC 16 kHz mono 64 kbit/s encoder discovery, configure/start success,
  encoder identity, codec configuration data, and a decoded quality fixture.
- Clean captures and controlled termination at 0.5 s, 4.8 s, 5.1 s, a commit
  boundary, a logical-segment boundary, and finalization.
- Process kill, force-stop, and file-tail truncation repeated at each offset.
- Recovered duration calculated from decoded samples; maximum missing media
  must be at most five seconds and all earlier committed groups must decode.
- PCM/reference and decoded-output comparison, plus manual listening for
  clicks, gaps, duplicates, or reordered audio at every boundary.
- Successful deterministic M4A rebuild, `MediaExtractor` timestamp inspection,
  complete playback, and duration agreement with cumulative AAC samples.
- Four-hour file-count, byte-overhead, manifest-growth, sync-latency, CPU,
  memory, thermal, battery, underrun, and input-overflow measurements.
- Artificial inference stalls while the canonical path records continuously;
  AI work may be dropped but canonical PCM/AAC sequence numbers and decoded
  samples must remain continuous.

Any unexplained corruption, missing committed group, loss above five seconds,
or capture back-pressure rejects the candidate. If 64 kbit/s AAC quality or
availability fails, the OpenSpec design and requirements must be updated before
selecting another production format or bitrate.

## Host evidence and limitations

The JVM spike currently verifies only:

- exact payload arithmetic for four-hour PCM, AAC 64 kbit/s, and AAC 32 kbit/s;
- a 78-frame/4.992-second commit plan and 60-commit/299.52-second logical plan;
- recovery of the last complete ADTS-frame prefix from synthetic bytes; and
- non-blocking capture publication to an isolated canonical worker while a
  full optional-inference queue drops only derived work; canonical overload or
  sink failure is reported explicitly in the host harness.

It does not encode microphone audio, prove Android filesystem durability,
measure audio quality, validate actual ADTS produced by a device codec, prove
gap-free playback, or produce a valid final M4A. No selection follows from the
host evidence alone.
