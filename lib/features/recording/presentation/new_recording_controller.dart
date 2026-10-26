import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/recording/presentation/recording_controller.dart';
import 'package:loquiris/features/remote_transcription/application/remote_feature.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/features/transcript/application/transcription_parameters.dart';
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';
import 'package:loquiris/services/meeting_processing_selection_repository.dart';
import 'package:loquiris/services/remote_transcription_repository.dart';
import 'package:loquiris/services/remote_transcription_service.dart';
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
sealed class NewRecordingFailure implements Failure {
  const NewRecordingFailure(this.code);

  /// Stable failure code suitable for localized mapping.
  @override
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

/// Explicit processing configuration could not be frozen before capture.
final class NewRecordingProcessingFailure extends NewRecordingFailure {
  /// Creates a content-free configuration failure, safe to retry before capture.
  const NewRecordingProcessingFailure(super.code);

  @override
  bool get allowsStartRetry => true;
}

/// Immutable state for the recording setup screen.
@immutable
final class NewRecordingState {
  /// Creates setup state from remembered or user-selected values.
  const NewRecordingState({
    this.processingMode = MeetingProcessingMode.postSession,
    this.transcriptionMode = MeetingTranscriptionMode.postSession,
    this.languageMode = MeetingLanguageMode.mixed,
    this.expectedSpeakerCount,
    this.status = NewRecordingStatus.ready,
    this.startedMeetingId,
    this.failure,
  });

  static const _unset = Object();

  /// Explicit processing intent for this meeting, independent of legacy defaults.
  final MeetingProcessingMode processingMode;

