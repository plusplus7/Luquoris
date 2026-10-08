import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/performance_benchmark.dart';
import 'package:loquiris/services/service_contracts.dart';

/// User-authorized destination boundary for one benchmark report.
// The interface keeps the destination side effect injectable and fakeable.
// ignore: one_member_abstracts
abstract interface class BenchmarkReportExporter {
  /// Validates [report] and asks the platform to save its JSON document.
  Future<Result<ExportReceipt, ExportFailure>> export({
    required PerformanceBenchmarkReport report,
    required String operationId,
    required DateTime createdAtUtc,
  });
}

/// Benchmark-report export boundary installed by production bootstrap.
final benchmarkReportExporterProvider = Provider<BenchmarkReportExporter>(
  (ref) => throw UnimplementedError('BenchmarkReportExporter is not installed'),
);
