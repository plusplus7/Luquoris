import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/remote_transcription/domain/remote_transcript.dart';
import 'package:loquiris/services/remote_transcription_service.dart';

/// Immutable destination binding without exposing its encrypted credential.
final class RemoteDestination {
  /// Freezes one destination and model profile for a new requested run.
  const RemoteDestination(this.endpoint, this.credentialRef, this.profileId);

  /// HTTPS or private-LAN HTTP origin without query, path or credentials.
  final String endpoint;

  /// Opaque local credential reference, never an API token.
  final String credentialRef;

  /// Requested server profile.
  final String profileId;
}

/// Persisted remote task observation independent of platform scheduling.
final class RemoteTask {
  /// Carries only public progress and typed errors to the screen.
  const RemoteTask({
    required this.id,
    required this.state,
    required this.confirmedBytes,
    required this.totalBytes,
    this.failureCode,
    this.expiresAtUtcMs,
    this.retentionSeconds,
  });

  /// Local run identity reused across retries.
  final String id;

  /// Durable synchronization phase.
  final String state;

  /// Durably acknowledged bytes.
  final int confirmedBytes;

  /// Complete upload size in bytes.
  final int totalBytes;

  /// Content-free error code.
  final String? failureCode;

  /// Advertised server retention duration in seconds.
  final int? retentionSeconds;

  /// Actual server expiry when known.
  final int? expiresAtUtcMs;
}

/// Local result plus a separate user-authored correction.
final class RemoteVersion {
  /// Keeps machine output immutable across human edits.
  const RemoteVersion({
    required this.id,
    required this.result,
    required this.resultJson,
    this.editedText,
  });

  /// Local stable version identity.
  final String id;

  /// Validated server result.
  final RemoteTranscript result;

  /// Original JSON, including immutable provenance and timestamps.
  final String resultJson;

  /// Human correction, never sent back as machine text.
  final String? editedText;

  /// Text selected for reading and plain-text export.
  String get displayedText => editedText ?? result.text;
}

/// Single Dart write path for user intents; native work writes protocol observations.
abstract interface class RemoteTranscriptionRepository {
  /// Lists tasks and versions from durable storage for one meeting.
  Future<
    Result<(List<RemoteTask>, List<RemoteVersion>), RemoteTranscriptionFailure>
  >
  load(String meetingId);

  /// Uses the most recent explicit destination without storing its token.
  Future<Result<RemoteDestination?, RemoteTranscriptionFailure>>
  latestDestination();

  /// Persists a new run before registering disposable OS work.
  Future<Result<String, RemoteTranscriptionFailure>> enqueue(
    String meetingId, {
    RemoteDestination? destination,
  });

  /// Binds only unconfigured work; a bound run never switches destination.
  Future<Result<void, RemoteTranscriptionFailure>> configure(
    String meetingId,
    RemoteDestination destination,
  );

  /// Binds previously opted-in unconfigured runs without creating tasks or resuming restores.
  Future<Result<void, RemoteTranscriptionFailure>> configurePending(
    RemoteDestination destination,
  );

  /// Cancels locally first so late responses cannot resurrect the run.
  Future<Result<void, RemoteTranscriptionFailure>> cancel(String runId);

  /// Saves a local correction without replacing raw server output.
  Future<Result<void, RemoteTranscriptionFailure>> edit(
    String runId,
    String text,
  );
}

/// Composition root supplies the Drift-backed implementation.
final remoteTranscriptionRepositoryProvider =
    Provider<RemoteTranscriptionRepository>(
      (ref) => throw UnimplementedError(
        'Remote transcription repository is not installed',
      ),
    );
