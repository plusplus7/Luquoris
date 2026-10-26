# Candidate provenance investigation — not model selection

Observed 2026-10-14. Task 2.1 remains incomplete: these are immutable discovery
pins, not verified imported bundles, measured runtime compatibility, fixed
complete decoding configurations, or approved redistribution decisions. No
candidate files are added to production inputs. Model-card license metadata
must not substitute for independent weight/tokenizer/configuration review.

## Runtime discovery pin

- sherpa-onnx `v1.13.8`, commit
  `11afbd009a7f8c08f4bcf2fc1b265d0df4670fbf`.
- [Pinned runtime license](https://github.com/k2-fsa/sherpa-onnx/blob/11afbd009a7f8c08f4bcf2fc1b265d0df4670fbf/LICENSE):
  Apache-2.0. This is the runtime license, not a weight license.
- Published Android archive `sherpa-onnx-v1.13.8-android.tar.bz2`, 46,093,321
  bytes, release-published SHA-256
  `2ff63469a71cb6009aa2e3ed5f4a670f8abdcbe4bb9ffd23776afc792a6b4f44`.
  Archive has not been downloaded, unpacked, or independently hashed here.
- [Pinned ARM64 dependency configuration](https://github.com/k2-fsa/sherpa-onnx/blob/11afbd009a7f8c08f4bcf2fc1b265d0df4670fbf/cmake/onnxruntime-android-aarch64.cmake)
  references ONNX Runtime Android 1.28.2 with archive SHA-256
  `01518867f78241138b6aa25925802e843a4fa9085af8d303d49e35bbb52aff4d`.
  Its separate dependency/notice/license audit and archive-build correspondence
  are not complete. Build-time dependency fetches must never become runtime
  downloads; the current app has not integrated this dependency.

## Compact Zipformer discovery pin

[Repository](https://huggingface.co/csukuangfj/k2fsa-zipformer-bilingual-zh-en-t/tree/e2382758de9a0219b4efe682b95af30b399db3b8),
revision `e2382758de9a0219b4efe682b95af30b399db3b8`. The pinned model card declares
Apache-2.0, describes character+BPE units, and identifies a fork of
`pfluo/k2fsa-zipformer-chinese-english-mixed`. That parent's current discovery
revision is `6eb615ae77ecac05c5628d5c8ed7037c14a338d5`; the exact fork-parent
revision used for these weights is not established by the card.

| Relative source file | Bytes | SHA-256 |
|---|---:|---|
| exp/32/encoder-epoch-99-avg-1.int8.onnx | 42980793 | db6f51551762e40e549166fe041ea3e45464370b595e9ad23f06478ec3794fbb |
| exp/32/decoder-epoch-99-avg-1.int8.onnx | 3486740 | 4b618d383af304cfae281dbf0a53e8bf442c2f0502256cd5694bd6567ebdd834 |
| exp/32/joiner-epoch-99-avg-1.int8.onnx | 3228485 | bdda356d6f9b8c2d7cee9ee0e26075fa537490f7fd06520be408d287073667b9 |
| data/lang_char_bpe/tokens.txt | 56317 | a8e0e4ec53810e433789b54a5c0134a7eaa2ffca595a6334d54c00da858841d3 |
| data/lang_char_bpe/bpe.model | 244836 | bcae393dbc5611be5ffa4c7ae0841558978a5a4f484008cb9dff3a2cc97ebe01 |

ONNX/BPE lengths and hashes above come from pinned Hugging Face LFS metadata,
not a local weight verification. `tokens.txt` was fetched at that exact revision
and hashed locally. Pinned README SHA-256:
`037edf8e561cff512493746532af04f5c40cb6fbc55d3e360a399215b6b0b915`.
Required runtime artifact set, configuration, endpoint behavior, and timestamp
mapping still require the integration spike. No accuracy or latency claim.

## Streaming Paraformer discovery pin

[Repository](https://huggingface.co/csukuangfj/streaming-paraformer-zh/tree/2db94bce7ce81909a08fb3142c71086f489e7e16),
revision `2db94bce7ce81909a08fb3142c71086f489e7e16`. Pinned card declares Apache-2.0
and identifies conversion from ModelScope
`damo/speech_paraformer_asr_nat-zh-cn-16k-common-vocab8404-online` but does not
identify that source's exact revision. Pinned README SHA-256:
`1ef67f0cb23618fd34d184f0be884884706e68bfc27f374bbbdd0448378a8a61`.

| Relative source file | Bytes | SHA-256 |
|---|---:|---|
| model_quant.onnx | 165450769 | 00b5f90549fff9f0b2a20a4c2ccf1b2335a3adb533f648ee768f79b29b777ce2 |
| decoder_quant.onnx | 71664561 | f3cca9f77bb9d93c8fcbfb63ae617b6b1ee96818df3aa3b151c40658fe38594f |
| tokens.txt | 34846 | fca8b98b28803e4235d6cd630e3666232bf55d3a34032c1cd7568c331ac213cd |

ONNX lengths/hashes are LFS metadata only; tokenizer bytes were fetched and
hashed locally. [The runtime's model documentation](https://k2-fsa.github.io/sherpa/onnx/pretrained_models/online-paraformer/paraformer-models.html)
describes bilingual streaming Paraformer but warns that the model does not
provide timestamps. Utterance capture-time mapping therefore needs an explicit
tested adapter; inferred wall-time timestamps cannot satisfy the spec. Exact
mapping from the conversion repository to the published runtime-ready archive
has not been verified. Alternative eligibility is not yet granted.

## Decisions and outstanding inputs

Runtime, ONNX Runtime, converted weights, upstream weights, tokenizers and local
configuration each need separate fixed provenance/terms records. None has
production redistribution approval in this change. Do not import these
discovery records as manifest-v2 bundles: their configuration/license snapshots
and byte verification are incomplete.

No target phone is currently reachable (`adb devices -l` empty), and no supplied
held-out human-verified three-stratum corpus is available. Neither discovery
pins nor the earlier Chinese-only smoke outputs can select or qualify a pair.
