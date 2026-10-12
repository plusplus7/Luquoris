import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/recording/presentation/recording_controller.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

/// Progress of the new-recording setup and preflight action.
enum NewRecordingStatus {
  /// The form is ready for user input.
  ready,

  /// Local persistence and native preflight are running.
  submitting,

  /// Native capture started and the active session may be opened.
  started,

  /// A typed local or native failure prevented normal completion.
  failed,
}

/// Failure surfaced by new-recording orchestration.
sealed class NewRecordingFailure {
  const NewRecordingFailure(this.code);

  /// Stable failure code suitable for localized mapping.
  final String code;

  /// Whether the same meeting identity may safely issue another start.
  bool get allowsStartRetry;
}

/// Local persistence failed before or immediately after native startup.
final class NewRecordingPersistenceFailure extends NewRecordingFailure {
  /// Creates a presentation failure from a repository boundary failure.
  NewRecordingPersistenceFailure(SessionRepositoryFailure failure)
    : super(failure.code);

  @override
  bool get allowsStartRetry => true;
}

/// Native recording preflight or startup failed.
final class NewRecordingCaptureFailure extends NewRecordingFailure {
  /// Creates a presentation failure from a capture boundary failure.
  NewRecordingCaptureFailure(AudioCaptureFailure failure)
    : availableBytes = failure is AudioCaptureInsufficientStorage
          ? failure.availableBytes
          : null,
      requiredBytes = failure is AudioCaptureInsufficientStorage
          ? failure.requiredBytes
          : null,
      super(failure.code);

  /// Free bytes measured during storage preflight, when available.
  final int? availableBytes;

  /// Bytes required by the four-hour recording policy, when applicable.
  final int? requiredBytes;

  @override
  bool get allowsStartRetry => true;
}

/// Native command completion is ambiguous, so starting again is unsafe.
final class NewRecordingCaptureOutcomeUnknown extends NewRecordingFailure {
  /// Creates an unresolved native-start failure.
  NewRecordingCaptureOutcomeUnknown(AudioCaptureFailure failure)
    : super(failure.code);

  @override
  bool get allowsStartRetry => false;
}

/// Guarded cleanup refused, so the existing meeting must not be overwritten.
final class NewRecordingCleanupFailure extends NewRecordingFailure {
  /// Creates a protected cleanup failure.
  NewRecordingCleanupFailure(SessionRepositoryFailure failure)
    : super(failure.code);

  @override
  bool get allowsStartRetry => false;
}

/// Immutable state for the recording setup screen.
@immutable
final class NewRecordingState {
  /// Creates setup state from remembered or user-selected values.
  const NewRecordingState({
    this.transcriptionMode = MeetingTranscriptionMode.postSession,
    this.languageMode = MeetingLanguageMode.mixed,
    this.expectedSpeakerCount,
    this.status = NewRecordingStatus.ready,
    this.startedMeetingId,
    this.failure,
  });

  static const _unset = Object();

  /// Requested live-draft or post-session transcription timing.
  final MeetingTranscriptionMode transcriptionMode;

  /// Recognition language hint.
  final MeetingLanguageMode languageMode;

  /// Optional two-to-six-speaker guidance; null requests automatic analysis.
  final int? expectedSpeakerCount;

  /// Current orchestration progress.
  final NewRecordingStatus status;

  /// Stable active meeting identity after native capture starts.
  final String? startedMeetingId;

  /// Typed failure shown without discarding the selected setup.
  final NewRecordingFailure? failure;

  /// Whether another start action is currently safe.
  bool get canStart => switch (status) {
    NewRecordingStatus.ready => true,
    NewRecordingStatus.failed => failure?.allowsStartRetry ?? false,
    NewRecordingStatus.submitting || NewRecordingStatus.started => false,
  };

