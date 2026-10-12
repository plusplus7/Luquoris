import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/export_backup/application/local_export_service.dart';
import 'package:loquiris/features/export_backup/domain/export_entities.dart'
    as domain;
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/speakers/domain/speaker_entities.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/export_record_repository_contract.dart';
import 'package:loquiris/services/service_contracts.dart';

import '../../support/fakes/fake_services.dart';

void main() {
  test(
    'text export sends corrected local text under a private default name',
    () async {
      final sessions = FakeSessionRepository()
        ..detailResult = Ok(_detail(title: 'Alice confidential interview'));
      final gateway = _FakeExportDestinationGateway();
      final records = _ExportRecordRepository();
      final service = LocalExportService(
        sessionRepository: sessions,
        transcriptRepository: _TranscriptRepository(_document()),
        destinationGateway: gateway,
        exportRecordRepository: records,
        nowUtcMs: () => 20,
      );

      final result = await service.export(
        const ExportRequest(
          operationId: 'export-1',
          createdAtUtcMs: 10,
          sessionId: 'meeting-1',
          format: ExportFormat.text,
        ),
      );

      expect(result, isA<Ok<ExportReceipt, ExportFailure>>());
      expect(records.created.single.id, 'export-1');
      expect(records.completed, [('export-1', 42, 20)]);
      final payload = gateway.payloads.single;
      expect(payload.suggestedFileName, 'Loquiris_20261001_090705.txt');
      expect(payload.suggestedFileName, isNot(contains('Alice')));
      expect(payload.mimeType, 'text/plain');
      expect(payload.documents, {
        'content.txt': '[00:00:00] Speaker 1\nCorrected text\n',
      });
    },
  );

  test(
    'archive remains exportable without a transcript and requests audio fallback',
    () async {
      final sessions = FakeSessionRepository()
        ..detailResult = Ok(_detail(title: 'Sensitive title'))
        ..recoveryDetailsResult = Ok(
          SessionRecoveryDetails(
            integrityState: RecoveryIntegrityState.partial,
            diagnostics: const [
              SessionRecoveryDiagnostic(
                code: 'recording_recovery_timeline_gap',
                segmentSequence: 1,
              ),
            ],
            rawExportSegments: [
              SessionRecoveryRawExportSegment(
                sequence: 0,
                relativePath: _path('recordings/hash/segment-00000.adts'),
                committedBytes: 321,
              ),
            ],
          ),
        );
      final gateway = _FakeExportDestinationGateway();
      final records = _ExportRecordRepository();
      final service = LocalExportService(
        sessionRepository: sessions,
        transcriptRepository: const _TranscriptRepository(null),
        destinationGateway: gateway,
        exportRecordRepository: records,
        nowUtcMs: () => 20,
      );

      final result = await service.export(
        const ExportRequest(
          operationId: 'export-2',
          createdAtUtcMs: 10,
          sessionId: 'meeting-1',
          format: ExportFormat.archive,
        ),
      );

      expect(result, isA<Ok<ExportReceipt, ExportFailure>>());
      final payload = gateway.payloads.single;
      expect(payload.includeAudio, isTrue);
      expect(payload.allowSegmentFallback, isTrue);
      expect(payload.audioPartial, isTrue);
      expect(payload.audioDiagnosticCodes, [
        'recording_recovery_timeline_gap',
      ]);
      expect(payload.segmentPlan.single.sequence, 0);
      expect(payload.segmentPlan.single.committedBytes, 321);
      expect(payload.documents.keys, {'meeting.json'});
      expect(payload.documents['meeting.json'], contains('Sensitive title'));
    },
  );

  test(
    'missing meeting returns a stable failure without opening a destination',
    () async {
      final gateway = _FakeExportDestinationGateway();
      final records = _ExportRecordRepository();
      final service = LocalExportService(
        sessionRepository: FakeSessionRepository(),
        transcriptRepository: const _TranscriptRepository(null),
        destinationGateway: gateway,
        exportRecordRepository: records,
        nowUtcMs: () => 20,
      );

      final result = await service.export(
        const ExportRequest(
          operationId: 'export-missing',
          createdAtUtcMs: 10,
          sessionId: 'missing',
          format: ExportFormat.audioM4a,
        ),
      );

      expect(
        result,
        isA<Err<ExportReceipt, ExportFailure>>().having(
          (value) => value.failure.code,
          'code',
          'export_session_unavailable',
        ),
      );
      expect(gateway.payloads, isEmpty);
      expect(records.created, isEmpty);
    },
  );

  test(
    'destination failure is durably recorded with its stable code',
    () async {
      final sessions = FakeSessionRepository()
        ..detailResult = Ok(_detail(title: 'Sensitive'));
      final gateway = _FakeExportDestinationGateway()
        ..result = const Err(
          ExportUnavailable('export_incomplete_output_cleanup_failed'),
        );
      final records = _ExportRecordRepository();
      final service = LocalExportService(
        sessionRepository: sessions,
        transcriptRepository: _TranscriptRepository(_document()),
        destinationGateway: gateway,
        exportRecordRepository: records,
        nowUtcMs: () => 30,
      );

      final result = await service.export(
        const ExportRequest(
          operationId: 'export-failed',
          createdAtUtcMs: 10,
          sessionId: 'meeting-1',
          format: ExportFormat.text,
        ),
      );

      expect(
        (result as Err<ExportReceipt, ExportFailure>).failure.code,
        'export_incomplete_output_cleanup_failed',
      );
      expect(records.failed, [
        ('export-failed', 'export_incomplete_output_cleanup_failed', 30),
      ]);
    },
  );

  test('pre-destination planning failure is also durably recorded', () async {
    final sessions = FakeSessionRepository()
      ..detailResult = Ok(_detail(title: 'Sensitive'))
      ..recoveryDetailsResult = const Err(
        SessionRepositoryUnavailable('recovery_unavailable'),
      );
    final records = _ExportRecordRepository();
    final service = LocalExportService(
      sessionRepository: sessions,
      transcriptRepository: _TranscriptRepository(_document()),
      destinationGateway: _FakeExportDestinationGateway(),
      exportRecordRepository: records,
      nowUtcMs: () => 40,
    );

    final result = await service.export(
      const ExportRequest(
        operationId: 'export-planning-failed',
        createdAtUtcMs: 10,
        sessionId: 'meeting-1',
        format: ExportFormat.archive,
      ),
    );

    expect(
      (result as Err<ExportReceipt, ExportFailure>).failure.code,
      'export_audio_plan_unavailable',
    );
    expect(records.failed, [
      ('export-planning-failed', 'export_audio_plan_unavailable', 40),
    ]);
  });
}

