import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/data/files/meeting_audio_store.dart';
import 'package:loquiris/data/repositories/drift_meeting_processing_selection_repository.dart';
import 'package:loquiris/data/repositories/drift_remote_transcription_repository.dart';
import 'package:loquiris/data/repositories/drift_session_repository.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:loquiris/features/recording/presentation/new_recording_controller.dart';
import 'package:loquiris/features/recording/presentation/recording_controller.dart';
import 'package:loquiris/features/remote_transcription/application/remote_feature.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/meeting_processing_selection_repository.dart';
import 'package:loquiris/services/remote_transcription_repository.dart';
import 'package:loquiris/services/remote_transcription_service.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

void main() {
  test(
    'switching a failed draft to recording-only cancels its remote intent',
    () async {
      final fixture = _Fixture(modelAvailable: false, remoteEnabled: true);
      addTearDown(fixture.close);
      fixture.capture.result = const Ok(
        AudioCaptureSnapshot(
          sessionId: 'meeting',
          state: AudioCaptureState.recording,
          elapsed: Duration.zero,
          bytesWritten: 0,
        ),
      );
      await fixture.container.read(newRecordingControllerProvider.future);
      await fixture.database.customStatement(
        "CREATE TRIGGER remote_fail_prepare BEFORE UPDATE OF lifecycle ON meetings WHEN NEW.lifecycle='preparing' BEGIN SELECT RAISE(ABORT, 'test'); END",
      );
      fixture.container
          .read(newRecordingControllerProvider.notifier)
          .start(title: 'draft');
      await pumpEventQueue();
      expect(fixture.capture.calls, 0);
      await fixture.database.customStatement(
        'DROP TRIGGER remote_fail_prepare',
      );
      fixture.container.read(newRecordingControllerProvider.notifier)
        ..selectProcessingMode(MeetingProcessingMode.recordingOnly)
        ..start(title: 'draft');
      await pumpEventQueue();
      expect(fixture.capture.calls, 1);
      final tasks = await fixture.database
          .select(fixture.database.remoteTranscriptionTasks)
          .get();
      expect(tasks.single.state, 'cancelled');
    },
  );
  test('remote capture needs no local model or configured network', () async {
    final fixture = _Fixture(modelAvailable: false, remoteEnabled: true);
    fixture.capture.result = const Ok(
      AudioCaptureSnapshot(
        sessionId: 'meeting',
        state: AudioCaptureState.recording,
        elapsed: Duration.zero,
        bytesWritten: 0,
      ),
    );
    addTearDown(fixture.close);
    await fixture.container.read(newRecordingControllerProvider.future);
    fixture.container
        .read(newRecordingControllerProvider.notifier)
        .start(title: 'Remote capture');
    await pumpEventQueue();
    expect(fixture.capture.calls, 1);
    expect(
      fixture.capture.seenSelection?.mode,
      MeetingProcessingMode.recordingOnly,
    );
    final tasks = await fixture.database
        .select(fixture.database.remoteTranscriptionTasks)
        .get();
    expect(tasks.single.state, 'waitingSetup');
  });
  test(
    'pending start survives leaving setup and releases its finite keep-alive',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final gate = Completer<void>();
      fixture.capture.gate = gate.future;
      fixture.capture.result = const Ok(
        AudioCaptureSnapshot(
          sessionId: 'meeting',
          state: AudioCaptureState.recording,
          elapsed: Duration.zero,
          bytesWritten: 0,
          revision: 1,
        ),
      );
      await fixture.container.read(recordingControllerProvider.future);
      await fixture.container.read(newRecordingControllerProvider.future);
      fixture.container
          .read(newRecordingControllerProvider.notifier)
          .start(title: 'Continue after leaving');
      await pumpEventQueue();
      expect(fixture.capture.calls, 1);
      fixture.subscription.close();
      await pumpEventQueue();
      expect(fixture.container.exists(newRecordingControllerProvider), isTrue);
      gate.complete();
      await pumpEventQueue();
      expect(
        fixture.container
            .read(recordingControllerProvider)
            .requireValue
            .snapshot
            ?.sessionId,
        'meeting',
      );
      expect(
        fixture.container
            .read(recordingControllerProvider)
            .requireValue
            .snapshot
            ?.state,
        AudioCaptureState.recording,
      );
      expect(
        (await fixture.database.select(fixture.database.meetings).getSingle())
            .lifecycle,
        'recording',
      );
      expect(fixture.container.exists(newRecordingControllerProvider), isFalse);
    },
  );

  test(
    'a missing post-session profile requires an explicit recording-only choice',
    () async {
      final fixture = _Fixture(modelAvailable: false);
      addTearDown(fixture.close);
      await fixture.container.read(newRecordingControllerProvider.future);
      fixture.container
          .read(newRecordingControllerProvider.notifier)
          .start(title: 'No implicit downgrade');
      await pumpEventQueue();
      expect(fixture.capture.calls, 0);
      expect(
        await fixture.database.select(fixture.database.meetings).get(),
        isEmpty,
      );
      expect(
        fixture.container
            .read(newRecordingControllerProvider)
            .requireValue
            .failure
            ?.code,
        'recording_processing_profile_unavailable',
      );
      fixture.container.read(newRecordingControllerProvider.notifier)
        ..selectProcessingMode(MeetingProcessingMode.recordingOnly)
        ..start(title: 'Capture only');
      await pumpEventQueue();
      expect(
        fixture.capture.seenSelection?.mode,
        MeetingProcessingMode.recordingOnly,
      );
      expect(fixture.capture.calls, 1);
    },
  );

  test(
    'per-meeting start preserves a timing preference changed after form opened',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final repository = fixture.container.read(sessionRepositoryProvider);
      await fixture.container.read(newRecordingControllerProvider.future);
      final seeded = await repository.saveRecordingDefaults(
        const RecordingDefaults(
          transcriptionMode: MeetingTranscriptionMode.nearRealTime,
        ),
        atUtcMs: 1,
      );
      expect(seeded.isOk, isTrue);
      fixture.container.read(newRecordingControllerProvider.notifier)
        ..selectProcessingMode(MeetingProcessingMode.recordingOnly)
        ..selectLanguageMode(MeetingLanguageMode.english)
        ..start(title: 'Independent choice');
      await pumpEventQueue();
      final defaults = await repository.loadRecordingDefaults();
      expect(
        (defaults as Ok<RecordingDefaults, SessionRepositoryFailure>)
            .value
            .transcriptionMode,
        MeetingTranscriptionMode.nearRealTime,
      );
      expect(fixture.capture.seenMeeting?.transcriptionMode, 'postSession');
      expect(fixture.capture.seenMeeting?.languageMode, 'english');
      expect(
        fixture.capture.seenSelection?.mode,
        MeetingProcessingMode.recordingOnly,
      );
    },
  );

  test(
    'preparing write failure can retry with a different explicit mode',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      await fixture.database.customStatement('''
      CREATE TRIGGER fail_preparing BEFORE UPDATE ON meetings
      WHEN NEW.lifecycle = 'preparing'
      BEGIN SELECT RAISE(ABORT, 'fixture'); END
    ''');
      await fixture.container.read(newRecordingControllerProvider.future);
      fixture.container
          .read(newRecordingControllerProvider.notifier)
          .start(title: 'Stable identity');
      await pumpEventQueue();
      expect(fixture.capture.calls, 0);
      expect(
        fixture.container
            .read(newRecordingControllerProvider)
            .requireValue
            .canStart,
        isTrue,
      );
      await fixture.database.customStatement('DROP TRIGGER fail_preparing');
      fixture.container.read(newRecordingControllerProvider.notifier)
        ..selectProcessingMode(MeetingProcessingMode.recordingOnly)
        ..start(title: 'Ignored retry title');
      await pumpEventQueue();
      expect(fixture.capture.calls, 1);
      expect(fixture.capture.seenMeeting?.id, 'meeting');
      expect(fixture.capture.seenMeeting?.title, 'Stable identity');
      expect(
        fixture.capture.seenSelection?.mode,
        MeetingProcessingMode.recordingOnly,
      );
    },
  );

  test(
    'recording-only freezes no inference profile or model dependency',
    () async {
      final fixture = _Fixture(modelAvailable: false);
      addTearDown(fixture.close);
      await fixture.container.read(newRecordingControllerProvider.future);
      fixture.container.read(newRecordingControllerProvider.notifier)
        ..selectProcessingMode(MeetingProcessingMode.recordingOnly)
        ..start(title: 'Capture only');
      await pumpEventQueue();
      expect(fixture.capture.calls, 1);
      expect(
        fixture.capture.seenSelection?.mode,
        MeetingProcessingMode.recordingOnly,
      );
      expect(fixture.capture.seenSelection?.live, isNull);
      expect(fixture.capture.seenSelection?.refinement, isNull);
    },
  );

  test(
    'unavailable two-pass mode cannot silently start a different mode',
    () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      await fixture.container.read(newRecordingControllerProvider.future);
      fixture.container.read(newRecordingControllerProvider.notifier)
        ..selectProcessingMode(MeetingProcessingMode.twoPass)
        ..start(title: 'Unavailable pair');
      await pumpEventQueue();
      expect(fixture.capture.calls, 0);
      expect(
        await fixture.database.select(fixture.database.meetings).get(),
        isEmpty,
      );
      final state = fixture.container
          .read(newRecordingControllerProvider)
          .requireValue;
      expect(state.failure?.code, 'recording_streaming_unavailable');
      expect(state.canStart, isTrue);
    },
  );

  test('freezes full post-session profile before native capture', () async {
    final fixture = _Fixture();
    addTearDown(fixture.close);
    await fixture.container.read(newRecordingControllerProvider.future);
    fixture.container
        .read(newRecordingControllerProvider.notifier)
        .start(title: 'Explicit post-session');
    await pumpEventQueue();

    expect(fixture.capture.calls, 1);
    expect(fixture.capture.seenMeeting?.lifecycle, 'preparing');
    final choice = fixture.capture.seenSelection;
    expect(choice?.mode, MeetingProcessingMode.postSession);
    expect(choice?.live, isNull);
    expect(choice?.refinement?.manifest, fixture.manifest);
    expect(choice?.refinement?.engineVersion, '1.9.4');
    expect(jsonDecode(choice!.refinement!.parametersJson), <String, Object?>{
      'executionMode': 'postSession',
      'languageHint': 'mixed',
      'parameterVersion': 1,
      'requestedTiming': 'postSession',
    });
    expect(
      jsonDecode(choice.refinement!.bundleManifestJson),
      fixture.manifest.toJson(),
    );
  });

  test('selection write failure never reaches native capture', () async {
    final fixture = _Fixture();
    addTearDown(fixture.close);
    await fixture.database.customStatement('''
      CREATE TRIGGER fail_processing_selection
      BEFORE INSERT ON meeting_processing_selections
      BEGIN SELECT RAISE(ABORT, 'fixture'); END
    ''');
    await fixture.container.read(newRecordingControllerProvider.future);
    fixture.container
        .read(newRecordingControllerProvider.notifier)
        .start(title: 'Must not capture');
    await pumpEventQueue();

    expect(fixture.capture.calls, 0);
    expect(
      fixture.container
          .read(newRecordingControllerProvider)
          .requireValue
          .status,
      NewRecordingStatus.failed,
    );
    expect(
      await fixture.database.select(fixture.database.meetings).get(),
      isEmpty,
    );
  });
}