  /// Remembered legacy timing preference; new choices do not rewrite it.
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
    MeetingProcessingMode? processingMode,
    MeetingTranscriptionMode? transcriptionMode,
    MeetingLanguageMode? languageMode,
    Object? expectedSpeakerCount = _unset,
    NewRecordingStatus? status,
    Object? startedMeetingId = _unset,
    Object? failure = _unset,
  }) => NewRecordingState(
    processingMode: processingMode ?? this.processingMode,
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
          processingMode == other.processingMode &&
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
    processingMode,
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
  void selectProcessingMode(MeetingProcessingMode value) {
    _update((current) => current.copyWith(processingMode: value));
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
    final keepAlive = ref.keepAlive();
    unawaited(
      _start(current, title)
          .catchError((Object error) {
            _fail(
              current,
              NewRecordingCaptureOutcomeUnknown(
                const AudioCaptureUnavailable('recording_start_unexpected'),
              ),
            );
          })
          .whenComplete(keepAlive.close),
    );
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
      lifecycle: MeetingLifecycle.draft,
      languageMode: selection.languageMode,
      transcriptionMode:
          selection.processingMode == MeetingProcessingMode.twoPass
          ? MeetingTranscriptionMode.nearRealTime
          : MeetingTranscriptionMode.postSession,
      expectedSpeakerCount: selection.expectedSpeakerCount,
    );
    _draftMeeting = meeting;
    final configured = _processingSelection(selection.processingMode, meeting);
    if (configured case Err(:final failure)) {
      _fail(selection, failure);
      return;
    }
    final processing =
        (configured
                as Ok<
                  MeetingProcessingSelection,
                  NewRecordingProcessingFailure
                >)
            .value;
    final repository = ref.read(sessionRepositoryProvider);
    final remembered = await repository.loadRecordingDefaults();
    if (remembered case Err(:final failure)) {
      _fail(selection, NewRecordingPersistenceFailure(failure));
      return;
    }
    final defaults = RecordingDefaults(
      transcriptionMode:
          (remembered as Ok<RecordingDefaults, SessionRepositoryFailure>)
              .value
              .transcriptionMode,
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
    final persistedProcessing = await ref
        .read(meetingProcessingSelectionRepositoryProvider)
        .save(meetingId, processing, storedAtUtcMs: now.millisecondsSinceEpoch);
    if (persistedProcessing case Err(:final failure)) {
      final cleanup = await repository.discardUnstartedMeeting(meetingId);
      switch (cleanup) {
        case Ok():
          _fail(selection, NewRecordingProcessingFailure(failure.code));
        case Err(:final failure):
          _fail(selection, NewRecordingCleanupFailure(failure));
      }
      return;
    }
    if (ref.read(remoteTranscriptionEnabledProvider) &&
        selection.processingMode == MeetingProcessingMode.recordingOnly) {
      final remote = ref.read(remoteTranscriptionRepositoryProvider);
      final pending = await remote.load(meetingId);
      if (pending case Err(:final failure)) {
        _fail(selection, NewRecordingProcessingFailure(failure.code));
        return;
      }
      for (final task
          in (pending
                  as Ok<
                    (List<RemoteTask>, List<RemoteVersion>),
                    RemoteTranscriptionFailure
                  >)
              .value
              .$1) {
        final cancelled = await remote.cancel(task.id);
        if (cancelled case Err(:final failure)) {
          _fail(selection, NewRecordingProcessingFailure(failure.code));
          return;
        }
      }
    }
    if (ref.read(remoteTranscriptionEnabledProvider) &&
        selection.processingMode == MeetingProcessingMode.postSession) {
      final remote = ref.read(remoteTranscriptionRepositoryProvider);
      final existing = await remote.load(meetingId);
      if (existing case Err(:final failure)) {
        _fail(selection, NewRecordingProcessingFailure(failure.code));
        return;
      }
      if ((existing
              as Ok<
                (List<RemoteTask>, List<RemoteVersion>),
                RemoteTranscriptionFailure
              >)
          .value
          .$1
          .isEmpty) {
        final destination = await remote.latestDestination();
        final queued = await remote.enqueue(
          meetingId,
          destination:
              destination is Ok<RemoteDestination?, RemoteTranscriptionFailure>
              ? destination.value
              : null,
        );
        if (queued case Err(:final failure)) {
          _fail(selection, NewRecordingProcessingFailure(failure.code));
          return;
        }
      }
    }
    final preparing = await repository.saveMeeting(
      meeting.copyWith(lifecycle: MeetingLifecycle.preparing),
    );
    if (preparing case Err(:final failure)) {
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

  Result<MeetingProcessingSelection, NewRecordingProcessingFailure>
  _processingSelection(MeetingProcessingMode mode, Meeting meeting) {
    switch (mode) {
      case MeetingProcessingMode.recordingOnly:
        return const Ok(MeetingProcessingSelection.recordingOnly());
      case MeetingProcessingMode.twoPass:
        return const Err(
          NewRecordingProcessingFailure(
            'recording_streaming_unavailable',
          ),
        );
      case MeetingProcessingMode.postSession:
        if (ref.read(remoteTranscriptionEnabledProvider)) {
          return const Ok(MeetingProcessingSelection.recordingOnly());
        }
        try {
          final manifest = ref.read(transcriptionModelManifestProvider);
          if (!isSupportedTranscriptionManifest(manifest)) {
            return const Err(
              NewRecordingProcessingFailure(
                'recording_processing_profile_unavailable',
              ),
            );
          }
          final profile = ProcessingModelProfile.tryCreate(
            bundleManifestJson: jsonEncode(manifest.toJson()),
            engineVersion: transcriptionEngineVersion,
            parametersJson: TranscriptionParameters.forMeeting(
              meeting: meeting,
              manifest: manifest,
            ).canonicalJson,
          );
          return switch (profile) {
            Ok(:final value) => Ok(
              MeetingProcessingSelection.postSession(
                refinement: value,
              ),
            ),
            Err() => const Err(
              NewRecordingProcessingFailure(
                'recording_processing_profile_unavailable',
              ),
            ),
          };
        } on Object {
          return const Err(
            NewRecordingProcessingFailure(
              'recording_processing_profile_unavailable',
            ),
          );
        }
    }
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
