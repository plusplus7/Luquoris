import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';

/// Read-only machine draft isolated from durable versions and human revisions.
final class StreamingDraft extends ValueObject {
  /// Begins an empty draft for one explicitly acquired recognizer owner.
  const StreamingDraft.empty(this.owner)
    : utterances = const [],
      gaps = const [],
      lastSequence = -1,
      isClosed = false,
      failure = null;

  StreamingDraft._(
    this.owner,
    this.lastSequence,
    List<StreamingUtterance> values, {
    List<StreamingGap> gaps = const [],
    this.isClosed = false,
    this.failure,
  }) : utterances = List.unmodifiable(values),
       gaps = List.unmodifiable(gaps);

  /// Meeting/run/generation accepted by this draft only.
  final StreamingOwner owner;

  /// Capture-ordered original-language hypotheses; never human corrections.
  final List<StreamingUtterance> utterances;

  /// Explicit missing-media/capture boundaries, never model text.
  final List<StreamingGap> gaps;

  /// Highest accepted owner-scoped callback sequence, or -1 before any event.
  final int lastSequence;

  /// Whether this owner has relinquished recognition and cannot accept events.
  final bool isClosed;

  /// Terminal degradation cause, if any; recorder capture is unaffected.
  final StreamingFailure? failure;

  /// Seals a retained draft without inventing final text for its hypothesis.
  StreamingDraft close() => isClosed
      ? this
      : StreamingDraft._(
          owner,
          lastSequence,
          utterances,
          gaps: gaps,
          isClosed: true,
          failure: failure,
        );

  /// Reconciles one callback without mutating any previous snapshot.
  StreamingDraft accept(StreamingEvent event) {
    if (isClosed || event.owner != owner || event.sequence <= lastSequence) {
      return this;
    }
    return switch (event) {
      StreamingUtterance() => _acceptUtterance(event),
      StreamingGap() => _acceptGap(event),
      StreamingFailed(:final failure) => StreamingDraft._(
        owner,
        event.sequence,
        utterances,
        gaps: gaps,
        isClosed: true,
        failure: failure,
      ),
    };
  }

  StreamingDraft _acceptGap(StreamingGap event) {
    if (event.start < Duration.zero ||
        event.end < event.start ||
        event.captureEpoch < 0) {
      return this;
    }
    final previous = utterances.lastOrNull;
    final boundary = gaps.lastOrNull;
    if (previous != null &&
        (previous.status == StreamingUtteranceStatus.provisional ||
            event.start < previous.end ||
            event.captureEpoch < previous.captureEpoch)) {
      return this;
    }
    if (boundary != null &&
        (event.start < boundary.end ||
            event.captureEpoch < boundary.captureEpoch)) {
      return this;
    }
    // A boundary never seals a guess or manufactures a speech interval.
    return StreamingDraft._(
      owner,
      event.sequence,
      utterances,
      gaps: [...gaps, event],
    );
  }

  StreamingDraft _acceptUtterance(StreamingUtterance event) {
    if (event.utteranceId.isEmpty ||
        event.start < Duration.zero ||
        event.end < event.start ||
        event.captureEpoch < 0) {
      return this;
    }
    final boundary = gaps.lastOrNull;
    if (boundary != null &&
        (event.start < boundary.end ||
            event.captureEpoch != boundary.captureEpoch)) {
      return this;
    }
    final existing = utterances.indexWhere(
      (u) => u.utteranceId == event.utteranceId,
    );
    if (existing >= 0) {
      final previous = utterances[existing];
      if (existing != utterances.length - 1 ||
          previous.status == StreamingUtteranceStatus.finalized ||
          previous.start != event.start ||
          previous.end > event.end ||
          previous.captureEpoch != event.captureEpoch) {
        return this;
      }
      final next = [...utterances]..[existing] = event;
      return StreamingDraft._(owner, event.sequence, next, gaps: gaps);
    }
    if (utterances.isNotEmpty) {
      final previous = utterances.last;
      if (previous.status == StreamingUtteranceStatus.provisional ||
          event.start < previous.end ||
          event.captureEpoch != previous.captureEpoch &&
              boundary?.captureEpoch != event.captureEpoch) {
        return this;
      }
    }
    return StreamingDraft._(owner, event.sequence, [
      ...utterances,
      event,
    ], gaps: gaps);
  }

  @override
  List<Object?> get equalityValues => [
    owner,
    lastSequence,
    isClosed,
    failure?.code,
    ...utterances,
    ...gaps,
  ];
}
