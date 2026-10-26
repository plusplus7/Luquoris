import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:meta/meta.dart';

/// Frozen execution owner and verified complete-input identity; no paths or draft text.
@immutable
final class RefinementExecutionInput {
  /// Creates execution inputs from the durable run and verified audio inventory.
  const RefinementExecutionInput({
    required this.meetingId,
    required this.runId,
    required this.audioInventorySha256,
    required this.totalSamples,
    required this.profile,
  });

  /// Meeting whose finalized original audio must be reverified natively.
  final String meetingId;

  /// Exact durable refinement run, independent of local model catalog aliases.
  final String runId;

  /// SHA-256 of all journal-authorized original audio.
  final String audioInventorySha256;

  /// Complete 16 kHz sample count, used to reject out-of-input native timestamps.
  final int totalSamples;

  /// Entire frozen manifest, runtime and decoding parameters.
  final ProcessingModelProfile profile;
}

/// Content-free execution outcome; resource pauses are not permanent failures.
sealed class RefinementExecutionFailure implements Failure {
  const RefinementExecutionFailure(this.code);

  @override
  final String code;
}

/// The complete pass could not be authorized or completed.
final class RefinementExecutionUnavailable extends RefinementExecutionFailure {
  /// Creates a stable execution rejection without native diagnostic contents.
  const RefinementExecutionUnavailable(super.code);
}

/// Recording or another resource owner requires an actionable later retry.
final class RefinementExecutionDeferred extends RefinementExecutionFailure {
  /// Creates a resource-priority pause rather than an input-corruption claim.
  const RefinementExecutionDeferred(super.code);
}

/// The platform lost its terminal acknowledgement; cleanup is not confirmed.
final class RefinementExecutionUnsettled extends RefinementExecutionFailure {
  /// Requires retaining the durable running owner until process recovery.
  const RefinementExecutionUnsettled()
    : super('refinement_cleanup_unconfirmed');
}

/// Cooperative cancellation completed without publishing a transcript version.
final class RefinementExecutionCancelled extends RefinementExecutionFailure {
  /// Creates an explicit cancellation outcome.
  const RefinementExecutionCancelled()
    : super('refinement_execution_cancelled');
}

/// Injectable complete-pass execution, separate from the legacy/live engine role.
abstract interface class RefinementExecutionService {
  /// Revalidates frozen inputs; ordinary outcomes imply native cleanup has settled.
  ///
  /// A timeout requests cancellation and waits for the original terminal reply.
  /// [RefinementExecutionUnsettled] alone reports lost ownership acknowledgement;
  /// callers must not finalize, release or retry that owner in the same process.
  @useResult
  Future<Result<TranscriptionOutput, RefinementExecutionFailure>> transcribe(
    RefinementExecutionInput input,
  );

  /// Requests cancellation only for this meeting/run owner, without claiming release.
  @useResult
  Future<Result<void, RefinementExecutionFailure>> cancel({
    required String meetingId,
    required String runId,
  });
}

/// Composition root must install the platform implementation before execution.
final refinementExecutionServiceProvider = Provider<RefinementExecutionService>(
  (ref) => throw UnimplementedError('Refinement execution is not installed'),
);
