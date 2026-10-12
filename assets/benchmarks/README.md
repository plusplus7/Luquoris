# Fixed first-run benchmark audio

`audio/zh_en_mixed_v1.wav` is the immutable 45-second input for the
on-device first-run performance check. It contains human-verified Mandarin,
English, and code-switched speech. It is not an accuracy acceptance corpus and
does not replace the held-out 30-minute language sets required by the physical
device validation plan.

`audio/manifest.json` records the source digest and media properties, exact
excerpt, deterministic conversion command, derived digest, language coverage,
authorization, consent, and license. The original five-minute contributor
recording is intentionally not committed.

The contributor confirmed on 2026-10-01 that they own the recording and that
every identifiable speaker authorized publication, modification, commercial
use, and redistribution of the selected excerpt under CC0-1.0. The unmodified
official legal text is retained at `licenses/CC0-1.0.txt`.

Do not replace or edit the WAV, manifest, or license snapshot without updating
the provenance and integrity test in the same reviewed change.
