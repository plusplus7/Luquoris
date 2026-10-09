import 'dart:convert';

import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/domain/value_object.dart';
import 'package:meta/meta.dart';

/// Reproducible local inference inputs shared by every analysis run.
@immutable
final class InferenceProvenance extends ValueObject {
  /// Creates immutable engine, model, and parameter provenance.
  const InferenceProvenance({
    required this.engineId,
    required this.engineVersion,
    required this.modelId,
    required this.modelVersion,
    required this.modelSha256,
    required this.parametersJson,
  });

  /// Stable inference-engine identifier.
  final String engineId;

  /// Exact inference-engine build or release.
  final String engineVersion;

  /// Stable bundled-model identifier.
  final String modelId;

  /// Exact bundled-model version.
  final String modelVersion;

  /// Integrity digest of the model bytes used by the run.
  final String modelSha256;

  /// Canonical JSON containing the actual inference parameters.
  final String parametersJson;

  @override
  List<Object?> get equalityValues => <Object?>[
    engineId,
    engineVersion,
    modelId,
    modelVersion,
    modelSha256,
    parametersJson,
  ];
}

/// Closed lifecycle carrying timestamps, progress, and structured failure.
@immutable
sealed class AnalysisState extends ValueObject {
  /// Creates an analysis state.
  const AnalysisState();
}

/// Analysis is waiting for local resources.
final class AnalysisQueued extends AnalysisState {
  /// Creates a queued analysis state.
  const AnalysisQueued();

  @override
  List<Object?> get equalityValues => const <Object?>[];
}

/// Analysis is active or resumable from its latest progress.
final class AnalysisRunning extends AnalysisState {
  /// Creates an active analysis state.
  const AnalysisRunning({
    required this.startedAtUtcMs,
    required this.progress,
  }) : assert(startedAtUtcMs >= 0, 'startedAtUtcMs must be non-negative'),
       assert(
         progress >= 0 && progress <= 1,
         'progress must be between zero and one',
       );

  /// UTC start instant in epoch milliseconds.
  final int startedAtUtcMs;

  /// Normalized completion fraction.
  final double progress;

  @override
  List<Object?> get equalityValues => <Object?>[startedAtUtcMs, progress];
}

/// Analysis completed successfully.
final class AnalysisCompleted extends AnalysisState {
  /// Creates a completed analysis state.
  const AnalysisCompleted({
    required this.startedAtUtcMs,
    required this.endedAtUtcMs,
  }) : assert(startedAtUtcMs >= 0, 'startedAtUtcMs must be non-negative'),
       assert(endedAtUtcMs >= startedAtUtcMs, 'end must not precede start');

  /// UTC start instant in epoch milliseconds.
  final int startedAtUtcMs;

  /// UTC completion instant in epoch milliseconds.
  final int endedAtUtcMs;

  @override
  List<Object?> get equalityValues => <Object?>[startedAtUtcMs, endedAtUtcMs];
}

/// Analysis stopped with a stable, privacy-safe failure code.
final class AnalysisFailed extends AnalysisState {
  /// Creates a failed analysis state.
  const AnalysisFailed({
    required this.startedAtUtcMs,
    required this.endedAtUtcMs,
    required this.progress,
    required this.failureCode,
  }) : assert(startedAtUtcMs >= 0, 'startedAtUtcMs must be non-negative'),
       assert(endedAtUtcMs >= startedAtUtcMs, 'end must not precede start'),
       assert(
         progress >= 0 && progress <= 1,
         'progress must be between zero and one',
       );

  /// UTC start instant in epoch milliseconds.
  final int startedAtUtcMs;

  /// UTC failure instant in epoch milliseconds.
  final int endedAtUtcMs;

  /// Last durably persisted completion fraction.
  final double progress;

  /// Stable failure code that excludes user content.
  final String failureCode;

  @override
  List<Object?> get equalityValues => <Object?>[
    startedAtUtcMs,
    endedAtUtcMs,
    progress,
    failureCode,
  ];
}

/// Kind of resumable local processing work.
enum ProcessingJobKind {
  /// Speech-to-text processing.
  transcription,

  /// Segment language identification.
  languageIdentification,

  /// Post-session speaker diarization.
  speakerDiarization,

  /// Rebuildable continuous-audio muxing.
  audioMerge,

  /// Rebuildable waveform creation.
  waveform,
}