AppRelativePath _path(String value) => AppRelativePath.tryParse(value).fold(
  (path) => path,
  (failure) => throw StateError(failure.code),
);

SessionDetail _detail({required String title}) => SessionDetail(
  meeting: Meeting(
    id: 'meeting-1',
    title: title,
    createdAtUtcMs: DateTime.utc(2026, 10, 1, 9, 7, 5).millisecondsSinceEpoch,
    mediaDuration: const Duration(seconds: 2),
    lifecycle: MeetingLifecycle.finalized,
    languageMode: MeetingLanguageMode.mixed,
  ),
  segments: const [],
  events: const [],
  bookmarks: const [],
  processingJobs: const [],
  recoveryDiagnostics: const [],
);

TranscriptEditorDocument _document() => TranscriptEditorDocument(
  meetingId: 'meeting-1',
  lifecycle: MeetingLifecycle.finalized,
  currentVersion: TranscriptVersion(
    run: const TranscriptRun(
      id: 'run-1',
      meetingId: 'meeting-1',
      provenance: InferenceProvenance(
        engineId: 'engine',
        engineVersion: '1',
        modelId: 'model',
        modelVersion: '1',
        modelSha256: 'hash',
        parametersJson: '{}',
      ),
      createdAtUtcMs: 1,
      state: AnalysisCompleted(startedAtUtcMs: 1, endedAtUtcMs: 2),
    ),
    segments: const [
      TranscriptSegment(
        id: 'segment-1',
        transcriptRunId: 'run-1',
        start: Duration.zero,
        end: Duration(seconds: 2),
        rawModelText: 'Raw text',
        displayedText: 'Corrected text',
        revisionState: TranscriptRevisionState.corrected,
        speakerId: 'speaker-1',
      ),
    ],
    isCurrent: true,
  ),
  languagesBySegmentId: const {},
  speakersById: const {
    'speaker-1': Speaker(
      id: 'speaker-1',
      meetingId: 'meeting-1',
      analysisRunId: 'diarization-1',
      label: 'Speaker 1',
    ),
  },
  revisions: const [],
);

