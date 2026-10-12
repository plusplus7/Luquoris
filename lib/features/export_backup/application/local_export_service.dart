import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/export_backup/application/export_document_builder.dart';
import 'package:loquiris/features/export_backup/domain/export_entities.dart'
    as domain;
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/export_record_repository_contract.dart';
import 'package:loquiris/services/service_contracts.dart';

/// One persisted journal-authorized prefix passed to native destination I/O.
final class ExportSegmentPlanEntry {
  /// Creates an immutable raw-segment export plan entry.
  const ExportSegmentPlanEntry({
    required this.sequence,
    required this.relativePath,
    required this.committedBytes,
  });

  /// Manifest order.
  final int sequence;

  /// Validated app-private relative path.
  final String relativePath;

  /// Exact number of bytes permitted to leave private storage.
  final int committedBytes;
}

/// Value-typed request passed to the Android user-selected destination.
final class ExportDestinationPayload {
  /// Creates one immutable native export request.
  ExportDestinationPayload({
    required this.operationId,
    required this.sessionId,
    required this.format,
    required this.suggestedFileName,
    required this.mimeType,
    required Map<String, String> documents,
    required this.includeAudio,
    required this.allowSegmentFallback,
    List<ExportSegmentPlanEntry> segmentPlan = const [],
    this.audioPartial = false,
    List<String> audioDiagnosticCodes = const [],
  }) : documents = Map.unmodifiable(documents),
       segmentPlan = List.unmodifiable(segmentPlan),
       audioDiagnosticCodes = List.unmodifiable(audioDiagnosticCodes);

  /// Stable meeting identity used to locate app-private authoritative audio.
  final String operationId;

  /// Stable meeting identity used to locate app-private authoritative audio.
  final String sessionId;

  /// Requested local representation.
  final ExportFormat format;

  /// Privacy-preserving default that the user may edit in the system picker.
  final String suggestedFileName;

  /// MIME type proposed to Android's Storage Access Framework.
  final String mimeType;

  /// Small UTF-8 documents keyed by generic archive entry name.
  final Map<String, String> documents;

  /// Whether Android must include authoritative audio.
  final bool includeAudio;

  /// Whether committed segments may replace an unavailable continuous M4A.
  final bool allowSegmentFallback;

  /// Persisted authoritative prefixes eligible for segment export.
  final List<ExportSegmentPlanEntry> segmentPlan;

  /// Whether recovery established that some meeting audio is unavailable.
  final bool audioPartial;

  /// Stable privacy-safe reasons for a partial recording.
  final List<String> audioDiagnosticCodes;
}

/// Opens a user-selected Android destination and publishes one export.
// The platform-backed implementation is injected and faked in headless tests.
abstract interface class ExportDestinationGateway {
  /// Writes [payload] only after the user confirms the system picker.
  Future<Result<ExportReceipt, ExportFailure>> save(
    ExportDestinationPayload payload,
  );

  /// Reads one active operation's latest native progress.
  Future<Result<ExportProgress, ExportFailure>> status(String operationId);

  /// Requests cooperative native cancellation.
  Future<Result<void, ExportFailure>> cancel(String operationId);
}

/// Builds local documents and delegates only destination I/O to Android.
final class LocalExportService implements ExportService {
  /// Creates the production export orchestrator from injectable boundaries.
  const LocalExportService({
    required this._sessionRepository,
    required this._transcriptRepository,
    required this._destinationGateway,
    required this._exportRecordRepository,
    required this._nowUtcMs,
    this.latestFailedExport,
  });

  final SessionRepository _sessionRepository;
  final TranscriptRepository _transcriptRepository;
  final ExportDestinationGateway _destinationGateway;
  final ExportRecordRepository _exportRecordRepository;
  final int Function() _nowUtcMs;

  /// Optional privacy-safe durable history reader installed in production.
  final Future<Result<domain.ExportRecord?, ExportRecordRepositoryFailure>>
  Function(String meetingId)?
  latestFailedExport;

  /// Reads the newest durable privacy-safe failure code for [meetingId].
  Future<Result<String?, ExportFailure>> latestFailureForMeeting(
    String meetingId,
  ) async {
    final reader = latestFailedExport;
    if (reader == null) return const Ok(null);
    return switch (await reader(meetingId)) {
      Ok(:final value) => Ok(
        switch (value?.state) {
          domain.ExportFailed(:final failureCode) => failureCode,
          _ => null,
        },
      ),
      Err() => const Err(ExportUnavailable('export_history_unavailable')),
    };
  }

