import 'package:loquiris/core/result.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Commands accepted by the native foreground recorder.
enum RecordingControlCommand {
  /// Starts a new meeting capture.
  start,

  /// Starts a new segment only after explicit recovery confirmation.
  continueRecovery,

  /// Pauses the active capture.
  pause,

  /// Resumes a user-paused capture.
  resume,

  /// Durably finalizes the active capture.
  stop,
}

/// Durable Android-side outcome for one correlated command.
sealed class RecordingCommandReceipt {
  const RecordingCommandReceipt();
}

/// Receipt indicating that Android has not reached a terminal outcome yet.
final class RecordingCommandPending extends RecordingCommandReceipt {
  /// Creates a pending receipt.
  const RecordingCommandPending();
}

/// Receipt carrying the authoritative persisted snapshot after success.
final class RecordingCommandSucceeded extends RecordingCommandReceipt {
  /// Creates a successful receipt for [snapshot].
  const RecordingCommandSucceeded(this.snapshot);

  /// Snapshot persisted by the native recording state machine.
  final AudioCaptureSnapshot snapshot;
}

/// Receipt carrying the typed terminal command failure.
final class RecordingCommandFailed extends RecordingCommandReceipt {
  /// Creates a failed receipt for [failure].
  const RecordingCommandFailed(this.failure);

  /// Authoritative failure persisted by Android.
  final AudioCaptureFailure failure;
}

/// Value-typed seam around the Android recording channel.
abstract interface class RecordingControlGateway {
  /// Requests the Android runtime permission required to capture microphone audio.
  Future<Result<void, AudioCaptureFailure>> requestMicrophonePermission();

  /// Reads the persisted native state without starting capture.
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> current();

  /// Finalizes recovered audio without dispatching a microphone command.
  Future<Result<AudioCaptureSnapshot, AudioCaptureFailure>> saveRecovery(
    String sessionId,
  );

  /// Requests a native command and returns its durable correlation ID.
  Future<Result<String, AudioCaptureFailure>> dispatch(
    RecordingControlCommand command, {
    String? sessionId,
  });

  /// Reads the durable terminal or pending outcome for [commandId].
  Future<Result<RecordingCommandReceipt, AudioCaptureFailure>> receipt(
    String commandId,
  );
}