/// Privacy-safe durable resume boundary for post-session transcription.
@immutable
final class TranscriptionCheckpoint extends ValueObject {
  /// Creates a checkpoint containing no audio or transcript content.
  const TranscriptionCheckpoint({
    required this.completedMedia,
    required this.parameterVersion,
  }) : assert(parameterVersion > 0, 'parameterVersion must be positive');

  /// Last media boundary durably completed by the engine.
  final Duration completedMedia;

  /// Canonical inference-parameter schema used by the resumed run.
  final int parameterVersion;

  /// Encodes the allowlisted checkpoint fields in canonical key order.
  String toStorageJson() => jsonEncode(<String, int>{
    'completedMediaUs': completedMedia.inMicroseconds,
    'parameterVersion': parameterVersion,
  });

  /// Decodes an allowlisted checkpoint, returning `null` for any other shape.
  static TranscriptionCheckpoint? tryParse(String? source) {
    if (source == null) return null;
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, Object?> || decoded.length != 2) {
        return null;
      }
      final completedMediaUs = decoded['completedMediaUs'];
      final parameterVersion = decoded['parameterVersion'];
      if (completedMediaUs is! int ||
          parameterVersion is! int ||
          completedMediaUs < 0 ||
          parameterVersion <= 0) {
        return null;
      }
      return TranscriptionCheckpoint(
        completedMedia: Duration(microseconds: completedMediaUs),
        parameterVersion: parameterVersion,
      );
    } on FormatException {
      return null;
    }
  }

  @override
  List<Object?> get equalityValues => <Object?>[
    completedMedia,
    parameterVersion,
  ];
}

/// Closed state of one local processing job.
@immutable
sealed class ProcessingState extends ValueObject {
  /// Creates a processing state.
  const ProcessingState();
}

/// Job is waiting for resources.
final class ProcessingQueued extends ProcessingState {
  /// Creates a queued state.
  const ProcessingQueued();

  @override
  List<Object?> get equalityValues => const <Object?>[];
}

/// Job is actively processing.
final class ProcessingRunning extends ProcessingState {
  /// Creates a running state with normalized [progress].
  const ProcessingRunning({required this.progress})
    : assert(
        progress >= 0 && progress <= 1,
        'progress must be between zero and one',
      );

  /// Normalized completion fraction.
  final double progress;

  @override
  List<Object?> get equalityValues => <Object?>[progress];
}

/// Job was deliberately paused or deferred.
final class ProcessingPaused extends ProcessingState {
  /// Creates a paused state.
  const ProcessingPaused({required this.reasonCode});

  /// Stable machine-readable pause reason.
  final String reasonCode;

  @override
  List<Object?> get equalityValues => <Object?>[reasonCode];
}

/// Job finished successfully.
final class ProcessingSucceeded extends ProcessingState {
  /// Creates a successful state.
  const ProcessingSucceeded();

  @override
  List<Object?> get equalityValues => const <Object?>[];
}

/// Job finished with a structured failure.
final class ProcessingFailed extends ProcessingState {
  /// Creates a failed state.
  const ProcessingFailed({required this.failureCode});

  /// Stable failure code without user content.
  final String failureCode;

  @override
  List<Object?> get equalityValues => <Object?>[failureCode];
}

/// Durable resumable local processing job.
@immutable
final class ProcessingJob extends ValueObject {
  /// Creates a processing job.
  const ProcessingJob({
    required this.id,
    required this.meetingId,
    required this.kind,
    required this.createdAtUtcMs,
    required this.state,
    this.targetRunId,
    this.modelId,
    this.checkpoint,
  }) : assert(createdAtUtcMs >= 0, 'createdAtUtcMs must be non-negative');

  static const _unset = Object();

  /// Stable job identifier.
  final String id;

  /// Meeting whose derived data is being produced.
  final String meetingId;

  /// Processing capability requested.
  final ProcessingJobKind kind;

  /// UTC creation instant in epoch milliseconds.
  final int createdAtUtcMs;

  /// Current closed job state.
  final ProcessingState state;

  /// Transcript or diarization run produced by this job.
  final String? targetRunId;

  /// Model manifest selected for the work, when applicable.
  final String? modelId;

  /// Opaque engine checkpoint that contains no transcript content.
  final String? checkpoint;

