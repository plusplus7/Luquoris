import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:meta/meta.dart';

/// Single durable write path for explicit new-meeting engine role choices.
abstract interface class MeetingProcessingSelectionRepository {
  /// Saves before capture; exact retries remain idempotent after capture starts.
  @useResult
  Future<Result<MeetingProcessingSelection, AnalysisRepositoryFailure>> save(
    String meetingId,
    MeetingProcessingSelection selection, {
    required int storedAtUtcMs,
  });

  /// Reads the original complete configuration, or null for legacy absence.
  @useResult
  Future<Result<MeetingProcessingSelection?, AnalysisRepositoryFailure>> load(
    String meetingId,
  );

  /// Finds explicit, finalized non-recording-only meetings for startup recovery.
  @useResult
  Future<Result<List<String>, AnalysisRepositoryFailure>> listFinalized();
}

/// Explicit mode persistence installed once by the application composition root.
final meetingProcessingSelectionRepositoryProvider =
    Provider<MeetingProcessingSelectionRepository>(
      (ref) => throw UnimplementedError(
        'Meeting processing selections are not installed',
      ),
    );
