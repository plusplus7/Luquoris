import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/features/transcript/domain/transcript_entities.dart';
import 'package:meta/meta.dart';

/// Closed, typed payload for a non-destructive human correction.
@immutable
sealed class RevisionChange extends ValueObject {
  /// Creates a revision payload.
  const RevisionChange();
}

/// Human correction of displayed transcript text.
final class TranscriptTextChange extends RevisionChange {
  /// Creates a text correction.
  const TranscriptTextChange({
    required this.previousText,
    required this.revisedText,
  });

  /// Displayed text before the correction.
  final String previousText;

  /// Displayed text after the correction.
  final String revisedText;

  @override
  List<Object?> get equalityValues => <Object?>[previousText, revisedText];
}

/// Human correction of a segment language label.
final class LanguageLabelChange extends RevisionChange {
  /// Creates a language correction.
  const LanguageLabelChange({required this.previous, required this.revised});

  /// Language label before the correction.
  final LanguageTag previous;

  /// Language label after the correction.
  final LanguageTag revised;

  @override
  List<Object?> get equalityValues => <Object?>[previous, revised];
}

/// Human correction of a speaker assignment over a media interval.
final class SpeakerAssignmentChange extends RevisionChange {
  /// Creates an interval speaker correction.
  const SpeakerAssignmentChange({
    required this.start,
    required this.end,
    required this.previousSpeakerId,
    required this.revisedSpeakerId,
    required this.needsConfirmation,
  });

  /// Inclusive pause-free media start.
  final Duration start;

  /// Exclusive pause-free media end.
  final Duration end;

  /// Previous speaker identifier, or null when unassigned.
  final String? previousSpeakerId;

  /// Revised speaker identifier, or null when deliberately unassigned.
  final String? revisedSpeakerId;

  /// Whether the corrected interval remains uncertain.
  final bool needsConfirmation;

  @override
  List<Object?> get equalityValues => <Object?>[
    start,
    end,
    previousSpeakerId,
    revisedSpeakerId,
    needsConfirmation,
  ];
}

/// Human rename of a meeting-local speaker label.
final class SpeakerLabelChange extends RevisionChange {
  /// Creates a speaker-label correction.
  const SpeakerLabelChange({required this.previous, required this.revised});

  /// Label before the rename.
  final String previous;

  /// Label after the rename.
  final String revised;

  @override
  List<Object?> get equalityValues => <Object?>[previous, revised];
}

/// Durable typed revision record.
@immutable
final class Revision extends ValueObject {
  /// Creates a revision.
  const Revision({
    required this.id,
    required this.meetingId,
    required this.targetId,
    required this.change,
    required this.createdAtUtcMs,
  }) : assert(createdAtUtcMs >= 0, 'createdAtUtcMs must be non-negative');

  /// Stable revision identifier.
  final String id;

  /// Owning meeting identifier.
  final String meetingId;

  /// Entity or segment being revised.
  final String targetId;

  /// Typed before/after correction payload.
  final RevisionChange change;

  /// UTC creation instant in epoch milliseconds.
  final int createdAtUtcMs;

  @override
  List<Object?> get equalityValues => <Object?>[
    id,
    meetingId,
    targetId,
    change,
    createdAtUtcMs,
  ];
}
