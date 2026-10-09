import 'dart:async';

import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/services/service_contracts.dart';

final class FakeAudioCaptureService implements AudioCaptureService {
  final List<AudioCaptureRequest> startRequests = [];
  final StreamController<AudioCaptureSnapshot> _snapshots =
      StreamController.broadcast(sync: true);

  Result<AudioCaptureSnapshot, AudioCaptureFailure> startResult = const Ok(
    AudioCaptureSnapshot(
      state: AudioCaptureState.recording,
      elapsed: Duration.zero,
      bytesWritten: 0,
    ),
  );
  Result<AudioCaptureSnapshot, AudioCaptureFailure> pauseResult = const Ok(
    AudioCaptureSnapshot(
      state: AudioCaptureState.pausedByUser,
      elapsed: Duration.zero,
      bytesWritten: 0,
    ),
  );
  Result<AudioCaptureSnapshot, AudioCaptureFailure> resumeResult = const Ok(
    AudioCaptureSnapshot(
      state: AudioCaptureState.recording,
      elapsed: Duration.zero,
      bytesWritten: 0,
    ),
  );
  Result<AudioCaptureSnapshot, AudioCaptureFailure> stopResult = const Ok(
    AudioCaptureSnapshot(
      state: AudioCaptureState.finalized,
      elapsed: Duration.zero,
      bytesWritten: 0,
    ),
  );

  @override
  Stream<AudioCaptureSnapshot> get snapshots => _snapshots.stream;

  void emitSnapshot(AudioCaptureSnapshot snapshot) => _snapshots.add(snapshot);

  Future<void> dispose() => _snapshots.close();

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> start(
    AudioCaptureRequest request,
  ) async {
    startRequests.add(request);
    return startResult;
  }

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> pause() async =>
      pauseResult;

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> resume() async =>
      resumeResult;

  @override
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> stop() async =>
      stopResult;
}

final class FakeTranscriptionEngine implements TranscriptionEngine {
  final List<TranscriptionRequest> requests = [];
  final List<String> cancellationRequests = [];
  final StreamController<TranscriptionEvent> _events =
      StreamController.broadcast(sync: true);
  Result<TranscriptionOutput, TranscriptionFailure> result = Ok(
    TranscriptionOutput(chunks: []),
  );
  Result<void, TranscriptionFailure> cancelResult = const Ok(null);

  @override
  Stream<TranscriptionEvent> eventsFor(String runId) =>
      _events.stream.where((event) => event.runId == runId);

  void emit(TranscriptionEvent event) => _events.add(event);

  Future<void> dispose() => _events.close();

  @override
  Future<Result<TranscriptionOutput, TranscriptionFailure>> transcribe(
    TranscriptionRequest request,
  ) async {
    requests.add(request);
    return result;
  }

  @override
  Future<Result<void, TranscriptionFailure>> cancel(String runId) async {
    cancellationRequests.add(runId);
    return cancelResult;
  }
}

final class FakeLanguageIdentificationEngine
    implements LanguageIdentificationEngine {
  final List<LanguageIdentificationRequest> requests = [];
  Result<LanguageIdentification, LanguageIdentificationFailure> result =
      const Ok(
        LanguageIdentification(
          segmentId: 'fake-segment',
          language: IdentifiedLanguage.uncertain,
          confidence: 0,
        ),
      );

  @override
  Future<Result<LanguageIdentification, LanguageIdentificationFailure>>
  identify(
    LanguageIdentificationRequest request,
  ) async {
    requests.add(request);
    return result;
  }
}

final class FakeSpeakerDiarizationEngine implements SpeakerDiarizationEngine {
  final List<SpeakerDiarizationRequest> requests = [];
  Result<SpeakerDiarizationOutput, SpeakerDiarizationFailure> result = Ok(
    SpeakerDiarizationOutput(turns: []),
  );

  @override
  Future<Result<SpeakerDiarizationOutput, SpeakerDiarizationFailure>> analyze(
    SpeakerDiarizationRequest request,
  ) async {
    requests.add(request);
    return result;
  }
}

