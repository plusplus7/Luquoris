import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/meeting_processing_selection_repository.dart';

/// In-memory explicit choices; an empty map represents genuine legacy absence.
final class FakeMeetingProcessingSelectionRepository
    implements MeetingProcessingSelectionRepository {
  final values = <String, MeetingProcessingSelection>{};
  final finalizedMeetingIds = <String>{};
  final frozenMeetingIds = <String>{};
  AnalysisRepositoryFailure? failure;

  @override
  Future<Result<MeetingProcessingSelection?, AnalysisRepositoryFailure>> load(
    String meetingId,
  ) async {
    final currentFailure = failure;
    return currentFailure == null ? Ok(values[meetingId]) : Err(currentFailure);
  }

  @override
  Future<Result<List<String>, AnalysisRepositoryFailure>>
  listFinalized() async {
    final currentFailure = failure;
    if (currentFailure != null) return Err(currentFailure);
    return Ok(
      finalizedMeetingIds
          .where((id) => values[id]?.refinement != null)
          .toList()
        ..sort(),
    );
  }

  @override
  Future<Result<MeetingProcessingSelection, AnalysisRepositoryFailure>> save(
    String meetingId,
    MeetingProcessingSelection selection, {
    required int storedAtUtcMs,
  }) async {
    final currentFailure = failure;
    if (currentFailure != null) return Err(currentFailure);
    if (storedAtUtcMs < 0 ||
        (frozenMeetingIds.contains(meetingId) &&
            values[meetingId] != selection)) {
      return const Err(AnalysisConflict());
    }
    values[meetingId] = selection;
    return Ok(selection);
  }
}
