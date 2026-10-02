import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/features/models_performance/domain/benchmark_resource_metrics.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:meta/meta.dart';

/// Immutable input used by the short on-device performance check.
@immutable
final class BenchmarkDefinition extends ValueObject {
  /// Creates one fixed benchmark definition.
  const BenchmarkDefinition({
    required this.id,
    required this.sha256,
    required this.bytes,
    required this.mediaDuration,
  });

  /// Stable benchmark corpus identifier.
  final String id;

  /// SHA-256 of the exact bundled audio bytes.
  final String sha256;

  /// Exact bundled audio byte length.
  final int bytes;

  /// Media duration represented by the bundled audio.
  final Duration mediaDuration;

  @override
  List<Object?> get equalityValues => <Object?>[
    id,
    sha256,
    bytes,
    mediaDuration,
  ];
}

/// The reviewed 45-second Mandarin and English benchmark input.
const firstRunBenchmarkDefinition = BenchmarkDefinition(
  id: 'zh-en-mixed-v1',
  sha256: '83440d4ccbd82dafd1a88346ab448e1dd309e408c598d665413b910cc92c40a7',
  bytes: 1440044,
  mediaDuration: Duration(seconds: 45),
);

/// Whether a benchmark runner can start on the current installation.
@immutable
sealed class BenchmarkAvailability extends ValueObject {
  const BenchmarkAvailability();
}

/// The benchmark runtime is ready for an explicit run.
final class BenchmarkAvailable extends BenchmarkAvailability {
  /// Creates an available state.
  const BenchmarkAvailable();

  @override
  List<Object?> get equalityValues => const <Object?>[];
}

/// The benchmark runtime cannot currently execute.
final class BenchmarkUnavailable extends BenchmarkAvailability {
  /// Creates an unavailable state with a stable [reasonCode].
  const BenchmarkUnavailable(this.reasonCode);

  /// Privacy-safe reason suitable for localized mapping.
  final String reasonCode;

  @override
  List<Object?> get equalityValues => <Object?>[reasonCode];
}

/// Evidence status for one candidate operating mode.
enum BenchmarkMeasurementStatus {
  /// Required measurements were captured.
  measured,

  /// The mode ran but encountered a blocking failure.
  failed,

  /// The runner did not measure this mode.
  unmeasured,
}

/// One immutable mode-specific observation from a benchmark run.
@immutable
final class BenchmarkModeMeasurement extends ValueObject {
  /// Creates an observation without interpreting eligibility.
  BenchmarkModeMeasurement({
    required this.mode,
    required this.status,
    this.realTimeFactor,
    this.firstTextLatency,
    this.maximumBacklog,
    List<String> blockingReasonCodes = const <String>[],
  }) : blockingReasonCodes = List<String>.unmodifiable(blockingReasonCodes);

  /// Candidate mode evaluated by this observation.
  final PerformanceMode mode;

  /// Whether this observation is measured, failed, or absent.
  final BenchmarkMeasurementStatus status;

  /// Wall processing seconds divided by processed audio seconds.
  final double? realTimeFactor;

  /// Time from qualifying speech to first non-empty local draft.
  final Duration? firstTextLatency;

  /// Largest runner-owned queued work count observed for this mode.
  final int? maximumBacklog;

  /// Privacy-safe reasons that prevent this mode from being eligible.
  final List<String> blockingReasonCodes;

  @override
  List<Object?> get equalityValues => <Object?>[
    mode,
    status,
    realTimeFactor,
    firstTextLatency,
    maximumBacklog,
    blockingReasonCodes.length,
    ...blockingReasonCodes,
  ];
}

/// Versioned output from one fixed benchmark execution.
@immutable
final class PerformanceBenchmarkReport extends ValueObject {
  /// Creates a report whose validity is checked by the policy boundary.
  PerformanceBenchmarkReport({
    required this.schemaVersion,
    required this.policyVersion,
    required this.definition,
    required this.engineId,
    required this.engineVersion,
    required this.modelId,
    required this.modelVersion,
    required this.configurationId,
    required List<BenchmarkModeMeasurement> measurements,
    this.resourceMetrics,
  }) : measurements = List<BenchmarkModeMeasurement>.unmodifiable(
         measurements,
       );