final class FakeModelManager implements ModelManager {
  final List<String> verifiedModelIds = [];
  Result<ModelInventory, ModelFailure> listResult = Ok(
    ModelInventory(models: []),
  );
  Result<ModelDescriptor, ModelFailure> verifyResult = const Ok(
    ModelDescriptor(id: 'fake-model', version: 'test', bytes: 0),
  );

  @override
  Future<Result<ModelInventory, ModelFailure>> listInstalled() async =>
      listResult;

  @override
  Future<Result<ModelDescriptor, ModelFailure>> verify(String modelId) async {
    verifiedModelIds.add(modelId);
    return verifyResult;
  }
}

final class FakeThermalAndPerformanceMonitor
    implements ThermalAndPerformanceMonitor {
  int currentCalls = 0;
  Result<DevicePerformanceSnapshot, PerformanceFailure> result = Ok(
    DevicePerformanceSnapshot(
      observedAtMonotonic: Duration.zero,
      processCpuTime: Duration.zero,
      processPssBytes: 0,
      thermalState: ThermalState.unknown,
      isCharging: false,
    ),
  );

  @override
  Future<Result<DevicePerformanceSnapshot, PerformanceFailure>>
  current() async {
    currentCalls += 1;
    return result;
  }
}

final class FakeSessionRepository implements SessionRepository {
  final List<SessionSummary> savedSessions = [];
  Result<SessionCollection, SessionRepositoryFailure> listResult = Ok(
    SessionCollection(sessions: const []),
  );
  Result<SessionSummary, SessionRepositoryFailure>? saveResult;

  @override
  Future<Result<SessionCollection, SessionRepositoryFailure>> list() async =>
      listResult;

  @override
  Future<Result<SessionSummary, SessionRepositoryFailure>> save(
    SessionSummary session,
  ) async {
    savedSessions.add(session);
    return saveResult ?? Ok(session);
  }

  @override
  Stream<Result<SessionLibraryPage, SessionRepositoryFailure>> watchLibrary(
    SessionLibraryQuery query,
  ) => Stream.value(
    Ok(SessionLibraryPage(meetings: const [], nextCursor: null)),
  );

  @override
  Future<Result<SessionLibraryPage, SessionRepositoryFailure>> queryLibrary(
    SessionLibraryQuery query,
  ) async => Ok(SessionLibraryPage(meetings: const [], nextCursor: null));

  @override
  Future<Result<Meeting, SessionRepositoryFailure>> saveMeeting(
    Meeting meeting,
  ) async => Ok(meeting);

  @override
  Future<Result<List<SessionSearchHit>, SessionRepositoryFailure>> search(
    String query,
  ) async => const Ok(<SessionSearchHit>[]);

  @override
  Future<Result<Meeting, SessionRepositoryFailure>> moveToTrash(
    String meetingId, {
    required int atUtcMs,
  }) async => const Err(SessionRepositoryUnavailable('fake_not_configured'));

  @override
  Future<Result<Meeting, SessionRepositoryFailure>> restoreFromTrash(
    String meetingId, {
    required int atUtcMs,
  }) async => const Err(SessionRepositoryUnavailable('fake_not_configured'));

  @override
  Future<Result<void, SessionRepositoryFailure>> permanentlyDelete(
    String meetingId,
  ) async => const Ok<void, SessionRepositoryFailure>(null);

  @override
  Future<Result<SessionStorageAccounting, SessionRepositoryFailure>>
  accountStorage() async => const Ok(
    SessionStorageAccounting(activeMeetingBytes: 0, trashBytes: 0),
  );

  @override
  Future<Result<SessionRecoveryReport, SessionRepositoryFailure>>
  reconcileRecovery(
    List<SessionRecoveryEvidence> evidence, {
    required int observedAtUtcMs,
  }) async => Ok(
    SessionRecoveryReport(
      markedRecoverableIds: const [],
      unchangedIds: evidence.map((item) => item.meetingId).toList(),
    ),
  );
}

final class FakeExportService implements ExportService {
  final List<ExportRequest> requests = [];
  Result<ExportReceipt, ExportFailure> result = const Ok(
    ExportReceipt(outputPath: '/tmp/loquiris-export'),
  );

  @override
  Future<Result<ExportReceipt, ExportFailure>> export(
    ExportRequest request,
  ) async {
    requests.add(request);
    return result;
  }
}
