import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/export_backup/application/local_benchmark_report_exporter.dart';
import 'package:loquiris/features/export_backup/application/local_export_service.dart';
import 'package:loquiris/features/models_performance/domain/benchmark_resource_metrics.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  test('valid report opens one privacy safe json destination', () async {
    final gateway = _FakeExportDestinationGateway();
    final exporter = LocalBenchmarkReportExporter(destinationGateway: gateway);

    final result = await exporter.export(
      report: _report(),
      operationId: 'benchmark-op-1',
      createdAtUtc: DateTime.utc(2026, 10, 2, 10, 30),
    );

    expect(result, isA<Ok<ExportReceipt, ExportFailure>>());
    expect(gateway.payloads, hasLength(1));
    final payload = gateway.payloads.single;
    expect(payload.operationId, 'benchmark-op-1');
    expect(payload.sessionId, 'benchmark');
    expect(payload.format, ExportFormat.json);
    expect(
      payload.suggestedFileName,
      'Loquiris-benchmark-20261002-103000.json',
    );
    expect(payload.mimeType, 'application/json');
    expect(payload.documents.keys, ['benchmark-report.json']);
    expect(
      payload.documents['benchmark-report.json'],
      contains('"schemaVersion":2'),
    );
    expect(payload.includeAudio, isFalse);
    expect(payload.allowSegmentFallback, isFalse);
    expect(payload.segmentPlan, isEmpty);
    expect(payload.audioPartial, isFalse);
    expect(payload.audioDiagnosticCodes, isEmpty);
  });

  test('invalid report never opens destination', () async {
    final gateway = _FakeExportDestinationGateway();
    final exporter = LocalBenchmarkReportExporter(destinationGateway: gateway);

    final result = await exporter.export(
      report: _report(schemaVersion: 3),
      operationId: 'benchmark-op-1',
      createdAtUtc: DateTime.utc(2026, 10, 2, 10, 30),
    );

    expect(_failureCode(result), 'benchmark_report_invalid');
    expect(gateway.payloads, isEmpty);
  });

  test(
    'picker cancellation and destination failure pass through unchanged',
    () async {
      final gateway = _FakeExportDestinationGateway();
      final exporter = LocalBenchmarkReportExporter(
        destinationGateway: gateway,
      );
      const cancellation = ExportUnavailable('export_cancelled');
      const destinationFailure = ExportUnavailable('export_destination_failed');

      gateway.next = const Err(cancellation);
      final cancelled = await exporter.export(
        report: _report(),
        operationId: 'benchmark-op-1',
        createdAtUtc: DateTime.utc(2026, 10, 2, 10, 30),
      );
      gateway.next = const Err(destinationFailure);
      final failed = await exporter.export(
        report: _report(),
        operationId: 'benchmark-op-2',
        createdAtUtc: DateTime.utc(2026, 10, 2, 10, 31),
      );

      expect(
        (cancelled as Err<ExportReceipt, ExportFailure>).failure,
        same(cancellation),
      );
      expect(
        (failed as Err<ExportReceipt, ExportFailure>).failure,
        same(destinationFailure),
      );
    },
  );

  test('export does not read or write meeting export history', () async {
    final gateway = _FakeExportDestinationGateway();
    final exporter = LocalBenchmarkReportExporter(destinationGateway: gateway);

    await exporter.export(
      report: _report(),
      operationId: 'benchmark-op-1',
      createdAtUtc: DateTime.utc(2026, 10, 2, 10, 30),
    );

    expect(gateway.payloads.single.sessionId, 'benchmark');
    expect(gateway.statusCalls, 0);
    expect(gateway.cancelCalls, 0);
  });
}

PerformanceBenchmarkReport _report({int schemaVersion = 2}) =>
    PerformanceBenchmarkReport(
      schemaVersion: schemaVersion,
      policyVersion: 1,
      definition: firstRunBenchmarkDefinition,
      engineId: 'whisper.cpp',
      engineVersion: '1.2.3',
      modelId: 'base-q5',
      modelVersion: '1',
      configurationId: 'cpu-neon',
      measurements: [
        BenchmarkModeMeasurement(
          mode: PerformanceMode.balanced,
          status: BenchmarkMeasurementStatus.measured,
          realTimeFactor: 0.5,
          firstTextLatency: const Duration(seconds: 2),
          maximumBacklog: 3,
        ),
      ],
      resourceMetrics: schemaVersion == 2
          ? BenchmarkResourceMetrics(
              wallDuration: const Duration(milliseconds: 1500),
              processCpuTime: const Duration(milliseconds: 450),
              maxSampledPssBytes: 12000,
              worstThermalState: ThermalState.hot,
              deviceEnergyUsedNanowattHours: 600,
            )
          : null,
    );

String _failureCode(Result<ExportReceipt, ExportFailure> result) =>
    switch (result) {
      Ok() => fail('expected failure'),
      Err(:final failure) => failure.code,
    };

final class _FakeExportDestinationGateway implements ExportDestinationGateway {
  Result<ExportReceipt, ExportFailure> next = Ok(
    ExportReceipt(fileName: 'benchmark.json', bytesWritten: 1),
  );
  final List<ExportDestinationPayload> payloads = [];
  int statusCalls = 0;
  int cancelCalls = 0;

  @override
  Future<Result<ExportReceipt, ExportFailure>> save(
    ExportDestinationPayload payload,
  ) async {
    payloads.add(payload);
    return next;
  }

  @override
  Future<Result<ExportProgress, ExportFailure>> status(
    String operationId,
  ) async {
    statusCalls += 1;
    return const Err(ExportUnavailable('unexpected_status'));
  }

  @override
  Future<Result<void, ExportFailure>> cancel(String operationId) async {
    cancelCalls += 1;
    return const Err(ExportUnavailable('unexpected_cancel'));
  }
}