  @override
  Future<Result<ExportReceipt, ExportFailure>> export(
    ExportRequest request,
  ) async {
    final detailResult = await _sessionRepository.loadDetail(request.sessionId);
    final detail = switch (detailResult) {
      Ok(:final value) => value,
      Err() => null,
    };
    if (detail == null) {
      return const Err(ExportUnavailable('export_session_unavailable'));
    }
    final pending = await _exportRecordRepository.createPending(
      domain.ExportRecord(
        id: request.operationId,
        meetingId: request.sessionId,
        format: domain.LocalExportFormat.values.byName(request.format.name),
        createdAtUtcMs: request.createdAtUtcMs,
        state: const domain.ExportPending(),
      ),
    );
    if (pending is Err<domain.ExportRecord, ExportRecordRepositoryFailure>) {
      return const Err(ExportUnavailable('export_record_unavailable'));
    }

    final includesAudio = switch (request.format) {
      ExportFormat.audioM4a ||
      ExportFormat.audioSegments ||
      ExportFormat.archive => true,
      ExportFormat.text || ExportFormat.subtitles || ExportFormat.json => false,
    };
    SessionRecoveryDetails? recoveryDetails;
    if (includesAudio) {
      recoveryDetails = switch (await _sessionRepository.recoveryDetails(
        request.sessionId,
      )) {
        Ok(:final value) => value,
        Err() => null,
      };
      if (recoveryDetails == null) {
        return _recordFailure(
          request.operationId,
          const ExportUnavailable('export_audio_plan_unavailable'),
        );
      }
    }

    final needsTranscript = switch (request.format) {
      ExportFormat.text || ExportFormat.subtitles => true,
      ExportFormat.audioM4a ||
      ExportFormat.audioSegments ||
      ExportFormat.json ||
      ExportFormat.archive => false,
    };
    TranscriptEditorDocument? transcript;
    var transcriptVersions = const <TranscriptVersion>[];
    if (request.format
        case ExportFormat.text ||
            ExportFormat.subtitles ||
            ExportFormat.json ||
            ExportFormat.archive) {
      final transcriptResult = await _transcriptRepository.loadEditor(
        request.sessionId,
      );
      switch (transcriptResult) {
        case Ok(:final value):
          transcript = value;
        case Err(:final failure):
          if (needsTranscript || failure is! AnalysisNotFound) {
            return _recordFailure(
              request.operationId,
              const ExportUnavailable('export_transcript_unavailable'),
            );
          }
      }
    }
    if (request.format case ExportFormat.json || ExportFormat.archive) {
      final versionsResult = await _transcriptRepository.listVersions(
        request.sessionId,
      );
      switch (versionsResult) {
        case Ok(:final value):
          transcriptVersions = value;
        case Err(:final failure):
          if (failure is! AnalysisNotFound) {
            return _recordFailure(
              request.operationId,
              const ExportUnavailable(
                'export_transcript_versions_unavailable',
              ),
            );
          }
      }
    }

    final documents = <String, String>{};
    switch (request.format) {
      case ExportFormat.text:
        documents['content.txt'] = ExportDocumentBuilder.plainText(transcript!);
      case ExportFormat.subtitles:
        documents['content.srt'] = ExportDocumentBuilder.subtitles(transcript!);
      case ExportFormat.json:
        documents['meeting.json'] = ExportDocumentBuilder.structuredJson(
          detail: detail,
          transcript: transcript,
          transcriptVersions: transcriptVersions,
        );
      case ExportFormat.archive:
        documents['meeting.json'] = ExportDocumentBuilder.structuredJson(
          detail: detail,
          transcript: transcript,
          transcriptVersions: transcriptVersions,
        );
        if (transcript != null) {
          documents['transcript.txt'] = ExportDocumentBuilder.plainText(
            transcript,
          );
          documents['transcript.srt'] = ExportDocumentBuilder.subtitles(
            transcript,
          );
        }
      case ExportFormat.audioM4a || ExportFormat.audioSegments:
        break;
    }

    final result = await _destinationGateway.save(
      ExportDestinationPayload(
        operationId: request.operationId,
        sessionId: request.sessionId,
        format: request.format,
        suggestedFileName: ExportDocumentBuilder.defaultFileName(
          format: request.format,
          createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
            detail.meeting.createdAtUtcMs,
            isUtc: true,
          ),
        ),
        mimeType: _mimeType(request.format),
        documents: documents,
        includeAudio: includesAudio,
        allowSegmentFallback: switch (request.format) {
          ExportFormat.audioSegments || ExportFormat.archive => true,
          ExportFormat.audioM4a ||
          ExportFormat.text ||
          ExportFormat.subtitles ||
          ExportFormat.json => false,
        },
        segmentPlan: [
          for (final segment
              in recoveryDetails?.rawExportSegments ??
                  const <SessionRecoveryRawExportSegment>[])
            ExportSegmentPlanEntry(
              sequence: segment.sequence,
              relativePath: segment.relativePath.value,
              committedBytes: segment.committedBytes,
            ),
        ],
        audioPartial:
            recoveryDetails?.integrityState == RecoveryIntegrityState.partial,
        audioDiagnosticCodes: [
          for (final diagnostic
              in recoveryDetails?.diagnostics ??
                  const <SessionRecoveryDiagnostic>[])
            diagnostic.code,
        ],
      ),
    );
    switch (result) {
      case Ok(:final value):
        final stored = await _exportRecordRepository.complete(
          request.operationId,
          bytes: value.bytesWritten,
          updatedAtUtcMs: _nowUtcMs(),
        );
        if (stored is Err<domain.ExportRecord, ExportRecordRepositoryFailure>) {
          return const Err(
            ExportUnavailable('export_completion_persistence_failed'),
          );
        }
      case Err(:final failure):
        return _recordFailure(request.operationId, failure);
    }
    return result;
  }

  Future<Result<ExportReceipt, ExportFailure>> _recordFailure(
    String operationId,
    ExportFailure failure,
  ) async {
    final stored = await _exportRecordRepository.fail(
      operationId,
      code: failure.code,
      updatedAtUtcMs: _nowUtcMs(),
    );
    if (stored is Err<domain.ExportRecord, ExportRecordRepositoryFailure>) {
      return const Err(
        ExportUnavailable('export_failure_persistence_failed'),
      );
    }
    return Err(failure);
  }

  @override
  Future<Result<ExportProgress, ExportFailure>> status(String operationId) =>
      _destinationGateway.status(operationId);

  @override
  Future<Result<void, ExportFailure>> cancel(String operationId) =>
      _destinationGateway.cancel(operationId);

  static String _mimeType(ExportFormat format) => switch (format) {
    ExportFormat.audioM4a => 'audio/mp4',
    ExportFormat.text => 'text/plain',
    ExportFormat.subtitles => 'application/x-subrip',
    ExportFormat.json => 'application/json',
    ExportFormat.audioSegments || ExportFormat.archive => 'application/zip',
  };
}
