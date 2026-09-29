import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:meta/meta.dart';

/// Versioned post-session diarization run.
@immutable
final class DiarizationRun extends ValueObject {
  /// Creates a diarization run.
  const DiarizationRun({
    required this.id,
    required this.meetingId,
    required this.provenance,
    required this.createdAtUtcMs,
    required this.state,
  }) : assert(createdAtUtcMs >= 0, 'createdAtUtcMs must be non-negative');

  /// Stable analysis-run identifier.
  final String id;

  /// Owning meeting identifier.
  final String meetingId;

  /// Exact engine, model, hash, and parameters used.
  final InferenceProvenance provenance;

  /// UTC creation instant in epoch milliseconds.
  final int createdAtUtcMs;

  /// Timestamped progress or structured terminal state.
  final AnalysisState state;

  /// Returns a copy with a changed [state].
  DiarizationRun copyWith({AnalysisState? state}) => DiarizationRun(
    id: id,
    meetingId: meetingId,
    provenance: provenance,
    createdAtUtcMs: createdAtUtcMs,
    state: state ?? this.state,
  );

  @override
  List<Object?> get equalityValues => <Object?>[
    id,
    meetingId,
    provenance,
    createdAtUtcMs,
    state,
  ];
}

/// Meeting-local speaker cluster from one diarization run.
@immutable
final class Speaker extends ValueObject {
  /// Creates a speaker label.
  const Speaker({
    required this.id,
    required this.meetingId,
    required this.analysisRunId,
    required this.label,
  });

  /// Stable speaker identifier local to the analysis run.
  final String id;

  /// Owning meeting identifier.
  final String meetingId;

  /// Diarization run that produced this cluster.
  final String analysisRunId;

  /// User-visible, editable label.
  final String label;

  /// Returns a copy with an updated display label.
  Speaker copyWith({String? label}) => Speaker(
    id: id,
    meetingId: meetingId,
    analysisRunId: analysisRunId,
    label: label ?? this.label,
  );

  @override
  List<Object?> get equalityValues => <Object?>[
    id,
    meetingId,
    analysisRunId,
    label,
  ];
}

/// Raw diarization assignment for one pause-free media interval.
@immutable
final class SpeakerAssignment extends ValueObject {
  /// Creates a speaker assignment.
  const SpeakerAssignment({
    required this.id,
    required this.analysisRunId,
    required this.speakerId,
    required this.start,
    required this.end,
    required this.confidence,
    required this.isOverlap,
    required this.needsConfirmation,
  }) : assert(
         confidence == null || (confidence >= 0 && confidence <= 1),
         'confidence must be null or between zero and one',
       );

  static const _unset = Object();

  /// Stable assignment identifier.
  final String id;

  /// Owning diarization run identifier.
  final String analysisRunId;

  /// Assigned cluster, or null when the engine could not decide.
  final String? speakerId;

  /// Inclusive pause-free media start.
  final Duration start;

  /// Exclusive pause-free media end.
  final Duration end;

  /// Calibrated confidence when available.
  final double? confidence;

  /// Whether multiple speakers overlap in this interval.
  final bool isOverlap;

  /// Whether the interval needs explicit user confirmation.
  final bool needsConfirmation;

  /// Returns a copy while allowing nullable inference fields to be cleared.
  SpeakerAssignment copyWith({
    Object? speakerId = _unset,
    Object? confidence = _unset,
    bool? isOverlap,
    bool? needsConfirmation,
  }) => SpeakerAssignment(
    id: id,
    analysisRunId: analysisRunId,
    speakerId: identical(speakerId, _unset)
        ? this.speakerId
        : speakerId as String?,
    start: start,
    end: end,
    confidence: identical(confidence, _unset)
        ? this.confidence
        : confidence as double?,
    isOverlap: isOverlap ?? this.isOverlap,
    needsConfirmation: needsConfirmation ?? this.needsConfirmation,
  );

  @override
  List<Object?> get equalityValues => <Object?>[
    id,
    analysisRunId,
    speakerId,
    start,
    end,
    confidence,
    isOverlap,
    needsConfirmation,
  ];
}