  /// Report schema interpreted by this application.
  final int schemaVersion;

  /// Recommendation-policy revision expected for this report.
  final int policyVersion;

  /// Exact bundled input used by the runner.
  final BenchmarkDefinition definition;

  /// Stable local inference-engine identifier.
  final String engineId;

  /// Exact local inference-engine version.
  final String engineVersion;

  /// Stable bundled-model identifier.
  final String modelId;

  /// Exact bundled-model version.
  final String modelVersion;

  /// Stable execution configuration, such as a CPU baseline.
  final String configurationId;

  /// Mode evidence emitted by the runner.
  final List<BenchmarkModeMeasurement> measurements;

  /// Optional schema-v2 before/after resource observations.
  final BenchmarkResourceMetrics? resourceMetrics;

  /// Returns a report with selected resource-envelope fields replaced.
  PerformanceBenchmarkReport copyWith({
    int? schemaVersion,
    BenchmarkResourceMetrics? resourceMetrics,
  }) => PerformanceBenchmarkReport(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    policyVersion: policyVersion,
    definition: definition,
    engineId: engineId,
    engineVersion: engineVersion,
    modelId: modelId,
    modelVersion: modelVersion,
    configurationId: configurationId,
    measurements: measurements,
    resourceMetrics: resourceMetrics ?? this.resourceMetrics,
  );

  @override
  List<Object?> get equalityValues => <Object?>[
    schemaVersion,
    policyVersion,
    definition,
    engineId,
    engineVersion,
    modelId,
    modelVersion,
    configurationId,
    measurements.length,
    ...measurements,
    resourceMetrics,
  ];
}

/// Advisory mode selection derived from measured evidence.
@immutable
final class BenchmarkRecommendation extends ValueObject {
  /// Creates a recommendation with privacy-safe [reasonCodes].
  BenchmarkRecommendation({
    required this.mode,
    required List<String> reasonCodes,
    required this.shortCheckOnly,
    this.evidence,
  }) : reasonCodes = List<String>.unmodifiable(reasonCodes);

  /// Recommended conservative operating mode.
  final PerformanceMode mode;

  /// Stable reasons mapped to localized explanations by presentation.
  final List<String> reasonCodes;

  /// Whether this recommendation is limited to the short first-run check.
  final bool shortCheckOnly;

  /// The measurement that qualified the mode, absent for recording-only.
  final BenchmarkModeMeasurement? evidence;

  @override
  List<Object?> get equalityValues => <Object?>[
    mode,
    reasonCodes.length,
    ...reasonCodes,
    shortCheckOnly,
    evidence,
  ];
}

/// Recoverable privacy-safe failure produced by benchmark processing.
@immutable
sealed class BenchmarkFailure extends ValueObject implements Failure {
  const BenchmarkFailure(this.code);

  @override
  final String code;

  @override
  List<Object?> get equalityValues => <Object?>[code];
}

/// A runner report or event violated the benchmark contract.
final class BenchmarkInvalidOutput extends BenchmarkFailure {
  /// Creates an invalid-output failure.
  const BenchmarkInvalidOutput() : super('benchmark_invalid_output');
}

/// The local benchmark runtime was absent or stopped unexpectedly.
final class BenchmarkRuntimeFailure extends BenchmarkFailure {
  /// Creates a runtime failure with a stable [code].
  const BenchmarkRuntimeFailure(super.code);
}

/// The fixed bundled benchmark asset was absent or invalid.
final class BenchmarkAssetFailure extends BenchmarkFailure {
  /// Creates an asset failure with a stable [code].
  const BenchmarkAssetFailure(super.code);
}

/// The local inference engine could not complete the run.
final class BenchmarkEngineFailure extends BenchmarkFailure {
  /// Creates an engine failure with a stable [code].
  const BenchmarkEngineFailure(super.code);
}

/// The user deliberately cancelled the benchmark.
final class BenchmarkCancelledFailure extends BenchmarkFailure {
  /// Creates a cancellation failure.
  const BenchmarkCancelledFailure() : super('benchmark_cancelled');
}
