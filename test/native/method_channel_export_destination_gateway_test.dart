import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/export_backup/application/local_export_service.dart';
import 'package:loquiris/native/method_channel_export_destination_gateway.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.loquiris/export');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'sends a versioned value-only request and decodes its receipt',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'save');
        expect(call.arguments, <String, Object?>{
          'v': 1,
          'operationId': 'export-1',
          'sessionId': 'meeting-1',
          'format': 'archive',
          'suggestedFileName': 'Loquiris_20261001_090705.zip',
          'mimeType': 'application/zip',
          'documents': <String, String>{'meeting.json': '{"v":1}'},
          'includeAudio': true,
          'allowSegmentFallback': true,
          'segmentPlan': <Map<String, Object?>>[
            <String, Object?>{
              'sequence': 0,
              'relativePath': 'recordings/hash/segment-00000.adts',
              'committedBytes': 321,
            },
          ],
          'audioPartial': true,
          'audioDiagnosticCodes': <String>[
            'recording_recovery_timeline_gap',
          ],
        });
        return <String, Object?>{
          'v': 1,
          'ok': true,
          'receipt': <String, Object?>{
            'fileName': 'Loquiris_20261001_090705.zip',
            'bytesWritten': 2048,
            'usedSegmentFallback': true,
            'warningCodes': <String>['export_audio_segments_used'],
          },
        };
      });
      const gateway = MethodChannelExportDestinationGateway(
        channel: channel,
        diagnosticSink: DisabledDiagnosticLogSink(),
      );

      final result = await gateway.save(
        ExportDestinationPayload(
          operationId: 'export-1',
          sessionId: 'meeting-1',
          format: ExportFormat.archive,
          suggestedFileName: 'Loquiris_20261001_090705.zip',
          mimeType: 'application/zip',
          documents: const {'meeting.json': '{"v":1}'},
          includeAudio: true,
          allowSegmentFallback: true,
          segmentPlan: const [
            ExportSegmentPlanEntry(
              sequence: 0,
              relativePath: 'recordings/hash/segment-00000.adts',
              committedBytes: 321,
            ),
          ],
          audioPartial: true,
          audioDiagnosticCodes: const [
            'recording_recovery_timeline_gap',
          ],
        ),
      );

      final receipt = (result as Ok<ExportReceipt, ExportFailure>).value;
      expect(receipt.fileName, 'Loquiris_20261001_090705.zip');
      expect(receipt.bytesWritten, 2048);
      expect(receipt.usedSegmentFallback, isTrue);
      expect(receipt.warningCodes, ['export_audio_segments_used']);
    },
  );

  test('maps picker cancellation to a stable typed failure', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => <String, Object?>{
        'v': 1,
        'ok': false,
        'failure': <String, Object?>{'code': 'export_cancelled'},
      },
    );
    const gateway = MethodChannelExportDestinationGateway(
      channel: channel,
      diagnosticSink: DisabledDiagnosticLogSink(),
    );

    final result = await gateway.save(
      ExportDestinationPayload(
        operationId: 'export-2',
        sessionId: 'meeting-1',
        format: ExportFormat.text,
        suggestedFileName: 'Loquiris_20261001_090705.txt',
        mimeType: 'text/plain',
        documents: const {'content.txt': 'hello'},
        includeAudio: false,
        allowSegmentFallback: false,
      ),
    );

    expect(
      (result as Err<ExportReceipt, ExportFailure>).failure.code,
      'export_cancelled',
    );
  });

  test('decodes progress and sends cooperative cancellation', () async {
    final methods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      expect(call.arguments, <String, Object?>{
        'v': 1,
        'operationId': 'export-3',
      });
      if (call.method == 'status') {
        return <String, Object?>{
          'v': 1,
          'ok': true,
          'progress': <String, Object?>{
            'operationId': 'export-3',
            'phase': 'writing',
            'bytesProcessed': 1024,
            'totalBytes': 4096,
            'cancellable': true,
          },
        };
      }
      return <String, Object?>{'v': 1, 'ok': true};
    });
    const gateway = MethodChannelExportDestinationGateway(
      channel: channel,
      diagnosticSink: DisabledDiagnosticLogSink(),
    );

    final progress = await gateway.status('export-3');
    final cancellation = await gateway.cancel('export-3');

    expect(
      (progress as Ok<ExportProgress, ExportFailure>).value.bytesProcessed,
      1024,
    );
    expect(progress.value.totalBytes, 4096);
    expect(progress.value.cancellable, isTrue);
    expect(cancellation, isA<Ok<void, ExportFailure>>());
    expect(methods, ['status', 'cancel']);
  });
}
