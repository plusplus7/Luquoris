import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/export_backup/presentation/export_screen.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../../support/fakes/fake_services.dart';
import '../../support/harness.dart';

void main() {
  testWidgets('user explicitly selects one of six local export formats', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    final exports = FakeExportService()
      ..result = Ok(
        ExportReceipt(
          fileName: 'Loquiris_20261001_090705.m4a',
          bytesWritten: 2048,
        ),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [exportServiceProvider.overrideWithValue(exports)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExportScreen(meetingId: 'meeting-1'),
        ),
      ),
    );

    expect(find.text('Continuous M4A'), findsOneWidget);
    expect(find.text('Recoverable audio segments'), findsOneWidget);
    expect(
      tester.getSemantics(
        find.byKey(const Key('export-format-audioM4a')),
      ),
      isSemantics(
        label: 'Continuous M4A',
        hint:
            'Rebuilds a playable audio file from committed recording data '
            'when needed.',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasSelectedState: true,
        isSelected: false,
        hasTapAction: true,
      ),
    );
    await tester.scrollUntilVisible(find.text('Plain text'), 200);
    expect(find.text('Plain text'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('SRT subtitles'), 200);
    expect(find.text('SRT subtitles'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Structured JSON'), 200);
    expect(find.text('Structured JSON'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Complete ZIP package'), 200);
    expect(find.text('Complete ZIP package'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('export-format-audioM4a')),
      -300,
    );
    await tester.tap(find.byKey(const Key('export-format-audioM4a')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('export-confirm')),
      300,
    );
    await tester.tap(find.byKey(const Key('export-confirm')));
    await tester.pumpAndSettle();

    expect(
      exports.requests.single,
      isA<ExportRequest>()
          .having((value) => value.sessionId, 'sessionId', 'meeting-1')
          .having((value) => value.format, 'format', ExportFormat.audioM4a),
    );
    expect(find.textContaining('Loquiris_20261001_090705.m4a'), findsOneWidget);
  });

  testWidgets('export choices reflow at compact width and 200 percent text', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exportServiceProvider.overrideWithValue(FakeExportService()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
              boldText: true,
            ),
            child: ExportScreen(meetingId: 'meeting-1'),
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('export-confirm')),
      300,
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('export-confirm')), findsOneWidget);
  });

  testWidgets('material audio warnings are announced as live regions', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    final exports = FakeExportService()
      ..result = Ok(
        ExportReceipt(
          fileName: 'Loquiris_20261001_090705.zip',
          bytesWritten: 2048,
          usedSegmentFallback: true,
          warningCodes: ['export_audio_partial'],
        ),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [exportServiceProvider.overrideWithValue(exports)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExportScreen(meetingId: 'meeting-1'),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('export-confirm')),
      300,
    );
    await tester.tap(find.byKey(const Key('export-confirm')));
    await tester.pumpAndSettle();

    final fallback = find.byKey(const Key('export-fallback-warning'));
    final partial = find.byKey(const Key('export-partial-warning'));
    await tester.scrollUntilVisible(fallback, 200);
    await tester.scrollUntilVisible(partial, 200);
    expect(
      tester.getSemantics(fallback),
      isSemantics(
        label:
            'Continuous audio was unavailable, so the package contains '
            'recoverable segments.',
        isLiveRegion: true,
      ),
    );
    expect(
      tester.getSemantics(partial),
      isSemantics(
        label:
            'This recording is partial. The export contains only the audio '
            'Loquiris verified as safely committed.',
        isLiveRegion: true,
      ),
    );
  });

  testWidgets(
    'long export exposes determinate progress and safe cancellation',
    (
      tester,
    ) async {
      tester.useDevice(TestDevice.compact);
      final exports = _ControllableExportService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [exportServiceProvider.overrideWithValue(exports)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ExportScreen(meetingId: 'meeting-1'),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('export-confirm')),
        300,
      );
      await tester.tap(find.byKey(const Key('export-confirm')));
      await tester.pump();
      expect(find.text('Choosing export destination…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));

      final progress = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('export-progress')),
      );
      expect(progress.value, 0.25);
      expect(find.text('Writing export…'), findsOneWidget);
      expect(find.byKey(const Key('export-cancel')), findsOneWidget);

      exports.progress = ExportProgress(
        operationId: exports.progress.operationId,
        phase: ExportProgressPhase.finalizing,
        bytesProcessed: exports.progress.bytesProcessed,
        totalBytes: exports.progress.totalBytes,
        cancellable: false,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Finalizing export…'), findsOneWidget);
      expect(find.byKey(const Key('export-cancel')), findsNothing);

      exports.progress = ExportProgress(
        operationId: exports.progress.operationId,
        phase: ExportProgressPhase.writing,
        bytesProcessed: exports.progress.bytesProcessed,
        totalBytes: exports.progress.totalBytes,
        cancellable: true,
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('export-cancel')));
      await tester.pump();
      expect(exports.cancelledOperationIds, [exports.request.operationId]);

      exports.completion.complete(
        const Err(ExportUnavailable('export_cancelled')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Export cancelled. Nothing was sent anywhere.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'cleanup refusal clearly identifies possible incomplete output',
    (tester) async {
      tester.useDevice(TestDevice.compact);
      final exports = FakeExportService()
        ..result = const Err(
          ExportUnavailable('export_incomplete_output_cleanup_failed'),
        );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [exportServiceProvider.overrideWithValue(exports)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ExportScreen(meetingId: 'meeting-1'),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('export-confirm')),
        300,
      );
      await tester.tap(find.byKey(const Key('export-confirm')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Export stopped, but Android could not remove the incomplete file. '
          'Check the destination you selected.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('interrupted export warning is restored after restart', (
    tester,
  ) async {
    tester.useDevice(TestDevice.compact);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exportServiceProvider.overrideWithValue(
            FakeExportService(),
          ),
          exportFailureHistoryProvider.overrideWithValue(
            (meetingId) async => const Ok(
              'export_interrupted_incomplete_output_may_remain',
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExportScreen(meetingId: 'meeting-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text(
        'A previous export was interrupted. An incomplete file may remain '
        'in the destination you selected.',
      ),
      200,
    );
    expect(
      find.text(
        'A previous export was interrupted. An incomplete file may remain '
        'in the destination you selected.',
      ),
      findsOneWidget,
    );
  });
}

final class _ControllableExportService implements ExportService {
  final completion = Completer<Result<ExportReceipt, ExportFailure>>();
  final List<String> cancelledOperationIds = [];
  late ExportRequest request;
  ExportProgress progress = const ExportProgress(
    operationId: 'pending',
    phase: ExportProgressPhase.writing,
    bytesProcessed: 1024,
    totalBytes: 4096,
    cancellable: true,
  );

  @override
  Future<Result<ExportReceipt, ExportFailure>> export(
    ExportRequest request,
  ) {
    this.request = request;
    return completion.future;
  }

  @override
  Future<Result<ExportProgress, ExportFailure>> status(
    String operationId,
  ) async => Ok(
    ExportProgress(
      operationId: operationId,
      phase: progress.phase,
      bytesProcessed: progress.bytesProcessed,
      totalBytes: progress.totalBytes,
      cancellable: progress.cancellable,
    ),
  );

  @override
  Future<Result<void, ExportFailure>> cancel(String operationId) async {
    cancelledOperationIds.add(operationId);
    return const Ok(null);
  }
}
