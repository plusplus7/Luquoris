import 'package:flutter/services.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/export_backup/application/local_export_service.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Android Storage Access Framework adapter for explicit local exports.
final class MethodChannelExportDestinationGateway
    implements ExportDestinationGateway {
  /// Creates the gateway with injectable channel and privacy-safe log sink.
  const MethodChannelExportDestinationGateway({
    required this._diagnosticSink,
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.loquiris/export_v1';
  static const _version = 1;

  final MethodChannel _channel;
  final DiagnosticLogSink _diagnosticSink;

  @override
  Future<Result<ExportReceipt, ExportFailure>> save(
    ExportDestinationPayload payload,
  ) async {
    try {
      final value = await _channel.invokeMethod<Object?>('save', {
        'v': _version,
        'operationId': payload.operationId,
        'sessionId': payload.sessionId,
        'format': payload.format.name,
        'suggestedFileName': payload.suggestedFileName,
        'mimeType': payload.mimeType,
        'documents': payload.documents,
        'includeAudio': payload.includeAudio,
        'allowSegmentFallback': payload.allowSegmentFallback,
        'segmentPlan': [
          for (final segment in payload.segmentPlan)
            {
              'sequence': segment.sequence,
              'relativePath': segment.relativePath,
              'committedBytes': segment.committedBytes,
            },
        ],
        'audioPartial': payload.audioPartial,
        'audioDiagnosticCodes': payload.audioDiagnosticCodes,
      });
      if (value is! Map<Object?, Object?> || value['v'] != _version) {
        return const Err(ExportUnavailable('export_channel_invalid'));
      }
      if (value['ok'] != true) {
        final failure = value['failure'];
        final code = failure is Map<Object?, Object?> ? failure['code'] : null;
        return Err(
          ExportUnavailable(
            code is String && code.isNotEmpty ? code : 'export_channel_invalid',
          ),
        );
      }
      final receipt = value['receipt'];
      if (receipt is! Map<Object?, Object?>) {
        return const Err(ExportUnavailable('export_channel_invalid'));
      }
      final fileName = receipt['fileName'];
      final bytesWritten = receipt['bytesWritten'];
      final usedSegmentFallback = receipt['usedSegmentFallback'];
      final warningCodes = receipt['warningCodes'];
      if (fileName is! String ||
          fileName.isEmpty ||
          bytesWritten is! int ||
          bytesWritten < 0 ||
          usedSegmentFallback is! bool ||
          warningCodes is! List<Object?> ||
          warningCodes.any((value) => value is! String)) {
        return const Err(ExportUnavailable('export_channel_invalid'));
      }
      return Ok(
        ExportReceipt(
          fileName: fileName,
          bytesWritten: bytesWritten,
          usedSegmentFallback: usedSegmentFallback,
          warningCodes: warningCodes.cast<String>(),
        ),
      );
    } on PlatformException catch (error, stackTrace) {
      _record(error, stackTrace);
      return const Err(ExportUnavailable('export_channel_unavailable'));
    } on MissingPluginException catch (error, stackTrace) {
      _record(error, stackTrace);
      return const Err(ExportUnavailable('export_channel_unavailable'));
    }
  }

  @override
  Future<Result<ExportProgress, ExportFailure>> status(
    String operationId,
  ) async {
    try {
      final value = await _channel.invokeMethod<Object?>('status', {
        'v': _version,
        'operationId': operationId,
      });
      if (value is! Map<Object?, Object?> ||
          value['v'] != _version ||
          value['ok'] != true) {
        return Err(_failureFrom(value));
      }
      final progress = value['progress'];
      if (progress is! Map<Object?, Object?>) {
        return const Err(ExportUnavailable('export_channel_invalid'));
      }
      final returnedOperationId = progress['operationId'];
      final phase = progress['phase'];
      final bytesProcessed = progress['bytesProcessed'];
      final totalBytes = progress['totalBytes'];
      final cancellable = progress['cancellable'];
      if (returnedOperationId != operationId ||
          phase is! String ||
          bytesProcessed is! int ||
          bytesProcessed < 0 ||
          (totalBytes != null && (totalBytes is! int || totalBytes < 0)) ||
          cancellable is! bool) {
        return const Err(ExportUnavailable('export_channel_invalid'));
      }
      final parsedPhase = ExportProgressPhase.values
          .where((value) => value.name == phase)
          .firstOrNull;
      if (parsedPhase == null) {
        return const Err(ExportUnavailable('export_channel_invalid'));
      }
      return Ok(
        ExportProgress(
          operationId: operationId,
          phase: parsedPhase,
          bytesProcessed: bytesProcessed,
          totalBytes: totalBytes as int?,
          cancellable: cancellable,
        ),
      );
    } on PlatformException catch (error, stackTrace) {
      _record(error, stackTrace);
      return const Err(ExportUnavailable('export_channel_unavailable'));
    } on MissingPluginException catch (error, stackTrace) {
      _record(error, stackTrace);
      return const Err(ExportUnavailable('export_channel_unavailable'));
    }
  }

  @override
  Future<Result<void, ExportFailure>> cancel(String operationId) async {
    try {
      final value = await _channel.invokeMethod<Object?>('cancel', {
        'v': _version,
        'operationId': operationId,
      });
      if (value is! Map<Object?, Object?> ||
          value['v'] != _version ||
          value['ok'] != true) {
        return Err(_failureFrom(value));
      }
      return const Ok(null);
    } on PlatformException catch (error, stackTrace) {
      _record(error, stackTrace);
      return const Err(ExportUnavailable('export_channel_unavailable'));
    } on MissingPluginException catch (error, stackTrace) {
      _record(error, stackTrace);
      return const Err(ExportUnavailable('export_channel_unavailable'));
    }
  }

  ExportFailure _failureFrom(Object? value) {
    if (value is Map<Object?, Object?> && value['v'] == _version) {
      final failure = value['failure'];
      final code = failure is Map<Object?, Object?> ? failure['code'] : null;
      if (code is String && code.isNotEmpty) return ExportUnavailable(code);
    }
    return const ExportUnavailable('export_channel_invalid');
  }

  void _record(Object error, StackTrace stackTrace) {
    _diagnosticSink.record(
      DiagnosticEvent(
        code: DiagnosticCode.exportOperationFailed,
        errorType: error.runtimeType,
        stackFingerprint: diagnosticStackFingerprint(stackTrace),
      ),
    );
  }
}
