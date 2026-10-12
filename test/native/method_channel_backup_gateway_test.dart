import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/export_backup/application/local_backup_service.dart';
import 'package:loquiris/features/export_backup/application/local_restore_service.dart';
import 'package:loquiris/native/method_channel_backup_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.loquiris/backup');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('sends allowlisted backup plan and decodes private receipt', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'create');
      expect(call.arguments, <String, Object?>{
        'v': 1,
        'operationId': 'backup_1',
        'schemaVersion': 4,
        'exportedAtUtc': '2026-10-01T00:00:00.000Z',
        'snapshotRelativePath': 'backup_staging/backup_1.sqlite',
        'audioPlan': <Map<String, Object?>>[
          <String, Object?>{
            'relativePath': 'recordings/$_storageKey/segment-00000.adts',
            'committedBytes': 123,
          },
        ],
      });
      return <String, Object?>{
        'v': 1,
        'ok': true,
        'receipt': <String, Object?>{
          'relativePath': 'backups/loquiris-backup-backup_1.zip',
          'sha256': _shaB,
          'bytes': 4096,
        },
      };
    });
    const gateway = MethodChannelBackupGateway(
      channel: channel,
      diagnosticSink: DisabledDiagnosticLogSink(),
    );

    final result = await gateway.create(
      BackupNativeRequest(
        operationId: 'backup_1',
        schemaVersion: 4,
        exportedAtUtc: '2026-10-01T00:00:00.000Z',
        snapshotRelativePath: 'backup_staging/backup_1.sqlite',
        audioPlan: const [
          BackupAudioPlanEntry(
            relativePath: 'recordings/$_storageKey/segment-00000.adts',
            committedBytes: 123,
          ),
        ],
      ),
    );

    final receipt = (result as Ok<BackupNativeReceipt, BackupFailure>).value;
    expect(receipt.relativePath.value, 'backups/loquiris-backup-backup_1.zip');
    expect(receipt.sha256, _shaB);
    expect(receipt.bytes, 4096);
  });

  test('decodes only validated private restore staging paths', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'verifyAndStageRestore');
      return <String, Object?>{
        'v': 1,
        'ok': true,
        'verification': <String, Object?>{
          'formatVersion': 1,
          'schemaVersion': 4,
          'exportedAtUtc': '2026-10-01T00:00:00Z',
          'databaseRelativePath':
              'restore_staging/restore_1/database/loquiris.sqlite',
          'checksumIndexRelativePath':
              'restore_staging/restore_1/checksums.json',
          'stagingRelativePath': 'restore_staging/restore_1',
          'recordings': <Map<String, Object?>>[
            <String, Object?>{
              'sourceMeetingId': 'meeting-a',
              'storageKey': _storageKey,
              'contentFingerprint': _shaB,
              'segments': <Map<String, Object?>>[
                <String, Object?>{
                  'fileName': 'segment-00000.adts',
                  'committedBytes': 5,
                },
              ],
            },
          ],
        },
      };
    });
    const gateway = MethodChannelBackupGateway(
      channel: channel,
      diagnosticSink: DisabledDiagnosticLogSink(),
    );

    final result = await gateway.verifyAndStage(
      const RestoreVerificationRequest(
        operationId: 'restore_1',
        archiveRelativePath: 'backups/loquiris-backup-backup_1.zip',
        currentSchemaVersion: 4,
      ),
    );

    final value = (result as Ok<RestoreStaging, BackupFailure>).value;
    expect(value.schemaVersion, 4);
    expect(
      value.databaseRelativePath.value,
      'restore_staging/restore_1/database/loquiris.sqlite',
    );
    expect(value.recordings.single.sourceMeetingId, 'meeting-a');
    expect(value.recordings.single.contentFingerprint, _shaB);
    expect(value.recordings.single.segments.single.committedBytes, 5);
  });

  test(
    'bridges restore recording publication, inspection, and cleanup',
    () async {
      final methods = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        methods.add(call.method);
        switch (call.method) {
          case 'fingerprintRestoreRecordings':
            expect(call.arguments, <String, Object?>{
              'v': 1,
              'meetingIds': <String>['meeting-a'],
            });
            return <String, Object?>{
              'v': 1,
              'ok': true,
              'fingerprints': <String, Object?>{'meeting-a': _shaB},
            };
          case 'publishRestoreRecording':
            return <String, Object?>{'v': 1, 'ok': true, 'published': true};
          case 'rollbackRestoreRecordings':
          case 'finalizeRestoreRecordings':
          case 'discardRestoreStaging':
            return <String, Object?>{'v': 1, 'ok': true};
        }
        fail('Unexpected method ${call.method}');
      });
      const gateway = MethodChannelBackupGateway(
        channel: channel,
        diagnosticSink: DisabledDiagnosticLogSink(),
      );

      final fingerprints = await gateway.recordingFingerprints(
        const <String>['meeting-a'],
      );
      expect(
        (fingerprints as Ok<Map<String, String?>, BackupFailure>)
            .value['meeting-a'],
        _shaB,
      );
      final published = await gateway.publishRecording(
        const RestoreRecordingTransfer(
          operationId: 'restore_1',
          sourceMeetingId: 'meeting-a',
          targetMeetingId: 'meeting-copy',
          contentFingerprint: _shaB,
        ),
      );
      expect((published as Ok<bool, BackupFailure>).value, isTrue);
      expect(
        await gateway.rollbackRecordings(
          'restore_1',
          const <String>['meeting-copy'],
        ),
        isA<Ok<void, BackupFailure>>(),
      );
      expect(
        await gateway.finalizeRecordings(
          'restore_1',
          const <String>['meeting-copy'],
        ),
        isA<Ok<void, BackupFailure>>(),
      );
      expect(
        await gateway.discardStaging('restore_1'),
        isA<Ok<void, BackupFailure>>(),
      );
      expect(methods, <String>[
        'fingerprintRestoreRecordings',
        'publishRestoreRecording',
        'rollbackRestoreRecordings',
        'finalizeRestoreRecordings',
        'discardRestoreStaging',
      ]);
    },
  );
}

const _storageKey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _shaB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
