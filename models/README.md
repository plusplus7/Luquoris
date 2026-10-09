# Offline model inputs

Large model weights are local build inputs and must not be committed. The
repository keeps only reviewable manifests and exact license snapshots.

## Add a model

1. Add `models/manifests/<model-id>.json` conforming to
   `tool/model_manifest/model_manifest.schema.json`.
2. Add the reviewed license text at the manifest's
   `license.snapshotPath`, beneath `models/licenses/`.
3. Put the exact artifact bytes at
   `models/local/<model-id>/<artifact-filename>`. The filename must match the
   basename of the manifest's `artifactPath`. The entire `models/local/` tree
   is ignored by Git.
4. From the repository root, run:

   ```sh
   dart run tool/import_models.dart
   ```

To calculate manifest values without copying model contents into logs:

```sh
wc -c < models/local/<model-id>/<artifact-filename>
shasum -a 256 models/local/<model-id>/<artifact-filename>
```

The importer performs no downloads. It validates every manifest, artifact
length, SHA-256 digest, license snapshot, duplicate identifier, and destination
path before publishing anything. Successful output is written atomically to
`build/generated/model_assets/`, which is also ignored by Git. A failed run
leaves the previous generated tree unchanged and reports only a stable failure
code plus an optional model identifier.

The generated tree contains the verified artifacts at their declared
`artifactPath`, copied license snapshots, normalized manifest filenames, and a
deterministic `model_manifests/index.json`. Android asset wiring is intentionally
separate and should consume only this generated tree.

## Reviewed Whisper base-q5 input

The first transcription spike uses the exact multilingual
`ggml-base-q5_1.bin` object declared by
`models/manifests/whisper-base-q5_1.json`. Fetch that immutable revision into
the ignored local-input tree:

```sh
hf download ggerganov/whisper.cpp ggml-base-q5_1.bin \
  --revision f281eb45af861ab5e5297d23694b7d46e090c02c \
  --local-dir models/local/whisper-base-q5_1
```

Before import, verify both values from the committed manifest:

```sh
wc -c < models/local/whisper-base-q5_1/ggml-base-q5_1.bin
shasum -a 256 models/local/whisper-base-q5_1/ggml-base-q5_1.bin
dart run tool/import_models.dart
```

The expected byte count is `59707625` and the expected SHA-256 is
`422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898`.
Do not replace the pinned revision with `main`, `latest`, or an unreviewed
mirror. The generated asset is a build input; runtime downloading remains
prohibited.
