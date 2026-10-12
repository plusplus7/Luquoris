import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/storage_privacy/domain/rebuildable_cache.dart';
import 'package:loquiris/features/storage_privacy/domain/storage_accounting.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Clock used by Riverpod-owned application logic.
final clockProvider = Provider<Clock>((ref) => clock);

/// Native capture boundary; bootstrap must override this provider.
final audioCaptureServiceProvider = Provider<AudioCaptureService>(
  (ref) => throw UnimplementedError('AudioCaptureService is not installed'),
);

/// Native validated local playback boundary; bootstrap must override it.
final sessionPlaybackServiceProvider = Provider<SessionPlaybackService>(
  (ref) => throw UnimplementedError('SessionPlaybackService is not installed'),
);

/// Native application-storage boundary; bootstrap must override this provider.
final storageMetricsServiceProvider = Provider<StorageMetricsService>(
  (ref) => throw UnimplementedError('StorageMetricsService is not installed'),
);

/// Safe derived-cache cleanup boundary; bootstrap must override this provider.
final rebuildableCacheServiceProvider = Provider<RebuildableCacheService>(
  (ref) => throw UnimplementedError('RebuildableCacheService is not installed'),
);

/// Local transcription boundary; bootstrap must override this provider.
final transcriptionEngineProvider = Provider<TranscriptionEngine>(
  (ref) => throw UnimplementedError('TranscriptionEngine is not installed'),
);

/// Local language boundary; bootstrap must override this provider.
final languageIdentificationEngineProvider =
    Provider<LanguageIdentificationEngine>(
      (ref) => throw UnimplementedError(
        'LanguageIdentificationEngine is not installed',
      ),
    );

/// Local diarization boundary; bootstrap must override this provider.
final speakerDiarizationEngineProvider = Provider<SpeakerDiarizationEngine>(
  (ref) =>
      throw UnimplementedError('SpeakerDiarizationEngine is not installed'),
);

/// Bundled model boundary; bootstrap must override this provider.
final modelManagerProvider = Provider<ModelManager>(
  (ref) => throw UnimplementedError('ModelManager is not installed'),
);

/// Thermal boundary; bootstrap must override this provider.
final thermalAndPerformanceMonitorProvider =
    Provider<ThermalAndPerformanceMonitor>(
      (ref) => throw UnimplementedError(
        'ThermalAndPerformanceMonitor is not installed',
      ),
    );

/// Session persistence boundary; bootstrap must override this provider.
final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => throw UnimplementedError('SessionRepository is not installed'),
);

/// Transcript-version persistence boundary; bootstrap must override it.
final transcriptRepositoryProvider = Provider<TranscriptRepository>(
  (ref) => throw UnimplementedError('TranscriptRepository is not installed'),
);

/// Durable transcription-job boundary; bootstrap must override it.
final transcriptionJobRepositoryProvider = Provider<TranscriptionJobRepository>(
  (ref) =>
      throw UnimplementedError('TranscriptionJobRepository is not installed'),
);

/// Bundled-model manifest persistence boundary; bootstrap must override it.
final modelRepositoryProvider = Provider<ModelRepository>(
  (ref) => throw UnimplementedError('ModelRepository is not installed'),
);

/// Human-revision persistence boundary; bootstrap must override it.
final revisionRepositoryProvider = Provider<RevisionRepository>(
  (ref) => throw UnimplementedError('RevisionRepository is not installed'),
);

/// User-authorized export boundary; bootstrap must override this provider.
final exportServiceProvider = Provider<ExportService>(
  (ref) => throw UnimplementedError('ExportService is not installed'),
);

/// Reads the newest privacy-safe export failure for one meeting.
typedef ExportFailureHistoryReader =
    Future<Result<String?, ExportFailure>> Function(String meetingId);

/// Durable export history; production overrides this with local persistence.
final exportFailureHistoryProvider = Provider<ExportFailureHistoryReader>(
  (ref) =>
      (meetingId) async => const Ok(null),
);
