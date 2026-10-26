import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/features/transcript/application/refinement_runner.dart';
import 'package:loquiris/features/transcript/application/refinement_scheduler.dart';
import 'package:loquiris/services/meeting_processing_selection_repository.dart';
import 'package:loquiris/services/refinement_audio_inventory_service.dart';
import 'package:loquiris/services/refinement_execution_service.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:loquiris/services/transcript_processing_repository.dart';

/// Process-local quarantine after a native terminal owner cannot be confirmed.
///
/// There is deliberately no reset: only a new process can recover durable work.
final class TranscriptionInferenceBarrier {
  bool _cleanupUnconfirmed = false;

  /// Whether all optional inference must remain blocked in this process.
  bool get cleanupUnconfirmed => _cleanupUnconfirmed;

  /// Retains the quarantine across coordinator/screen reconstruction.
  void retainUnconfirmedCleanup() {
    _cleanupUnconfirmed = true;
  }
}

/// Shared by legacy and explicit execution without constructing either engine.
final transcriptionInferenceBarrierProvider =
    Provider<TranscriptionInferenceBarrier>(
      (ref) => TranscriptionInferenceBarrier(),
    );

/// Process-lifetime queue construction over composition-root-installed authorities.
final refinementSchedulerProvider = Provider<RefinementScheduler>(
  (ref) => RefinementScheduler(
    sessions: ref.watch(sessionRepositoryProvider),
    selections: ref.watch(meetingProcessingSelectionRepositoryProvider),
    processing: ref.watch(transcriptProcessingRepositoryProvider),
    jobs: ref.watch(transcriptionJobRepositoryProvider),
    models: ref.watch(modelRepositoryProvider),
    transcripts: ref.watch(transcriptRepositoryProvider),
    audio: ref.watch(refinementAudioInventoryServiceProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// One process-local execution owner, retained across screen navigation.
final refinementRunnerProvider = Provider<RefinementRunner>(
  (ref) => RefinementRunner(
    sessions: ref.watch(sessionRepositoryProvider),
    jobs: ref.watch(transcriptionJobRepositoryProvider),
    processing: ref.watch(transcriptProcessingRepositoryProvider),
    audio: ref.watch(refinementAudioInventoryServiceProvider),
    execution: ref.watch(refinementExecutionServiceProvider),
    clock: ref.watch(clockProvider),
  ),
);
