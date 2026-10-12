# Recoverable AAC Storage Candidates

## Decision status

The selected Phase 6 implementation design is append-only ADTS AAC-LC plus a
checksummed commit journal and directory-synced atomic manifest, with a derived
M4A rebuilt after capture. This document records the comparison and evidence on
the selected Redmi Note 10 Pro (`M2104K10AC`/`chopin`, 6GB+128GB class). Tasks
5.4 and 5.5 have physical-
device evidence. A deterministic workflow has also continuously encoded 304
seconds of PCM, persisted two actual ADTS/journal segment files behind an
atomically replaced manifest, recovered them, and rebuilt a continuous M4A
across the 4,650-frame split. Tasks 5.2 and 5.3 are complete: objective quality,
human listening, recovery, playback, and final mux checks passed. Selection
authorizes implementation, not release: physical power removal, exact-rotation
death, production integration, and later long-run gates remain explicit limits.

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

At 16 kHz, an AAC-LC frame represents 1,024 samples, or 64 ms. The reviewed
commit interval is 75 frames, or 4.8 seconds, reserving at least 100 ms of the
five-second gate after measured sync time. Sixty-two commit groups represent
4,650 frames or 297.6 seconds, close to one five-minute logical segment. These
values replace the rejected 78-frame plan, whose 4.992-second media interval
left inadequate margin for sync and scheduling delay.

## Candidate comparison

| Candidate | Short durable commits | Five-minute logical segmentation | Gap-free playback | Final M4A | Assessment before device testing |
|---|---|---|---|---|---|
| One long M4A written by `MediaMuxer` | Weak. The active file is not safe to consume until `stop()` completes. | Natural as one file, but the active container is a large failure domain. | Standard player behavior after clean finalization. | Already M4A after a clean stop. | Reject as the authoritative active recording. It can remain a derived final artifact. |
| Standalone M4A file per commit (at most 5 s) | Stronger once every tiny file is stopped, synced, and its manifest entry committed. | 3,000 files for four hours at 4.8 s per file, unless hidden behind a second grouping layer. | Must measure encoder delay/padding and timestamp continuity at every boundary. | Requires remux/rebuild from thousands of inputs. | Retain as a fallback experiment, not the preferred design. File count, finalization overhead, and gapless risk are high. |
| Standalone M4A per logical segment (about 5 min) | Weak without an additional fragment/journal scheme; abrupt loss can approach the active segment length. | Direct match. | Standard after each segment finalizes; boundaries still require measurement. | Straightforward remux after clean segment finalization. | Reject by itself because it cannot satisfy the five-second loss requirement. |
| Append-only ADTS AAC plus durable commit index | Promising. Complete frame prefixes can be found after a truncated tail; the index can expose only synced commit boundaries. | Rotate an authoritative ADTS file after 62 commit groups, while keeping commit records inside each logical segment. | Target-device full decode, player probes, and complete human playback across both commit and logical-segment boundaries passed. | Rebuild by parsing frames, deriving monotonic sample timestamps, supplying AAC codec configuration, and muxing into a new M4A. | Leading candidate. Target-device continuous encoding, file/manifest/directory sync ordering, remux/extract, full decoder coverage, player probes, and human playback passed. Physical power removal and process death at the exact rotation instruction remain broader fault-injection limits. |
| Fragmented MP4 | Potentially strong if every fragment is independently durable. | Possible. | Potentially good with correct fragment timestamps. | Already an ISO-BMFF family artifact or remuxable. | Do not select for the MVP spike. Android `MediaMuxer` does not expose fragmented MP4 as an output format, so this needs a separate muxer and larger native/repair surface. |
| Hybrid: authoritative ADTS/index plus derived M4A | Same recovery properties as the ADTS authority. | Five-minute authoritative files with sub-five-second commit records. | Selected-target full decode, platform probes, and human playback passed. | Derived and safely replaceable; merge failure never invalidates ADTS. | Selected for Phase 6 implementation. Release remains gated by production integration and long-run evidence. |

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
3. After no more than 75 AAC frames, flush and `fsync` the ADTS file.
4. Atomically persist and sync a commit record containing segment identity,
   first/last frame sequence, byte end offset, cumulative sample count, media
   start/end, and a checksum for the committed byte range.
5. On recovery, trust only the intersection of a valid complete-frame prefix
   and the latest valid committed byte offset. Ignore or quarantine a trailing
   partial frame or uncommitted complete frames.
6. Rotate after 62 commit groups (297.6 seconds) and atomically publish the
   next logical segment identity.
7. Build continuous M4A as derived data by assigning timestamps from cumulative
   sample counts, not wall-clock arrival time.

This ordering deliberately prefers losing a final uncommitted group over
claiming bytes durable when the manifest is not durable. The exact atomic-write
and directory-sync ordering was demonstrated on the selected target filesystem;
it remains an invariant for the production implementation.

## Physical-device gates

### Phase 5 implementation-selection gate — PASS