final class _Fixture {
  _Fixture({bool modelAvailable = true, bool remoteEnabled = false}) {
    manifest =
        (BundledModelManifest.tryParse(
                  jsonDecode(
                    File(
                      'models/manifests/whisper-base-q5_1.json',
                    ).readAsStringSync(),
                  ),
                )
                as Ok<BundledModelManifest, InvalidModelManifest>)
            .value;
    selections = DriftMeetingProcessingSelectionRepository(
      database,
      diagnosticSink: const DisabledDiagnosticLogSink(),
    );
    capture = _InspectCapture(database, selections);
    container = ProviderContainer.test(
      overrides: [
        remoteTranscriptionEnabledProvider.overrideWithValue(remoteEnabled),
        remoteTranscriptionRepositoryProvider.overrideWithValue(
          DriftRemoteTranscriptionRepository(
            database,
            service: _RemotePlatform(),
            newId: () => 'remote-run',
            nowUtcMs: () => 1,
          ),
        ),
        sessionRepositoryProvider.overrideWithValue(
          DriftSessionRepository(
            database,
            audioStore: const _NoAudioDeletion(),
            diagnosticSink: const DisabledDiagnosticLogSink(),
          ),
        ),
        meetingProcessingSelectionRepositoryProvider.overrideWithValue(
          selections,
        ),
        if (modelAvailable)
          transcriptionModelManifestProvider.overrideWithValue(manifest),
        audioCaptureServiceProvider.overrideWithValue(capture),
        meetingIdFactoryProvider.overrideWithValue(() => 'meeting'),
      ],
    );
    subscription = container.listen(newRecordingControllerProvider, (_, _) {});
  }

