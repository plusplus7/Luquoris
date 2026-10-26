import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';

import '../../support/model_bundle_fixture.dart';

void main() {
  test('catalog aliases bind only an exact complete model projection', () {
    final profile =
        (ProcessingModelProfile.tryCreate(
                  bundleManifestJson: jsonEncode(modelBundleFixture()),
                  engineVersion: '1.0.0',
                  parametersJson: '{"parameterVersion":1}',
                )
                as Ok<ProcessingModelProfile, InvalidProcessingSelection>)
            .value;
    final model = profile.manifest.toInstalledModel();
    for (final changed in [
      model.copyWith(source: 'different'),
      model.copyWith(version: 'different'),
      model.copyWith(bytes: model.bytes + 1),
      model.copyWith(licenseId: 'different'),
      model.copyWith(expectedEngineId: 'different'),
      model.copyWith(sha256: 'b' * 64),
      model.copyWith(
        licenseSnapshotPath:
            (AppRelativePath.tryParse('models/other.txt')
                    as Ok<AppRelativePath, InvalidAppRelativePath>)
                .value,
      ),
      model.copyWith(capabilities: []),
      model.copyWith(enabledModes: []),
    ]) {
      expect(
        profile.bindToInstalledModel(changed),
        isA<Err<InferenceProvenance, InvalidProcessingSelection>>(),
      );
    }
    final alias = InstalledModel(
      id: 'restored',
      version: model.version,
      source: model.source,
      sha256: model.sha256,
      bytes: model.bytes,
      capabilities: model.capabilities,
      expectedEngineId: model.expectedEngineId,
      licenseId: model.licenseId,
      licenseSnapshotPath: model.licenseSnapshotPath,
      enabledModes: model.enabledModes,
    );
    final bound =
        profile.bindToInstalledModel(alias)
            as Ok<InferenceProvenance, InvalidProcessingSelection>;
    expect(bound.value.modelId, 'restored');
    expect(bound.value.parametersJson, profile.parametersJson);
    expect(profile.provenance.modelId, 'test-bundle');
  });
  test(
    'independent live and refinement snapshots retain exact role provenance',
    () {
      final live = _profile(jsonEncode(modelBundleFixture()), '1.0.0');
      final refinement = _profile(
        File('models/manifests/whisper-base-q5_1.json').readAsStringSync(),
        '1.9.4',
      );
      final selection = MeetingProcessingSelection.twoPass(
        live: live,
        refinement: refinement,
      );
      expect(selection.mode, MeetingProcessingMode.twoPass);
      expect(selection.live!.manifest.engineId, 'test-streaming');
      expect(selection.refinement!.manifest.engineId, 'whisper_cpp');
      expect(selection.live!.provenance.engineVersion, '1.0.0');
      expect(selection.refinement!.provenance.engineVersion, '1.9.4');
      expect(selection.live!.bundleManifestJson, live.bundleManifestJson);
      expect(
        selection.refinement!.bundleManifestJson,
        refinement.bundleManifestJson,
      );
      expect(const MeetingProcessingSelection.recordingOnly().live, isNull);
      expect(
        const MeetingProcessingSelection.recordingOnly().refinement,
        isNull,
      );
      expect(
        MeetingProcessingSelection.postSession(refinement: refinement).live,
        isNull,
      );
    },
  );

  test(
    'canonical parameters fix key order without changing lexical values',
    () {
      final snapshot = jsonEncode(modelBundleFixture());
      final first = _profile(
        snapshot,
        '1.0.0',
        parameters: '{ "z": {"b":2,"a":"臺灣 ONNX 01"}, "parameterVersion":1 }',
      );
      final second = _profile(
        snapshot,
        '1.0.0',
        parameters: '{"parameterVersion":1,"z":{"a":"臺灣 ONNX 01","b":2}}',
      );
      expect(first, second);
      expect(
        first.parametersJson,
        '{"parameterVersion":1,"z":{"a":"臺灣 ONNX 01","b":2}}',
      );
      expect(first.parameterVersion, 1);
      expect(first.provenance.parametersJson, first.parametersJson);
    },
  );

  test(
    'unreadable, mutable, or incompatible profiles never enter a selection',
    () {
      final valid = jsonEncode(modelBundleFixture());
      for (final (snapshot, runtime, parameters) in [
        ('bad', '1.0.0', '{"parameterVersion":1}'),
        ('{"schemaVersion":2}', '1.0.0', '{"parameterVersion":1}'),
        (valid, '', '{"parameterVersion":1}'),
        (valid, 'different', '{"parameterVersion":1}'),
        (valid, '1.0.0', '{}'),
        (valid, '1.0.0', '[]'),
        (valid, '1.0.0', '{"parameterVersion":1.0}'),
        (valid, '1.0.0', '{"parameterVersion":0}'),
        (valid, '1.0.0', '{"parameterVersion":true}'),
      ]) {
        expect(
          ProcessingModelProfile.tryCreate(
            bundleManifestJson: snapshot,
            engineVersion: runtime,
            parametersJson: parameters,
          ),
          isA<Err<ProcessingModelProfile, InvalidProcessingSelection>>(),
        );
      }
    },
  );
}

ProcessingModelProfile _profile(
  String snapshot,
  String runtime, {
  String parameters = '{"parameterVersion":1}',
}) {
  final parsed = ProcessingModelProfile.tryCreate(
    bundleManifestJson: snapshot,
    engineVersion: runtime,
    parametersJson: parameters,
  );
  expect(parsed, isA<Ok<ProcessingModelProfile, InvalidProcessingSelection>>());
  return (parsed as Ok<ProcessingModelProfile, InvalidProcessingSelection>)
      .value;
}