  /// Typed transcription checkpoint, or `null` for another job kind/shape.
  TranscriptionCheckpoint? get transcriptionCheckpoint =>
      TranscriptionCheckpoint.tryParse(checkpoint);

  /// Returns a copy with changed resumable job state.
  ProcessingJob copyWith({
    ProcessingState? state,
    Object? targetRunId = _unset,
    Object? modelId = _unset,
    Object? checkpoint = _unset,
  }) => ProcessingJob(
    id: id,
    meetingId: meetingId,
    kind: kind,
    createdAtUtcMs: createdAtUtcMs,
    state: state ?? this.state,
    targetRunId: identical(targetRunId, _unset)
        ? this.targetRunId
        : targetRunId as String?,
    modelId: identical(modelId, _unset) ? this.modelId : modelId as String?,
    checkpoint: identical(checkpoint, _unset)
        ? this.checkpoint
        : checkpoint as String?,
  );

  @override
  List<Object?> get equalityValues => <Object?>[
    id,
    meetingId,
    kind,
    createdAtUtcMs,
    state,
    targetRunId,
    modelId,
    checkpoint,
  ];
}

/// Capability supplied by an installed local model.
enum ModelCapability {
  /// Speech-to-text inference.
  transcription,

  /// Language identification.
  languageIdentification,

  /// Speaker diarization.
  speakerDiarization,
}

/// User-selectable processing profile that a model has passed.
enum PerformanceMode {
  /// Larger model and higher resource allowance.
  highQuality,

  /// Default accuracy and resource balance.
  balanced,

  /// Reduced concurrency or a smaller model.
  powerSaving,

  /// Capture without inference.
  recordingOnly,

  /// Run inference after capture ends.
  postSession,
}

/// Integrity-verifiable model bundled with the application.
@immutable
final class InstalledModel extends ValueObject {
  /// Creates a complete immutable model manifest.
  InstalledModel({
    required this.id,
    required this.version,
    required this.source,
    required this.sha256,
    required this.bytes,
    required List<ModelCapability> capabilities,
    required this.expectedEngineId,
    required this.licenseId,
    required this.licenseSnapshotPath,
    required List<PerformanceMode> enabledModes,
  }) : capabilities = List<ModelCapability>.unmodifiable(capabilities),
       enabledModes = List<PerformanceMode>.unmodifiable(enabledModes),
       assert(bytes >= 0, 'bytes must be non-negative');

  /// Stable manifest identifier.
  final String id;

  /// Model release version.
  final String version;

  /// Reviewed upstream source reference.
  final String source;

  /// Expected SHA-256 digest.
  final String sha256;

  /// Installed file size.
  final int bytes;

  /// Inference capabilities supplied by the same bundled artifact.
  final List<ModelCapability> capabilities;

  /// Engine identifier allowed to load this model format.
  final String expectedEngineId;

  /// SPDX license identifier or reviewed license key.
  final String licenseId;

  /// Bundled immutable snapshot of the reviewed license text.
  final AppRelativePath licenseSnapshotPath;

  /// Modes for which this model has passed the required evidence gates.
  final List<PerformanceMode> enabledModes;

  /// Returns an immutable descriptor with replaced manifest metadata.
  InstalledModel copyWith({
    String? version,
    String? source,
    String? sha256,
    int? bytes,
    List<ModelCapability>? capabilities,
    String? expectedEngineId,
    String? licenseId,
    AppRelativePath? licenseSnapshotPath,
    List<PerformanceMode>? enabledModes,
  }) => InstalledModel(
    id: id,
    version: version ?? this.version,
    source: source ?? this.source,
    sha256: sha256 ?? this.sha256,
    bytes: bytes ?? this.bytes,
    capabilities: capabilities ?? this.capabilities,
    expectedEngineId: expectedEngineId ?? this.expectedEngineId,
    licenseId: licenseId ?? this.licenseId,
    licenseSnapshotPath: licenseSnapshotPath ?? this.licenseSnapshotPath,
    enabledModes: enabledModes ?? this.enabledModes,
  );

  @override
  List<Object?> get equalityValues => <Object?>[
    id,
    version,
    source,
    sha256,
    bytes,
    capabilities.length,
    ...capabilities,
    expectedEngineId,
    licenseId,
    licenseSnapshotPath,
    enabledModes.length,
    ...enabledModes,
  ];
}
