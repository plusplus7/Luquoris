import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/export_backup/application/local_export_service.dart';
import 'package:loquiris/features/models_performance/application/benchmark_report_exporter.dart';
import 'package:loquiris/features/models_performance/application/benchmark_report_json_encoder.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Saves one deterministic benchmark report through Android's SAF gateway.
final class LocalBenchmarkReportExporter implements BenchmarkReportExporter {
  /// Creates a repository-free benchmark exporter.
  const LocalBenchmarkReportExporter({
    required this.destinationGateway,
    this.encoder = const BenchmarkReportJsonEncoder(),
  });

  /// Platform destination used only after encoding succeeds.
  final ExportDestinationGateway destinationGateway;

  /// Pure deterministic report encoder.
  final BenchmarkReportJsonEncoder encoder;

  @override
  Future<Result<ExportReceipt, ExportFailure>> export({
    required PerformanceBenchmarkReport report,
    required String operationId,
    required DateTime createdAtUtc,
  }) async {
    final encoded = encoder.encode(report);
    switch (encoded) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return destinationGateway.save(
          ExportDestinationPayload(
            operationId: operationId,
            sessionId: 'benchmark',
            format: ExportFormat.json,
            suggestedFileName: _fileName(createdAtUtc.toUtc()),
            mimeType: 'application/json',
            documents: <String, String>{'benchmark-report.json': value},
            includeAudio: false,
            allowSegmentFallback: false,
          ),
        );
    }
  }

  static String _fileName(DateTime createdAtUtc) =>
      'Loquiris-benchmark-'
      '${createdAtUtc.year.toString().padLeft(4, '0')}'
      '${createdAtUtc.month.toString().padLeft(2, '0')}'
      '${createdAtUtc.day.toString().padLeft(2, '0')}-'
      '${createdAtUtc.hour.toString().padLeft(2, '0')}'
      '${createdAtUtc.minute.toString().padLeft(2, '0')}'
      '${createdAtUtc.second.toString().padLeft(2, '0')}.json';
}