  /// Returns a new immutable setup value.
  NewRecordingState copyWith({
    MeetingTranscriptionMode? transcriptionMode,
    MeetingLanguageMode? languageMode,
    Object? expectedSpeakerCount = _unset,
    NewRecordingStatus? status,
    Object? startedMeetingId = _unset,
    Object? failure = _unset,
  }) => NewRecordingState(
    transcriptionMode: transcriptionMode ?? this.transcriptionMode,
    languageMode: languageMode ?? this.languageMode,
    expectedSpeakerCount: identical(expectedSpeakerCount, _unset)
        ? this.expectedSpeakerCount
        : expectedSpeakerCount as int?,
    status: status ?? this.status,
    startedMeetingId: identical(startedMeetingId, _unset)
        ? this.startedMeetingId
        : startedMeetingId as String?,
    failure: identical(failure, _unset)
        ? this.failure
        : failure as NewRecordingFailure?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NewRecordingState &&
          transcriptionMode == other.transcriptionMode &&
          languageMode == other.languageMode &&
          expectedSpeakerCount == other.expectedSpeakerCount &&
          status == other.status &&
          startedMeetingId == other.startedMeetingId &&
          failure.runtimeType == other.failure.runtimeType &&
          failure?.code == other.failure?.code &&
          _availableBytes(failure) == _availableBytes(other.failure) &&
          _requiredBytes(failure) == _requiredBytes(other.failure);

  @override
  int get hashCode => Object.hash(
    transcriptionMode,
    languageMode,
    expectedSpeakerCount,
    status,
    startedMeetingId,
    failure.runtimeType,
    failure?.code,
    _availableBytes(failure),
    _requiredBytes(failure),
  );

  static int? _availableBytes(NewRecordingFailure? failure) =>
      failure is NewRecordingCaptureFailure ? failure.availableBytes : null;

  static int? _requiredBytes(NewRecordingFailure? failure) =>
      failure is NewRecordingCaptureFailure ? failure.requiredBytes : null;
}

/// Generates stable local meeting identifiers without external services.
final meetingIdFactoryProvider = Provider<String Function()>(
  (ref) => const Uuid().v4,
);

/// Owns setup selection and persist-before-capture orchestration.
final class NewRecordingController extends AsyncNotifier<NewRecordingState> {
  Meeting? _draftMeeting;

  @override
  Future<NewRecordingState> build() async {
    final result = await ref
        .watch(sessionRepositoryProvider)
        .loadRecordingDefaults();
    return switch (result) {
      Ok(:final value) => NewRecordingState(
        transcriptionMode: value.transcriptionMode,
        languageMode: value.languageMode,
        expectedSpeakerCount: value.expectedSpeakerCount,
      ),
      Err(:final failure) => NewRecordingState(
        status: NewRecordingStatus.failed,
        failure: NewRecordingPersistenceFailure(failure),
      ),
    };
  }

  /// Selects when transcription work may run for this meeting.
  void selectTranscriptionMode(MeetingTranscriptionMode value) {
    _update((current) => current.copyWith(transcriptionMode: value));
  }

  /// Selects the recognition language hint for this meeting.
  void selectLanguageMode(MeetingLanguageMode value) {
    _update((current) => current.copyWith(languageMode: value));
  }

  /// Selects automatic or explicit two-to-six-speaker guidance.
  void selectExpectedSpeakerCount(int? value) {
    assert(
      value == null || (value >= 2 && value <= 6),
      'expected speaker count must be null or between two and six',
    );
    _update((current) => current.copyWith(expectedSpeakerCount: value));
  }

  /// Persists the setup, runs native preflight, and starts immediately.
  void start({required String title}) {
    final current = state.value;
    if (current == null || !current.canStart) return;
    unawaited(_start(current, title));
  }

