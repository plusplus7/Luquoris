import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:meta/meta.dart';

export 'revision_entities.dart';

/// Versioned transcription run with reproducible local inference provenance.
@immutable
final class TranscriptRun extends ValueObject {
  /// Creates a transcription run.
  const TranscriptRun({
    required this.id,
    required this.meetingId,
    required this.provenance,
    required this.createdAtUtcMs,
    required this.state,
  }) : assert(createdAtUtcMs >= 0, 'createdAtUtcMs must be non-negative');

  /// Stable run identifier.
  final String id;

  /// Owning meeting identifier.
  final String meetingId;

  /// Exact engine, model, hash, and inference parameters used.
  final InferenceProvenance provenance;

  /// UTC creation instant in epoch milliseconds.
  final int createdAtUtcMs;

  /// Timestamped progress or structured terminal state.
  final AnalysisState state;

  /// Returns a copy with a changed [state].
  TranscriptRun copyWith({AnalysisState? state}) => TranscriptRun(
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

/// Whether displayed text is raw machine output or human-corrected.
enum TranscriptRevisionState {
  /// Display still follows machine output.
  machine,

  /// Display includes a human-authored correction.
  corrected,
}

/// Stable timestamped segment inside one transcript version.
@immutable
final class TranscriptSegment extends ValueObject {
  /// Creates a transcript segment.
  const TranscriptSegment({
    required this.id,
    required this.transcriptRunId,
    required this.start,
    required this.end,
    required this.rawModelText,
    required this.displayedText,
    required this.revisionState,
    this.languageDecisionId,
    this.speakerId,
  });

  static const _unset = Object();

  /// Stable identifier within the transcript version.
  final String id;

  /// Owning transcript run identifier.
  final String transcriptRunId;

  /// Inclusive pause-free media start.
  final Duration start;

  /// Exclusive pause-free media end.
  final Duration end;

  /// Untouched engine output retained for provenance.
  final String rawModelText;

  /// Current user-visible text.
  final String displayedText;

  /// Human revision state.
  final TranscriptRevisionState revisionState;

  /// Current language-decision reference.
  final String? languageDecisionId;

  /// Current meeting-local speaker reference.
  final String? speakerId;

  /// Returns a copy while allowing nullable references to be cleared.
  TranscriptSegment copyWith({
    String? displayedText,
    TranscriptRevisionState? revisionState,
    Object? languageDecisionId = _unset,
    Object? speakerId = _unset,
  }) => TranscriptSegment(
    id: id,
    transcriptRunId: transcriptRunId,
    start: start,
    end: end,
    rawModelText: rawModelText,
    displayedText: displayedText ?? this.displayedText,
    revisionState: revisionState ?? this.revisionState,
    languageDecisionId: identical(languageDecisionId, _unset)
        ? this.languageDecisionId
        : languageDecisionId as String?,
    speakerId: identical(speakerId, _unset)
        ? this.speakerId
        : speakerId as String?,
  );

  @override
  List<Object?> get equalityValues => <Object?>[
    id,
    transcriptRunId,
    start,
    end,
    rawModelText,
    displayedText,
    revisionState,
    languageDecisionId,
    speakerId,
  ];
}

/// Stored segment language label.
enum LanguageTag {
  /// Primarily Chinese.
  chinese,

  /// Primarily English.
  english,

  /// Contains meaningful Chinese-English mixing.
  mixed,

  /// Evidence is insufficient for a confident label.
  uncertain,
}

/// Provenance of a language decision.
enum LanguageDecisionSource {
  /// Produced by a local engine.
  automatic,

  /// Explicitly corrected by the user.
  manual,
}

/// Versioned language decision for one stable transcript segment.
@immutable
final class LanguageDecision extends ValueObject {
  /// Creates a language decision.
  const LanguageDecision({
    required this.id,
    required this.transcriptSegmentId,
    required this.tag,
    required this.source,
    required this.confidence,
  }) : assert(
         confidence == null || (confidence >= 0 && confidence <= 1),
         'confidence must be null or between zero and one',
       );

  static const _unset = Object();

  /// Stable decision identifier.
  final String id;

  /// Target transcript segment identifier.
  final String transcriptSegmentId;

  /// Current language label.
  final LanguageTag tag;

  /// Automatic or human provenance.
  final LanguageDecisionSource source;

  /// Calibrated confidence when available.
  final double? confidence;

  /// Returns a copy while allowing [confidence] to be explicitly cleared.
  LanguageDecision copyWith({
    LanguageTag? tag,
    LanguageDecisionSource? source,
    Object? confidence = _unset,
  }) => LanguageDecision(
    id: id,
    transcriptSegmentId: transcriptSegmentId,
    tag: tag ?? this.tag,
    source: source ?? this.source,
    confidence: identical(confidence, _unset)
        ? this.confidence
        : confidence as double?,
  );

  @override
  List<Object?> get equalityValues => <Object?>[
    id,
    transcriptSegmentId,
    tag,
    source,
    confidence,
  ];
}
