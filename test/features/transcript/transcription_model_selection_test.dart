import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:loquiris/features/transcript/application/transcription_parameters.dart';

void main() {
  test('only the build-selected model can back native transcription', () async {
    final base = await _manifest('models/manifests/whisper-base-q5_1.json');
    final small = await _manifest(
      'models/manifests/experimental-small/whisper-small-q5_1.json',
    );
    expect(
      isSupportedTranscriptionManifest(base),
      !experimentalSmallTranscriptionModel,
    );
    expect(
      isSupportedTranscriptionManifest(small),
      experimentalSmallTranscriptionModel,
    );
    expect(
      transcriptionModelId,
      experimentalSmallTranscriptionModel ? small.id : base.id,
    );
  });

  test(
    'experimental comparison retains the exact approved base manifest',
    () async {
      final approved = jsonDecode(
        await File('models/manifests/whisper-base-q5_1.json').readAsString(),
      );
      final comparison = jsonDecode(
        await File(
          'models/manifests/experimental-small/whisper-base-q5_1.json',
        ).readAsString(),
      );
      expect(comparison, approved);
    },
  );
}

Future<BundledModelManifest> _manifest(String path) async {
  final parsed = BundledModelManifest.tryParse(
    jsonDecode(await File(path).readAsString()),
  );
  expect(parsed, isA<Ok<BundledModelManifest, InvalidModelManifest>>());
  return (parsed as Ok<BundledModelManifest, InvalidModelManifest>).value;
}
