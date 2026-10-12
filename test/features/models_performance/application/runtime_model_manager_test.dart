import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/application/runtime_model_manager.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:loquiris/features/recording/presentation/new_recording_controller.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../../../support/fakes/fake_services.dart';

void main() {
  group('RuntimeModelManager', () {
    test('lists declared models in stable identifier order', () async {
      final manager = RuntimeModelManager(
        manifests: <BundledModelManifest>[
          _manifest(id: 'zeta-model'),
          _manifest(id: 'alpha-model'),
        ],
        artifactSource: _MemoryModelArtifactSource(),
      );

      final result = await manager.listInstalled();

      expect(result, isA<Ok<ModelInventory, ModelFailure>>());
      final inventory = (result as Ok<ModelInventory, ModelFailure>).value;
      expect(
        inventory.models.map((model) => model.id),
        <String>['alpha-model', 'zeta-model'],
      );
    });

    test('verifies exact bytes from a chunked artifact stream', () async {
      final source = _MemoryModelArtifactSource()
        ..artifacts['models/test-model/model.bin'] = () => Stream.fromIterable(
          const <List<int>>[
            <int>[1],
            <int>[2, 3],
          ],
        );
      final manager = RuntimeModelManager(
        manifests: <BundledModelManifest>[_manifest()],
        artifactSource: source,
      );

      final result = await manager.verify('test-model');

      expect(
        result,
        isA<Ok<ModelDescriptor, ModelFailure>>().having(
          (success) => success.value.id,
          'model id',
          'test-model',
        ),
      );
    });

    test('keeps the caller isolate responsive while hashing', () async {
      final heartbeat = Completer<void>();
      var verificationCompleted = false;
      late StreamController<List<int>> controller;
      controller = StreamController<List<int>>(
        sync: true,
        onListen: () {
          Timer.run(heartbeat.complete);
          controller.add(const <int>[1, 2, 3]);
          unawaited(controller.close());
        },
      );
      final source = _MemoryModelArtifactSource()
        ..artifacts['models/test-model/model.bin'] = () => controller.stream;
      final manager = RuntimeModelManager(
        manifests: <BundledModelManifest>[_manifest()],
        artifactSource: source,
      );

      final verification = manager.verify('test-model').then((result) {
        verificationCompleted = true;
        return result;
      });
      await heartbeat.future;

      expect(verificationCompleted, isFalse);
      expect(await verification, isA<Ok<ModelDescriptor, ModelFailure>>());
    });

    test('rejects an identifier absent from the immutable catalog', () async {
      final manager = RuntimeModelManager(
        manifests: <BundledModelManifest>[_manifest()],
        artifactSource: _MemoryModelArtifactSource(),
      );

      final result = await manager.verify('undeclared-model');

      _expectFailure(result, 'model_not_declared');
    });

    test('maps a missing artifact to a path-free failure', () async {
      final manager = RuntimeModelManager(
        manifests: <BundledModelManifest>[_manifest()],
        artifactSource: _MemoryModelArtifactSource(),
      );

      final result = await manager.verify('test-model');

      _expectFailure(result, 'model_artifact_missing');
    });

    test(
      'rejects a stream whose byte length differs from the manifest',
      () async {
        final source = _MemoryModelArtifactSource()
          ..artifacts['models/test-model/model.bin'] = () =>
              Stream.value(const <int>[1, 2]);
        final manager = RuntimeModelManager(
          manifests: <BundledModelManifest>[_manifest()],
          artifactSource: source,
        );

        final result = await manager.verify('test-model');

        _expectFailure(result, 'model_bytes_mismatch');
      },
    );

    test('rejects same-length bytes whose SHA-256 differs', () async {
      final source = _MemoryModelArtifactSource()
        ..artifacts['models/test-model/model.bin'] = () =>
            Stream.value(const <int>[1, 2, 4]);
      final manager = RuntimeModelManager(
        manifests: <BundledModelManifest>[_manifest()],
        artifactSource: source,
      );

      final result = await manager.verify('test-model');

      _expectFailure(result, 'model_sha256_mismatch');
    });

    test('contains artifact stream exceptions as stable failures', () async {
      final source = _MemoryModelArtifactSource()
        ..artifacts['models/test-model/model.bin'] = () =>
            Stream<List<int>>.error(StateError('private path'));
      final manager = RuntimeModelManager(
        manifests: <BundledModelManifest>[_manifest()],
        artifactSource: source,
      );

      final result = await manager.verify('test-model');

      _expectFailure(result, 'model_artifact_unreadable');
    });

    test(
      'a corrupt model does not poison an independent healthy model',
      () async {
        final source = _MemoryModelArtifactSource();
        source.artifacts['models/broken-model/model.bin'] = () =>
            Stream.value(const <int>[1, 2, 4]);
        source.artifacts['models/healthy-model/model.bin'] = () =>
            Stream.value(const <int>[1, 2, 3]);
        final manager = RuntimeModelManager(
          manifests: <BundledModelManifest>[
            _manifest(id: 'broken-model'),
            _manifest(id: 'healthy-model'),
          ],
          artifactSource: source,
        );

        final broken = await manager.verify('broken-model');
        final healthy = await manager.verify('healthy-model');

        _expectFailure(broken, 'model_sha256_mismatch');
        expect(healthy, isA<Ok<ModelDescriptor, ModelFailure>>());
      },
    );

    test(
      'duplicate identifiers fail closed without hiding healthy models',
      () async {
        final source = _MemoryModelArtifactSource()
          ..artifacts['models/healthy-model/model.bin'] = () =>
              Stream.value(const <int>[1, 2, 3]);
        final manager = RuntimeModelManager(
          manifests: <BundledModelManifest>[
            _manifest(id: 'duplicate-model'),
            _manifest(id: 'duplicate-model'),
            _manifest(id: 'healthy-model'),
          ],
          artifactSource: source,
        );

        final inventory = await manager.listInstalled();
        final duplicate = await manager.verify('duplicate-model');
        final healthy = await manager.verify('healthy-model');

        expect(inventory, isA<Err<ModelInventory, ModelFailure>>());
        _expectFailure(duplicate, 'model_manifest_duplicate');
        expect(healthy, isA<Ok<ModelDescriptor, ModelFailure>>());
      },
    );
  });

  test('a corrupt AI model never blocks canonical recording startup', () async {
    final source = _MemoryModelArtifactSource()
      ..artifacts['models/test-model/model.bin'] = () =>
          Stream.value(const <int>[1, 2, 4]);
    final manager = RuntimeModelManager(
      manifests: <BundledModelManifest>[_manifest()],
      artifactSource: source,
    );
    final capture = FakeAudioCaptureService()
      ..startResult = const Ok(
        AudioCaptureSnapshot(
          sessionId: 'recording-without-ai',
          state: AudioCaptureState.recording,
          elapsed: Duration.zero,
          bytesWritten: 0,
        ),
      );
    addTearDown(capture.dispose);
    final container = ProviderContainer.test(
      overrides: [
        modelManagerProvider.overrideWithValue(manager),
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        audioCaptureServiceProvider.overrideWithValue(capture),
        meetingIdFactoryProvider.overrideWithValue(
          () => 'recording-without-ai',
        ),
      ],
    );
    final subscription = container.listen(
      newRecordingControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(newRecordingControllerProvider.future);

    final modelResult = await manager.verify('test-model');
    container
        .read(newRecordingControllerProvider.notifier)
        .start(title: 'Recording survives');
    await pumpEventQueue();

    _expectFailure(modelResult, 'model_sha256_mismatch');
    expect(
      container.read(newRecordingControllerProvider).requireValue.status,
      NewRecordingStatus.started,
    );
  });
}

BundledModelManifest _manifest({String id = 'test-model'}) {
  final result = BundledModelManifest.tryParse(<String, Object?>{
    'schemaVersion': 1,
    'id': id,
    'version': '1.0.0',
    'source': 'https://example.test/models/$id/model.bin',
    'artifactPath': 'models/$id/model.bin',
    'sha256':
        '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81',
    'bytes': 3,
    'runtime': <String, Object?>{
      'engineId': 'test-engine',
      'modelFormat': 'test-format',
    },
    'license': <String, Object?>{
      'id': 'MIT',
      'snapshotPath': 'models/licenses/$id.txt',
    },
    'capabilities': <Object?>['transcription'],
    'enabledModes': <Object?>['postSession'],
  });
  return (result as Ok<BundledModelManifest, InvalidModelManifest>).value;
}

void _expectFailure(
  Result<ModelDescriptor, ModelFailure> result,
  String code,
) {
  expect(result, isA<Err<ModelDescriptor, ModelFailure>>());
  expect(
    (result as Err<ModelDescriptor, ModelFailure>).failure.code,
    code,
  );
}

final class _MemoryModelArtifactSource implements ModelArtifactSource {
  final Map<String, Stream<List<int>> Function()> artifacts =
      <String, Stream<List<int>> Function()>{};

  @override
  Future<Result<ModelArtifact, ModelArtifactSourceFailure>> open(
    AppRelativePath artifactPath,
  ) async {
    final streamFactory = artifacts[artifactPath.value];
    if (streamFactory == null) {
      return const Err<ModelArtifact, ModelArtifactSourceFailure>(
        ModelArtifactSourceFailure(ModelArtifactSourceFailureReason.missing),
      );
    }
    return Ok<ModelArtifact, ModelArtifactSourceFailure>(
      ModelArtifact(streamFactory()),
    );
  }
}
