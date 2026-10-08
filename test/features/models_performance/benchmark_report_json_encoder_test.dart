import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/application/benchmark_report_json_encoder.dart';
import 'package:loquiris/features/models_performance/domain/benchmark_resource_metrics.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  const encoder = BenchmarkReportJsonEncoder();

  test('encodes schema two in fixed allowlisted order', () {
    final blockingReasons = <String>['z_reason', 'a_reason'];
    final unavailableReasons = <String>[
      'performance_metrics_end_unavailable',
      'device_energy_counter_unavailable',
    ];
    final report = _report(
      measurements: [
        BenchmarkModeMeasurement(
          mode: PerformanceMode.powerSaving,
          status: BenchmarkMeasurementStatus.failed,
          blockingReasonCodes: const ['runtime_unavailable'],
        ),
        BenchmarkModeMeasurement(
          mode: PerformanceMode.balanced,
          status: BenchmarkMeasurementStatus.measured,
          realTimeFactor: 0.6,
          firstTextLatency: const Duration(milliseconds: 1200),
          maximumBacklog: 2,
          blockingReasonCodes: blockingReasons,
        ),
      ],
      resources: BenchmarkResourceMetrics(
        wallDuration: const Duration(milliseconds: 1500),
        processCpuTime: const Duration(milliseconds: 450),
        maxSampledPssBytes: 12000,
        worstThermalState: ThermalState.hot,
        unavailableReasonCodes: unavailableReasons,
      ),
    );

    final encoded = _encoded(encoder.encode(report));

    expect(
      encoded,
      '{"schemaVersion":2,"policyVersion":1,'
      '"benchmark":{"id":"zh-en-mixed-v1",'
      '"sha256":"83440d4ccbd82dafd1a88346ab448e1dd309e408c598d665413b910cc92c40a7",'
      '"bytes":1440044,"mediaDurationMilliseconds":45000},'
      '"execution":{"engineId":"whisper.cpp","engineVersion":"1.2.3",'
      '"modelId":"base-q5","modelVersion":"1",'
      '"configurationId":"cpu-neon"},'
      '"measurements":[{"mode":"balanced","status":"measured",'
      '"realTimeFactor":0.6,"firstTextLatencyMilliseconds":1200,'
      '"maximumBacklog":2,'
      '"blockingReasonCodes":["a_reason","z_reason"]},'
      '{"mode":"powerSaving","status":"failed",'
      '"realTimeFactor":null,"firstTextLatencyMilliseconds":null,'
      '"maximumBacklog":null,'
      '"blockingReasonCodes":["runtime_unavailable"]}],'
      '"resources":{"wallDurationMilliseconds":1500,'
      '"processCpuTimeMilliseconds":450,"maxSampledPssBytes":12000,'
      '"worstThermalState":"hot",'
      '"deviceEnergyUsedNanowattHours":null,'
      '"unavailableReasonCodes":["device_energy_counter_unavailable",'
      '"performance_metrics_end_unavailable"]}}',
    );
    expect(blockingReasons, ['z_reason', 'a_reason']);
    expect(unavailableReasons, [
      'performance_metrics_end_unavailable',
      'device_energy_counter_unavailable',
    ]);
    expect(report.measurements.first.mode, PerformanceMode.powerSaving);
  });

  test('sorts measurements by performance mode and reason codes lexically', () {
    final report = _report(
      measurements: [
        _measurement(PerformanceMode.postSession, reasons: ['z', 'a']),
        _measurement(PerformanceMode.highQuality, reasons: ['y', 'b']),
        _measurement(PerformanceMode.recordingOnly),
      ],
    );

    final decoded = jsonDecode(_encoded(encoder.encode(report))) as Map;
    final measurements = decoded['measurements'] as List;

    expect(
      measurements.map((value) => (value as Map)['mode']),
      ['highQuality', 'recordingOnly', 'postSession'],
    );
    expect((measurements.first as Map)['blockingReasonCodes'], ['b', 'y']);
    expect((measurements.last as Map)['blockingReasonCodes'], ['a', 'z']);
  });

  test('uses explicit nulls for missing runner and energy metrics', () {
    final report = _report(
      measurements: [
        BenchmarkModeMeasurement(
          mode: PerformanceMode.balanced,
          status: BenchmarkMeasurementStatus.unmeasured,
          blockingReasonCodes: const ['runner_unavailable'],
        ),
      ],
      resources: BenchmarkResourceMetrics(
        wallDuration: const Duration(milliseconds: 1500),
        processCpuTime: const Duration(milliseconds: 450),
        maxSampledPssBytes: 12000,
        worstThermalState: ThermalState.hot,
        unavailableReasonCodes: const ['device_energy_counter_unavailable'],
      ),
    );

    final decoded = jsonDecode(_encoded(encoder.encode(report))) as Map;
    final measurement = (decoded['measurements'] as List).single as Map;
    final resources = decoded['resources'] as Map;

    expect(measurement.containsKey('realTimeFactor'), isTrue);
    expect(measurement['realTimeFactor'], isNull);
    expect(measurement['firstTextLatencyMilliseconds'], isNull);
    expect(measurement['maximumBacklog'], isNull);
    expect(resources.containsKey('deviceEnergyUsedNanowattHours'), isTrue);
    expect(resources['deviceEnergyUsedNanowattHours'], isNull);

    final schemaOne =
        jsonDecode(_encoded(encoder.encode(_report(schemaVersion: 1)))) as Map;
    expect(schemaOne['resources'], {
      'wallDurationMilliseconds': null,
      'processCpuTimeMilliseconds': null,
      'maxSampledPssBytes': null,
      'worstThermalState': null,
      'deviceEnergyUsedNanowattHours': null,
      'unavailableReasonCodes': <Object?>[],
    });
  });

  test('equal reports produce identical utf8 bytes', () {
    final first = _report();
    final second = _report(
      resources: BenchmarkResourceMetrics(
        wallDuration: const Duration(milliseconds: 1500),
        processCpuTime: const Duration(milliseconds: 450),
        maxSampledPssBytes: 12000,
        worstThermalState: ThermalState.hot,
        deviceEnergyUsedNanowattHours: 600,
      ),
    );

    expect(first, second);
    expect(
      utf8.encode(_encoded(encoder.encode(first))),
      utf8.encode(_encoded(encoder.encode(second))),
    );
  });

  test(
    'rejects unsupported partial negative non finite and path like identity values',
    () {
      final invalidReports = <PerformanceBenchmarkReport>[
        _report(schemaVersion: 3),
        _report(
          resources: BenchmarkResourceMetrics(
            wallDuration: const Duration(seconds: 1),
          ),
        ),
        _report(
          measurements: [
            BenchmarkModeMeasurement(
              mode: PerformanceMode.balanced,
              status: BenchmarkMeasurementStatus.measured,
              realTimeFactor: -0.1,
            ),
          ],
        ),
        _report(
          measurements: [
            BenchmarkModeMeasurement(
              mode: PerformanceMode.balanced,
              status: BenchmarkMeasurementStatus.measured,
              realTimeFactor: double.nan,
            ),
          ],
        ),
        _report(engineId: '../private/model'),
        _report(engineId: r'engine\private'),
        _report(engineId: 'engine:private'),
        _report(engineId: 'engine\nid'),
        _report(engineId: '   '),
        _report(engineId: 'a' * 129),
        _report(policyVersion: 2),
        _report(
          definition: const BenchmarkDefinition(
            id: 'other',
            sha256:
                '83440d4ccbd82dafd1a88346ab448e1dd309e408c598d665413b910cc92c40a7',
            bytes: 1440044,
            mediaDuration: Duration(seconds: 45),
          ),
        ),
        _report(
          measurements: [
            _measurement(PerformanceMode.balanced),
            _measurement(PerformanceMode.balanced),
          ],
        ),
        _report(
          measurements: [
            _measurement(PerformanceMode.balanced, reasons: ['bad-reason']),
          ],
        ),
        _report(
          measurements: [
            BenchmarkModeMeasurement(
              mode: PerformanceMode.balanced,
              status: BenchmarkMeasurementStatus.measured,
              maximumBacklog: -1,
            ),
          ],
        ),
        _report(
          resources: BenchmarkResourceMetrics(
            wallDuration: const Duration(milliseconds: 1),
            processCpuTime: Duration.zero,
            maxSampledPssBytes: -1,
            worstThermalState: ThermalState.nominal,
            unavailableReasonCodes: const ['device_energy_counter_unavailable'],
          ),
        ),
      ];

      for (final report in invalidReports) {
        expect(
          _failureCode(encoder.encode(report)),
          'benchmark_report_invalid',
        );
      }
    },
  );

  test(
    'output contains no user device path uri exception audio or transcript keys',
    () {
      final decoded = jsonDecode(_encoded(encoder.encode(_report())));
      final keys = <String>{};
      _collectKeys(decoded, keys);

      expect(
        keys.intersection(const {
          'user',
          'device',
          'path',
          'uri',
          'exception',
          'audio',
          'transcript',
        }),
        isEmpty,
      );
    },
  );
}