The connected, fingerprinted target produced the bounded evidence required to
choose an implementation design:

- actual AAC-LC 16 kHz mono encoder configuration, objective real-speech
  round-trip metrics, and complete human listening;
- authentic file-tail and journal truncation plus repeated process-kill and
  force-stop recovery, with a worst measured media-plus-sync window of
  4.800739 seconds and all earlier committed groups decodable;
- 4.8-second commits, a 297.6-second logical boundary, unpublished-rotation
  rejection, atomic manifest replacement, and three successful parent-directory
  syncs on the target filesystem;
- deterministic M4A rebuild, exact payload/timestamp inspection, full fresh
  decode coverage, platform player probes, duration agreement, and complete
  human playback; and
- artificial inference stalls while the canonical encoder path remained
  continuous and only optional work was dropped.

Any unexplained corruption, missing committed group, loss above five seconds,
or canonical capture back-pressure in this spike scope would have rejected the
candidate. No such failure remained after the documented fixes and reruns.

### Recorder release gate — NOT YET EVALUATED

Phase 6/7/15 must still verify the production implementation rather than inherit
the spike result. Required evidence includes:

- real `AudioRecord` capture and controlled termination across the complete
  offset matrix, including the exact logical-rotation instruction;
- physical power-loss coverage where the test environment can safely provide it;
- four-hour file-count, byte-overhead, manifest-growth, sync-latency, CPU,
  memory, thermal, battery, underrun, and input-overflow measurements; and
- the complete background, lock-screen, interruption, low-power, low-storage,
  recovery, and repeated release matrix defined in phases 7 and 15.

Release remains rejected by any unexplained corruption, missing committed
group, loss above five seconds, or capture back-pressure. If production AAC
quality or availability differs from the spike, the OpenSpec design and
requirements must be updated before selecting another format or bitrate.

## Recorded evidence and limitations

The JVM and selected-target spikes now verify:

- exact payload arithmetic for four-hour PCM, AAC 64 kbit/s, and AAC 32 kbit/s;
- the reviewed 75-frame/4.8-second commit plan and 62-commit/297.6-second
  logical plan;
- recovery of the last complete ADTS-frame prefix from synthetic bytes; and
- repeated authentic `MediaCodec` kill, force-stop, and controlled-truncation
  recovery with a maximum measured 4.800739-second media-plus-sync risk window;
- non-blocking capture publication to an isolated canonical worker while a
  full optional-inference queue drops only derived work; canonical overload or
  sink failure is reported explicitly in the host harness; and
- one continuous 304-second / 4,864,000-sample PCM encode on the selected
  target, producing 4,750 authentic AAC access units in 40.042 seconds. The
  first authoritative file contains 4,650 frames and 62 durable commits; the
  second contains 100 frames and two commits. All codec-specific-data buffers
  and both segments are discovered through the reloaded manifest, recover
  4,650 + 100 payloads, validate 4,761,600 + 102,400 committed-sample
  watermarks, and match the encoded timeline byte-for-byte. An injected next
  segment containing an uncommitted frame is ignored while absent from the
  published manifest. `MediaExtractor` then returns all 4,750 M4A payloads;
  every PTS matches cumulative sample arithmetic, container and fresh-decoder
  sample coverage are both 1.0, and the rebuilt file is 2,454,905 bytes.
- Android `MediaPlayer` reports the rebuilt duration as 304,000 ms and, muted,
  completes seek plus playback-clock advancement at 0, 4.8, 297.6, and 302
  seconds. A separate complete human playback pass reported no audible anomaly.
- Manifest publication now syncs the temporary file, atomically replaces the
  manifest, then opens and `fsync`s the parent directory. A fresh selected-
  target run recorded all three expected directory syncs while preserving the
  4,650+100-frame recovered timeline.
- One explicitly authorized 302.741-second real-speech fixture decoded from
  48 kHz stereo, downmixed to 16 kHz mono, and round-tripped through the target
  `c2.android.aac.encoder`/decoder with a requested 64 kbit/s bitrate. Actual
  encoder AudioSpecificConfig `1408` parsed as AOT 2 (AAC-LC), 16 kHz, mono.
  The rebuilt M4A contains 4,730 access units / 2,421,821 encoded payload bytes.
  Delay-aligned comparison
  measured 99.9507% reference coverage, 0.999930 decoded/reference sample
  ratio, 0.999023 correlation, and 26.864 dB SNR. This is objective evidence
  from one private fixture, not a listening panel, ASR result, or broad quality
  claim. The user listened to the complete exported fixture and reported no
  discontinuity, repetition, click, incomplete playback, or obvious distortion.

It still does not simulate physical power removal or actual process death at
the exact logical-rotation instruction, and it does not establish four-hour
overhead/stability. File, manifest, and parent-directory sync ordering plus
complete human playback have passed on the selected target. The rebuilt M4A is
retained as test output for manual playback.
No release approval follows from the implementation selection. The later
production and long-run gates remain mandatory without weakening the five-second
loss requirement.
