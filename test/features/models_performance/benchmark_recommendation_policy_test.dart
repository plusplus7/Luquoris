import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/application/benchmark_recommendation_policy.dart';
import 'package:loquiris/features/models_performance/domain/benchmark_resource_metrics.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  const policy = BenchmarkRecommendationPolicy();

  test('fixed definition matches bundled manifest', () {
    expect(firstRunBenchmarkDefinition.id, 'zh-en-mixed-v1');
    expect(
      firstRunBenchmarkDefinition.sha256,
      '83440d4ccbd82dafd1a88346ab448e1dd309e408c598d665413b910cc92c40a7',
    );
    expect(firstRunBenchmarkDefinition.bytes, 1440044);
    expect(
      firstRunBenchmarkDefinition.mediaDuration,
      const Duration(seconds: 45),
    );
  });

  test('threshold equality passes each eligible mode', () {
    final cases = <(BenchmarkModeMeasurement, PerformanceMode)>[
      (
        BenchmarkModeMeasurement(
          mode: PerformanceMode.balanced,
          status: BenchmarkMeasurementStatus.measured,
          realTimeFactor: 0.8,
          firstTextLatency: const Duration(seconds: 5),
        ),
        PerformanceMode.balanced,
      ),
      (
        BenchmarkModeMeasurement(
          mode: PerformanceMode.powerSaving,
          status: BenchmarkMeasurementStatus.measured,
          realTimeFactor: 1.2,
          firstTextLatency: const Duration(seconds: 12),
        ),
        PerformanceMode.powerSaving,
      ),
      (
        BenchmarkModeMeasurement(
          mode: PerformanceMode.postSession,
          status: BenchmarkMeasurementStatus.measured,
          realTimeFactor: 1,
        ),
        PerformanceMode.postSession,
      ),
    ];

    for (final (measurement, expectedMode) in cases) {
      final recommendation = _ok(
        policy.recommend(_report([measurement])),
      );
      expect(recommendation.mode, expectedMode);
      expect(recommendation.shortCheckOnly, isTrue);
    }
  });

  test('recommendation uses conservative order', () {
    final recommendation = _ok(
      policy.recommend(
        _report([
          BenchmarkModeMeasurement(
            mode: PerformanceMode.postSession,
            status: BenchmarkMeasurementStatus.measured,
            realTimeFactor: 0.5,
          ),
          BenchmarkModeMeasurement(
            mode: PerformanceMode.powerSaving,
            status: BenchmarkMeasurementStatus.measured,
            realTimeFactor: 0.5,
            firstTextLatency: const Duration(seconds: 2),
          ),
          BenchmarkModeMeasurement(
            mode: PerformanceMode.balanced,
            status: BenchmarkMeasurementStatus.measured,
            realTimeFactor: 0.5,
            firstTextLatency: const Duration(seconds: 2),
          ),
        ]),
      ),
    );

    expect(recommendation.mode, PerformanceMode.balanced);
    expect(recommendation.reasonCodes, ['benchmark_balanced_eligible']);
  });

  test('high quality is never auto selected', () {
    final recommendation = _ok(
      policy.recommend(
        _report([
          BenchmarkModeMeasurement(
            mode: PerformanceMode.highQuality,
            status: BenchmarkMeasurementStatus.measured,
            realTimeFactor: 0.1,
            firstTextLatency: const Duration(milliseconds: 100),
          ),
        ]),
      ),
    );

    expect(recommendation.mode, PerformanceMode.recordingOnly);
    expect(recommendation.reasonCodes, ['benchmark_no_ai_mode_eligible']);
  });

  test('blocking reason defeats passing numbers', () {
    final recommendation = _ok(
      policy.recommend(
        _report([
          BenchmarkModeMeasurement(
            mode: PerformanceMode.balanced,
            status: BenchmarkMeasurementStatus.measured,
            realTimeFactor: 0.5,
            firstTextLatency: const Duration(seconds: 2),
            blockingReasonCodes: const ['benchmark_thermal_blocked'],
          ),
          BenchmarkModeMeasurement(
            mode: PerformanceMode.postSession,
            status: BenchmarkMeasurementStatus.measured,
            realTimeFactor: 0.9,
          ),
        ]),
      ),
    );

    expect(recommendation.mode, PerformanceMode.postSession);
  });

  test('missing metric remains ineligible', () {
    final recommendation = _ok(
      policy.recommend(
        _report([
          BenchmarkModeMeasurement(
            mode: PerformanceMode.balanced,
            status: BenchmarkMeasurementStatus.measured,
            realTimeFactor: 0.5,
          ),
        ]),
      ),
    );

    expect(recommendation.mode, PerformanceMode.recordingOnly);
  });

  test('non finite metrics are invalid', () {
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      final result = policy.recommend(
        _report([
          BenchmarkModeMeasurement(
            mode: PerformanceMode.postSession,
            status: BenchmarkMeasurementStatus.measured,
            realTimeFactor: value,
          ),
        ]),
      );

      expect(_failure(result).code, 'benchmark_invalid_output');
    }
  });

  test('empty execution identity is invalid', () {
    final validMeasurement = BenchmarkModeMeasurement(
      mode: PerformanceMode.postSession,
      status: BenchmarkMeasurementStatus.measured,
      realTimeFactor: 0.5,
    );

    for (final report in [
      _report([validMeasurement], engineId: ''),
      _report([validMeasurement], engineVersion: ''),
      _report([validMeasurement], modelId: ''),
      _report([validMeasurement], modelVersion: ''),
      _report([validMeasurement], configurationId: ''),
    ]) {
      expect(
        _failure(policy.recommend(report)).code,
        'benchmark_invalid_output',
      );
    }
  });

  test('duplicate mode measurement is invalid', () {
    final result = policy.recommend(
      _report([
        BenchmarkModeMeasurement(
          mode: PerformanceMode.postSession,
          status: BenchmarkMeasurementStatus.measured,
          realTimeFactor: 0.5,
        ),
        BenchmarkModeMeasurement(
          mode: PerformanceMode.postSession,
          status: BenchmarkMeasurementStatus.unmeasured,
        ),
      ]),
    );

    expect(_failure(result).code, 'benchmark_invalid_output');
  });

  test('asset and policy mismatch are invalid', () {
    final validMeasurement = BenchmarkModeMeasurement(
      mode: PerformanceMode.postSession,
      status: BenchmarkMeasurementStatus.measured,
      realTimeFactor: 0.5,
    );
    final wrongDefinition = BenchmarkDefinition(
      id: 'different-audio',
      sha256: firstRunBenchmarkDefinition.sha256,
      bytes: firstRunBenchmarkDefinition.bytes,
      mediaDuration: firstRunBenchmarkDefinition.mediaDuration,
    );

    for (final report in [
      _report([validMeasurement], schemaVersion: 3),
      _report([validMeasurement], policyVersion: 2),
      _report([validMeasurement], definition: wrongDefinition),
    ]) {
      expect(
        _failure(policy.recommend(report)).code,
        'benchmark_invalid_output',
      );
    }
  });

  test(
    'schema one stays valid and schema two rejects partial core metrics negative backlog and non finite rtf',
    () {
      final validMeasurement = BenchmarkModeMeasurement(
        mode: PerformanceMode.balanced,
        status: BenchmarkMeasurementStatus.measured,
        realTimeFactor: 0.5,
        firstTextLatency: const Duration(seconds: 2),
        maximumBacklog: 3,
      );
      final validResources = BenchmarkResourceMetrics(
        wallDuration: const Duration(milliseconds: 1500),
        processCpuTime: const Duration(milliseconds: 450),
        maxSampledPssBytes: 12000,
        worstThermalState: ThermalState.hot,
        deviceEnergyUsedNanowattHours: 600,
      );

      expect(
        _ok(policy.recommend(_report([validMeasurement]))).mode,
        PerformanceMode.balanced,
      );
      expect(
        _ok(
          policy.recommend(
            _report(
              [validMeasurement],
              schemaVersion: 2,
              resourceMetrics: validResources,
            ),
          ),
        ).mode,
        PerformanceMode.balanced,
      );

      final invalidReports = [
        _report([validMeasurement], schemaVersion: 2),
        _report(
          [validMeasurement],
          resourceMetrics: validResources,
        ),
        _report(
          [validMeasurement],
          schemaVersion: 2,
          resourceMetrics: BenchmarkResourceMetrics(
            wallDuration: const Duration(milliseconds: 1500),
            unavailableReasonCodes: const ['performance_metrics_invalid_delta'],
          ),
        ),
        _report([
          BenchmarkModeMeasurement(
            mode: PerformanceMode.balanced,
            status: BenchmarkMeasurementStatus.measured,
            realTimeFactor: 0.5,
            firstTextLatency: const Duration(seconds: 2),
            maximumBacklog: -1,
          ),
        ]),
      ];

      for (final report in invalidReports) {
        expect(
          _failure(policy.recommend(report)).code,
          'benchmark_invalid_output',
        );
      }
    },
  );

  test('schema two accepts unavailable resource metrics with a reason', () {
    final result = policy.recommend(
      _report(
        [
          BenchmarkModeMeasurement(
            mode: PerformanceMode.postSession,
            status: BenchmarkMeasurementStatus.measured,
            realTimeFactor: 0.5,
          ),
        ],
        schemaVersion: 2,
        resourceMetrics: BenchmarkResourceMetrics(
          unavailableReasonCodes: const [
            'performance_metrics_start_unavailable',
          ],
        ),
      ),
    );

    expect(_ok(result).mode, PerformanceMode.postSession);
  });
}

PerformanceBenchmarkReport _report(
  List<BenchmarkModeMeasurement> measurements, {
  int schemaVersion = 1,
  int policyVersion = 1,
  BenchmarkDefinition definition = firstRunBenchmarkDefinition,
  String engineId = 'whisper.cpp',
  String engineVersion = 'test-engine',
  String modelId = 'base-q5',
  String modelVersion = 'test-model',
  String configurationId = 'cpu-neon',
  BenchmarkResourceMetrics? resourceMetrics,
}) => PerformanceBenchmarkReport(
  schemaVersion: schemaVersion,
  policyVersion: policyVersion,
  definition: definition,
  engineId: engineId,
  engineVersion: engineVersion,
  modelId: modelId,
  modelVersion: modelVersion,
  configurationId: configurationId,
  measurements: measurements,
  resourceMetrics: resourceMetrics,
);

BenchmarkRecommendation _ok(
  Result<BenchmarkRecommendation, BenchmarkFailure> result,
) => (result as Ok<BenchmarkRecommendation, BenchmarkFailure>).value;

BenchmarkFailure _failure(
  Result<BenchmarkRecommendation, BenchmarkFailure> result,
) => (result as Err<BenchmarkRecommendation, BenchmarkFailure>).failure;
