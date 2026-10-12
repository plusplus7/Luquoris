import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart' as db;
import 'package:loquiris/data/files/meeting_audio_store.dart';
import 'package:loquiris/data/repositories/drift_session_repository.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart'
    as domain;
import 'package:loquiris/services/service_contracts.dart';

void main() {
  test(
    'detail reads all meeting-local timelines in deterministic order',
    () async {
      final database = db.AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSessionRepository(
        database,
        audioStore: _NoOpAudioStore(),
        diagnosticSink: _NoOpDiagnosticSink(),
      );
      await repository.saveMeeting(_meeting);
      await database.batch((batch) {
        batch
          ..insertAll(database.audioSegments, [
            db.AudioSegmentsCompanion.insert(
              id: 'segment-1',
              createdAt: 1,
              updatedAt: 1,
              meetingId: 'meeting-1',
              sequence: 0,
              relativePath: 'recordings/key/segment-00000.adts',
              mediaStartUs: 0,
              mediaDurationUs: const Duration(seconds: 10).inMicroseconds,
              committedBytes: 80000,
              state: domain.AudioSegmentState.committed.name,
            ),
          ])
          ..insertAll(database.sessionEvents, [
            db.SessionEventsCompanion.insert(
              id: 'event-1',
              createdAt: 1,
              updatedAt: 1,
              meetingId: 'meeting-1',
              sequence: 0,
              type: domain.SessionEventType.started.name,
              wallClockUtcMs: 1000,
              monotonicElapsedUs: 0,
              mediaOffsetUs: 0,
            ),
          ])
          ..insertAll(database.bookmarks, [
            db.BookmarksCompanion.insert(
              id: 'bookmark-1',
              createdAt: 2000,
              updatedAt: 2000,
              meetingId: 'meeting-1',
              mediaOffsetUs: const Duration(seconds: 4).inMicroseconds,
              kind: domain.BookmarkKind.highlight.name,
            ),
          ])
          ..insertAll(database.processingJobs, [
            db.ProcessingJobsCompanion.insert(
              id: 'job-1',
              createdAt: 3000,
              updatedAt: 3000,
              meetingId: 'meeting-1',
              jobKind: ProcessingJobKind.audioMerge.name,
              jobState: 'failed',
              failureCode: const Value('recording_m4a_mux_failed'),
            ),
          ])
          ..insertAll(database.recoveryFindings, [
            db.RecoveryFindingsCompanion.insert(
              id: 'finding-1',
              createdAt: 4000,
              updatedAt: 4000,
              meetingId: 'meeting-1',
              segmentSequence: const Value(0),
              code: 'recording_recovery_tail_discarded',
            ),
          ]);
      });

      final result = await repository.loadDetail('meeting-1');

      final detail =
          (result as Ok<SessionDetail, SessionRepositoryFailure>).value;
      expect(detail.meeting, _meeting);
      expect(detail.segments.single.id, 'segment-1');
      expect(detail.events.single.type, domain.SessionEventType.started);
      expect(detail.bookmarks.single.mediaOffset, const Duration(seconds: 4));
      expect(
        detail.processingJobs.single.state,
        const ProcessingFailed(failureCode: 'recording_m4a_mux_failed'),
      );
      expect(
        detail.recoveryDiagnostics.single.code,
        'recording_recovery_tail_discarded',
      );
    },
  );
}

const _meeting = domain.Meeting(
  id: 'meeting-1',
  title: 'Meeting',
  createdAtUtcMs: 1,
  mediaDuration: Duration(seconds: 10),
  lifecycle: domain.MeetingLifecycle.finalized,
  languageMode: domain.MeetingLanguageMode.mixed,
);

final class _NoOpAudioStore implements MeetingAudioStore {
  @override
  Future<Result<void, MeetingAudioStoreFailure>> deleteAuthoritativeAudio(
    String meetingId,
    List<AppRelativePath> paths,
  ) async => const Ok<void, MeetingAudioStoreFailure>(null);
}

final class _NoOpDiagnosticSink implements DiagnosticLogSink {
  @override
  void record(DiagnosticEvent event) {}
}
