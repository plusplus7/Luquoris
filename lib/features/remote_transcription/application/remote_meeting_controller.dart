import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/export_backup/application/local_export_service.dart';
import 'package:loquiris/services/remote_transcription_repository.dart';
import 'package:loquiris/services/remote_transcription_service.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:uuid/uuid.dart';

/// Export uses the existing user-selected local document destination.
final remoteExportGatewayProvider = Provider<ExportDestinationGateway>(
  (ref) =>
      throw UnimplementedError('Remote export destination is not installed'),
);

/// Immutable projection of one meeting's retained remote work.
final class RemoteMeetingState {
  /// Creates a projection without duplicating durable task state.
  const RemoteMeetingState({
    this.tasks = const [],
    this.versions = const [],
    this.failureCode,
    this.busy = false,
  });

  /// Most recent tasks, including failures and expired remote results.
  final List<RemoteTask> tasks;

  /// Locally retained results, including human corrections.
  final List<RemoteVersion> versions;

  /// Typed failure mapped by localization.
  final String? failureCode;

  /// Whether a committing user action is awaiting acknowledgement.
  final bool busy;
}

/// Screen-lifetime user intents over repository and platform interfaces.
final class RemoteMeetingController extends AsyncNotifier<RemoteMeetingState> {
  /// Reconstructs a projection from the stable meeting route identity.
  RemoteMeetingController(this.meetingId);

  /// Meeting whose original recording authorizes this work.
  final String meetingId;
  bool _reading = false;

  RemoteTranscriptionRepository get _repository =>
      ref.read(remoteTranscriptionRepositoryProvider);

  @override
  Future<RemoteMeetingState> build() async {
    final timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(refresh()),
    );
    ref.onDispose(timer.cancel);
    return _load();
  }

  Future<RemoteMeetingState> _load() async {
    final result = await _repository.load(meetingId);
    return switch (result) {
      Ok(:final value) => RemoteMeetingState(
        tasks: List.unmodifiable(value.$1),
        versions: List.unmodifiable(value.$2),
      ),
      Err(:final failure) => RemoteMeetingState(failureCode: failure.code),
    };
  }

  /// Observes native committed writes, which do not emit Drift invalidations.
  Future<void> refresh() async {
    if (_reading || state.value?.busy == true) return;
    _reading = true;
    try {
      final value = await _load();
      if (ref.mounted) state = AsyncData(value);
    } finally {
      _reading = false;
    }
  }

  Future<void> _action(
    Future<Result<void, RemoteTranscriptionFailure>> Function() action,
  ) async {
    final current = state.value;
    if (current == null || current.busy) return;
    state = AsyncData(
      RemoteMeetingState(
        tasks: current.tasks,
        versions: current.versions,
        busy: true,
      ),
    );
    final result = await action();
    if (!ref.mounted) return;
    final value = await _load();
    if (!ref.mounted) return;
    state = AsyncData(
      RemoteMeetingState(
        tasks: value.tasks,
        versions: value.versions,
        failureCode: result is Err<void, RemoteTranscriptionFailure>
            ? result.failure.code
            : value.failureCode,
      ),
    );
  }

  /// Requests a new version or leaves a visible configuration-needed intent.
  Future<void> start() => _action(() async {
    final destination = await _repository.latestDestination();
    if (destination case Err(:final failure)) return Err(failure);
    final result = await _repository.enqueue(
      meetingId,
      destination:
          (destination as Ok<RemoteDestination?, RemoteTranscriptionFailure>)
              .value,
    );
    return result.map((_) {});
  });

  /// Encrypts credentials before binding pending work or creating a new run.
  Future<void> configure(String endpoint, String token, String profile) =>
      _action(() async {
        final saved = await ref
            .read(remoteTranscriptionServiceProvider)
            .saveCredential(endpoint, token);
        if (saved case Err(:final failure)) return Err(failure);
        final destination = RemoteDestination(
          endpoint.trim().replaceFirst(RegExp(r'/$'), ''),
          (saved as Ok<String, RemoteTranscriptionFailure>).value,
          profile,
        );
        if (state.value!.tasks.any((task) => task.state == 'waitingSetup')) {
          return _repository.configure(meetingId, destination);
        }
        final result = await _repository.enqueue(
          meetingId,
          destination: destination,
        );
        return result.map((_) {});
      });

  /// Cancels locally before attempting remote cancellation.
  Future<void> cancel(String runId) => _action(() => _repository.cancel(runId));

  /// Stores a human correction independently of raw machine text.
  Future<void> edit(String runId, String text) =>
      _action(() => _repository.edit(runId, text));

  /// Writes a retained version through Android's explicit destination picker.
  Future<void> export(RemoteVersion version, ExportFormat format) => _action(
    () async {
      final extension = switch (format) {
        ExportFormat.json => 'json',
        ExportFormat.subtitles => 'srt',
        _ => 'txt',
      };
      final text = switch (format) {
        ExportFormat.json => jsonEncode({
          'schemaVersion': 1,
          'remoteResult': jsonDecode(version.resultJson),
          'editedText': version.editedText,
        }),
        ExportFormat.subtitles => _subtitles(version),
        _ => version.displayedText,
      };
      final result = await ref
          .read(remoteExportGatewayProvider)
          .save(
            ExportDestinationPayload(
              operationId: const Uuid().v4(),
              sessionId: meetingId,
              format: format,
              suggestedFileName: 'transcript.$extension',
              mimeType: format == ExportFormat.json
                  ? 'application/json'
                  : 'text/plain',
              documents: {
                format == ExportFormat.json
                        ? 'meeting.json'
                        : 'content.$extension':
                    text,
              },
              includeAudio: false,
              allowSegmentFallback: false,
            ),
          );
      return switch (result) {
        Ok() => const Ok(null),
        Err() => const Err(RemoteTranscriptionFailure('remote_export_failed')),
      };
    },
  );
}

String _subtitles(RemoteVersion version) {
  // Free-form human edits have no trustworthy alignment. Subtitle export retains
  // the original timestamped machine version; text/JSON carry human corrections.
  String timestamp(int value) {
    final hours = value ~/ 3600000;
    final minutes = value ~/ 60000 % 60;
    final seconds = value ~/ 1000 % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')},${(value % 1000).toString().padLeft(3, '0')}';
  }

  final buffer = StringBuffer();
  for (var i = 0; i < version.result.segments.length; i++) {
    final segment = version.result.segments[i];
    buffer.writeln(
      '${i + 1}\n${timestamp(segment.startMs)} --> ${timestamp(segment.endMs)}\n${segment.text}\n',
    );
  }
  return buffer.toString();
}

/// One controller per visible meeting, disposed with its polling timer.
final AsyncNotifierProviderFamily<
  RemoteMeetingController,
  RemoteMeetingState,
  String
>
remoteMeetingControllerProvider = AsyncNotifierProvider.autoDispose
    .family<RemoteMeetingController, RemoteMeetingState, String>(
      RemoteMeetingController.new,
    );
