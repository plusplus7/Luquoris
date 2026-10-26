# Experimental Whisper small comparison

On 2026-10-14, an opt-in debug build selected multilingual
`whisper-small-q5_1` for both live requests and complete post-session passes.
The approved base model remains the default for builds without the flag.
Neither the production package nor existing original recordings was replaced.

## Physical-device observations

The paired `WhisperModelComparisonInstrumentedTest` passed on the Redmi
M2104K10AC / `chopin`, Android 13, with `whisper.cpp` 1.9.4. Both models received
the exact same authorized 45-second, 16 kHz mono PCM fixture and the `mixed`
language hint. The raw result is `whisper-small-comparison.json` alongside
this document.

| Model | Weight bytes | Context load | Inference | RTF |
| --- | ---: | ---: | ---: | ---: |
| base-q5_1 | 59,707,625 | 119 ms | 24,643 ms | 0.548 |
| small-q5_1 | 190,085,487 | 272 ms | 70,824 ms | 1.574 |

Small took approximately 2.87 times as long. Its RTF above 1 means it does not
keep up with incoming speech on this device in this single measurement.
Prefer post-session transcription when testing this candidate; the bounded live
path retains its existing degradation and complete-pass fallback.

Output examples include base's `流过两` versus small's `刘国良`, base's
`把一堆节散的那天` versus small's `八一队解散的那天`, and base's `烈痕` versus
small's `裂痕`. These illustrate improved readability, not a measured accuracy
score. Small still emits malformed phrases and transcription errors, including
`凡正东`. No human reference transcript was available for CER/WER scoring.
The observed text is Chinese; this run does not establish English or code-switch
accuracy, regardless of the fixture catalog's broader language labels.

Both runs produced monotonic segments and released all context, run, and result
handles. The debug APK SHA-256 was
`16f5ba89e52527ec4f34501683f2e2c9c7a5a3cd75e258570f754a1f51f4aab8`.
The fixture SHA-256 was
`83440d4ccbd82dafd1a88346ab448e1dd309e408c598d665413b910cc92c40a7`.

## Reproduction

Download and import the pinned weights following `models/README.md`, then:

```sh
flutter build apk --debug --dart-define=LOQUIRIS_EXPERIMENTAL_SMALL=true
cd android
./gradlew :app:testDebugUnitTest :app:assembleDebugAndroidTest \
  -Pdart-defines=TE9RVUlSSVNfRVhQRVJJTUVOVEFMX1NNQUxMPXRydWU=
cd ..
adb install -r -t build/app/outputs/flutter-apk/app-debug.apk
adb install -r -t build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb shell am instrument -w -r \
  -e class com.loquiris.transcription.WhisperModelComparisonInstrumentedTest \
  com.loquiris.debug.test/androidx.test.runner.AndroidJUnitRunner
adb shell run-as com.loquiris.debug \
  cat files/device-validation/whisper-small-comparison.json
```

The explicit Base64 argument encodes `LOQUIRIS_EXPERIMENTAL_SMALL=true` and keeps
the test and app native model selection consistent with Flutter.

## Verification and acceptance boundary

- 52 focused Flutter transcription, bootstrap, native-channel, and import tests passed.
- 19 experimental selection, catalog, import, and release privacy tests passed.
- All 306 Android JVM unit tests passed with small selected.
- Physical paired comparison passed: `OK (1 test)`.
- Flutter static analysis and changed-file formatting checks passed.
- The production model guard rejected the experimental catalog and flag with
  `experimental_transcription_model_debug_only`.
- After the normal base import, the production model guard passed. The local
  generated asset tree was left in that normal base state; the built and installed
  debug APK still contains and selects small.

This is a development experiment, not production model acceptance. There is no
held-out accuracy score, repeated latency distribution, sustained energy/thermal
measurement, or continuously sampled peak memory evidence. Production approval
and independent redistribution review remain required by `MODEL_ACCEPTANCE.md`.