  Future<void> _start(NewRecordingState selection, String title) async {
    state = AsyncData(
      selection.copyWith(
        status: NewRecordingStatus.submitting,
        startedMeetingId: null,
        failure: null,
      ),
    );
    final now = ref.read(clockProvider).now().toUtc();
    final draft = _draftMeeting;
    final meetingId = draft?.id ?? ref.read(meetingIdFactoryProvider)();
    final meeting = Meeting(
      id: meetingId,
      title: draft?.title ?? title,
      createdAtUtcMs: draft?.createdAtUtcMs ?? now.millisecondsSinceEpoch,
      mediaDuration: Duration.zero,
      lifecycle: MeetingLifecycle.preparing,
      languageMode: selection.languageMode,
      transcriptionMode: selection.transcriptionMode,
      expectedSpeakerCount: selection.expectedSpeakerCount,
    );
    _draftMeeting = meeting;
    final repository = ref.read(sessionRepositoryProvider);
    final defaults = RecordingDefaults(
      transcriptionMode: selection.transcriptionMode,
      languageMode: selection.languageMode,
      expectedSpeakerCount: selection.expectedSpeakerCount,
    );
    final persistedDefaults = await repository.saveRecordingDefaults(
      defaults,
      atUtcMs: now.millisecondsSinceEpoch,
    );
    if (persistedDefaults case Err(:final failure)) {
      _fail(selection, NewRecordingPersistenceFailure(failure));
      return;
    }
    final persistedMeeting = await repository.saveMeeting(meeting);
    if (persistedMeeting case Err(:final failure)) {
      _fail(selection, NewRecordingPersistenceFailure(failure));
      return;
    }
    Result<AudioCaptureSnapshot, AudioCaptureFailure> captureResult;
    final capture = ref.read(audioCaptureServiceProvider);
    try {
      captureResult = await capture.start(
        AudioCaptureRequest(sessionId: meetingId),
      );
    } on Object {
      captureResult = const Err(
        AudioCaptureUnavailable('recording_command_unexpected'),
      );
    }
    if (captureResult case Err(:final failure)) {
      if (_isDefinitivePreflightFailure(failure)) {
        final cleanup = await repository.discardUnstartedMeeting(meetingId);
        switch (cleanup) {
          case Ok():
            _fail(selection, NewRecordingCaptureFailure(failure));
          case Err(:final failure):
            _fail(selection, NewRecordingCleanupFailure(failure));
        }
        return;
      }
      final authoritative = await capture.current();
      if (authoritative case Ok(:final value)
          when value.sessionId == meetingId &&
              value.state != AudioCaptureState.idle) {
        ref
            .read(recordingControllerProvider.notifier)
            .acceptAuthoritativeSnapshot(value);
        _started(selection, meetingId);
        return;
      }
      _fail(selection, NewRecordingCaptureOutcomeUnknown(failure));
      return;
    }
    final snapshot =
        (captureResult as Ok<AudioCaptureSnapshot, AudioCaptureFailure>).value;
    ref
        .read(recordingControllerProvider.notifier)
        .acceptAuthoritativeSnapshot(snapshot);
    _started(selection, meetingId);
  }

  void _started(NewRecordingState selection, String meetingId) {
    if (!ref.mounted) return;
    state = AsyncData(
      selection.copyWith(
        status: NewRecordingStatus.started,
        startedMeetingId: meetingId,
        failure: null,
      ),
    );
  }

  void _fail(NewRecordingState selection, NewRecordingFailure failure) {
    if (!ref.mounted) return;
    state = AsyncData(
      selection.copyWith(
        status: NewRecordingStatus.failed,
        startedMeetingId: null,
        failure: failure,
      ),
    );
  }

  void _update(NewRecordingState Function(NewRecordingState) transform) {
    final current = state.value;
    if (current == null || !current.canStart) return;
    state = AsyncData(
      transform(current).copyWith(
        status: NewRecordingStatus.ready,
        startedMeetingId: null,
        failure: null,
      ),
    );
  }
}

bool _isDefinitivePreflightFailure(AudioCaptureFailure failure) =>
    failure is AudioCaptureInsufficientStorage ||
    failure.code == 'recording_permission_denied' ||
    failure.code == 'microphone_permission_denied';

/// Screen-lifetime state for creating one recording.
final AsyncNotifierProvider<NewRecordingController, NewRecordingState>
newRecordingControllerProvider =
    AsyncNotifierProvider.autoDispose<
      NewRecordingController,
      NewRecordingState
    >(NewRecordingController.new);