  final database = db.AppDatabase(NativeDatabase.memory());
  late final BundledModelManifest manifest;
  late final DriftMeetingProcessingSelectionRepository selections;
  late final _InspectCapture capture;
  late final ProviderContainer container;
  late final ProviderSubscription<AsyncValue<NewRecordingState>> subscription;

  Future<void> close() async {
    subscription.close();
    container.dispose();
    await database.close();
  }
}

final class _InspectCapture implements AudioCaptureService {
  _InspectCapture(this.database, this.selections);

  final db.AppDatabase database;
  final DriftMeetingProcessingSelectionRepository selections;
  int calls = 0;
  Future<void>? gate;
  Result<AudioCaptureSnapshot, AudioCaptureFailure> result = const Err(
    AudioCaptureUnavailable('recording_permission_denied'),
  );
  db.Meeting? seenMeeting;
  MeetingProcessingSelection? seenSelection;

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> start(
    AudioCaptureRequest request,
  ) async {
    calls++;
    seenMeeting = await database.select(database.meetings).getSingle();
    final loaded = await selections.load(request.sessionId);
    seenSelection =
        (loaded as Ok<MeetingProcessingSelection?, AnalysisRepositoryFailure>)
            .value;
    await gate;
    return result;
  }

  @override
  Stream<AudioCaptureSnapshot> get snapshots => const Stream.empty();

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> current() async =>
      const Ok(
        AudioCaptureSnapshot(
          state: AudioCaptureState.idle,
          elapsed: Duration.zero,
          bytesWritten: 0,
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _NoAudioDeletion implements MeetingAudioStore {
  const _NoAudioDeletion();

  @override
  Future<Result<void, MeetingAudioStoreFailure>> deleteAuthoritativeAudio(
    String meetingId,
    List<AppRelativePath> relativePaths,
  ) => throw StateError('No audio deletion is authorized by this test');
}

final class _RemotePlatform implements RemoteTranscriptionService {
  @override
  Future<Result<String, RemoteTranscriptionFailure>> saveConnection(
    String endpoint,
    String token,
  ) => saveCredential(endpoint, token);

  @override
  Future<Result<RemoteSavedConnection?, RemoteTranscriptionFailure>>
  loadConnection() async => const Ok(null);

  @override
  Future<Result<void, RemoteTranscriptionFailure>> wake() async =>
      const Ok(null);
  @override
  Future<Result<void, RemoteTranscriptionFailure>> prepareDatabase() async =>
      const Ok(null);
  @override
  Future<Result<void, RemoteTranscriptionFailure>> resume(String path) async =>
      const Ok(null);
  @override
  Future<Result<String, RemoteTranscriptionFailure>> saveCredential(
    String endpoint,
    String token,
  ) async => const Ok('reference');
}