final class _TranscriptRepository implements TranscriptRepository {
  const _TranscriptRepository(this.document);

  final TranscriptEditorDocument? document;

  @override
  Future<Result<TranscriptEditorDocument, AnalysisRepositoryFailure>>
  loadEditor(String meetingId) async =>
      document == null ? const Err(AnalysisNotFound()) : Ok(document!);

  @override
  Future<Result<List<TranscriptVersion>, AnalysisRepositoryFailure>>
  listVersions(String meetingId) async => Ok(
    document?.currentVersion == null
        ? const []
        : <TranscriptVersion>[document!.currentVersion!],
  );

  @override
  Future<Result<void, AnalysisRepositoryFailure>> selectCurrent(
    String meetingId,
    String runId, {
    required int selectedAtUtcMs,
  }) async => const Ok(null);

  @override
  Future<Result<TranscriptVersion, AnalysisRepositoryFailure>> saveVersion(
    TranscriptRun run,
    List<TranscriptSegment> segments, {
    required int storedAtUtcMs,
  }) async => Ok(
    TranscriptVersion(run: run, segments: segments, isCurrent: false),
  );
}

final class _FakeExportDestinationGateway implements ExportDestinationGateway {
  final List<ExportDestinationPayload> payloads = [];
  Result<ExportReceipt, ExportFailure>? result;

  @override
  Future<Result<ExportReceipt, ExportFailure>> save(
    ExportDestinationPayload payload,
  ) async {
    payloads.add(payload);
    return result ??
        Ok(
          ExportReceipt(
            fileName: payload.suggestedFileName,
            bytesWritten: 42,
          ),
        );
  }

  @override
  Future<Result<void, ExportFailure>> cancel(String operationId) async =>
      const Ok(null);

  @override
  Future<Result<ExportProgress, ExportFailure>> status(
    String operationId,
  ) async => Ok(
    ExportProgress(
      operationId: operationId,
      phase: ExportProgressPhase.writing,
      bytesProcessed: 0,
      cancellable: true,
    ),
  );
}

final class _ExportRecordRepository implements ExportRecordRepository {
  final List<domain.ExportRecord> created = [];
  final List<(String, int, int)> completed = [];
  final List<(String, String, int)> failed = [];

  @override
  Future<Result<domain.ExportRecord, ExportRecordRepositoryFailure>>
  createPending(domain.ExportRecord record) async {
    created.add(record);
    return Ok(record);
  }

  @override
  Future<Result<domain.ExportRecord, ExportRecordRepositoryFailure>> complete(
    String operationId, {
    required int bytes,
    required int updatedAtUtcMs,
  }) async {
    completed.add((operationId, bytes, updatedAtUtcMs));
    return Ok(
      created
          .singleWhere((record) => record.id == operationId)
          .copyWith(
            state: domain.ExportCompleted(bytes: bytes),
          ),
    );
  }

  @override
  Future<Result<domain.ExportRecord, ExportRecordRepositoryFailure>> fail(
    String operationId, {
    required String code,
    required int updatedAtUtcMs,
  }) async {
    failed.add((operationId, code, updatedAtUtcMs));
    return Ok(
      created
          .singleWhere((record) => record.id == operationId)
          .copyWith(
            state: domain.ExportFailed(failureCode: code),
          ),
    );
  }

  @override
  Future<Result<domain.ExportRecord, ExportRecordRepositoryFailure>> read(
    String operationId,
  ) async => Ok(created.singleWhere((record) => record.id == operationId));

  @override
  Future<Result<int, ExportRecordRepositoryFailure>> failInterruptedPending({
    required int updatedAtUtcMs,
  }) async => const Ok(0);
}
