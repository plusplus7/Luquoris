import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/services/service_contracts.dart';

/// One composition-selected live source; no engine fallback or model selection.
typedef LiveTranscriptSessionStarter =
    Future<Result<LiveTranscriptionSession?, TranscriptionFailure>> Function(
      String meetingId,
    );

/// Preserves the legacy source until an explicitly enabled root overrides it.
final liveTranscriptSessionStarterProvider =
    Provider<LiveTranscriptSessionStarter>(
      (ref) =>
          ref.watch(transcriptionCoordinatorProvider.notifier).startLiveDraft,
    );