BenchmarkModeMeasurement _measurement(
  PerformanceMode mode, {
  List<String> reasons = const [],
}) => BenchmarkModeMeasurement(
  mode: mode,
  status: BenchmarkMeasurementStatus.failed,
  blockingReasonCodes: reasons,
);

PerformanceBenchmarkReport _report({
  int schemaVersion = 2,
  int policyVersion = 1,
  BenchmarkDefinition definition = firstRunBenchmarkDefinition,
  String engineId = 'whisper.cpp',
  List<BenchmarkModeMeasurement>? measurements,
  BenchmarkResourceMetrics? resources,
}) => PerformanceBenchmarkReport(
  schemaVersion: schemaVersion,
  policyVersion: policyVersion,
  definition: definition,
  engineId: engineId,
  engineVersion: '1.2.3',
  modelId: 'base-q5',
  modelVersion: '1',
  configurationId: 'cpu-neon',
  measurements:
      measurements ??
      [
        BenchmarkModeMeasurement(
          mode: PerformanceMode.balanced,
          status: BenchmarkMeasurementStatus.measured,
          realTimeFactor: 0.5,
          firstTextLatency: const Duration(seconds: 2),
          maximumBacklog: 3,
        ),
      ],
  resourceMetrics:
      resources ??
      (schemaVersion == 2
          ? BenchmarkResourceMetrics(
              wallDuration: const Duration(milliseconds: 1500),
              processCpuTime: const Duration(milliseconds: 450),
              maxSampledPssBytes: 12000,
              worstThermalState: ThermalState.hot,
              deviceEnergyUsedNanowattHours: 600,
            )
          : null),
);

String _encoded(Result<String, ExportFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('unexpected failure: ${failure.code}'),
};

String _failureCode(Result<String, ExportFailure> result) => switch (result) {
  Ok() => fail('expected failure'),
  Err(:final failure) => failure.code,
};

void _collectKeys(Object? value, Set<String> keys) {
  switch (value) {
    case Map<Object?, Object?>():
      for (final entry in value.entries) {
        if (entry.key case final String key) keys.add(key);
        _collectKeys(entry.value, keys);
      }
    case List<Object?>():
      for (final item in value) {
        _collectKeys(item, keys);
      }
  }
}
