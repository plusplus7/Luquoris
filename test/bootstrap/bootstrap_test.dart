import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/bootstrap/bootstrap.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/data/repositories/drift_analysis_repositories.dart';
import 'package:loquiris/data/repositories/drift_session_repository.dart';
import 'package:loquiris/services/service_providers.dart';

import '../support/fakes/fake_services.dart';

void main() {
  testWidgets('production bootstrap installs local session persistence', (
    tester,
  ) async {
    final dependencies = await bootstrap(
      diagnosticLogSink: const DisabledDiagnosticLogSink(),
      openDatabase: () async => AppDatabase(NativeDatabase.memory()),
    );

    await tester.pumpWidget(
      buildLoquirisRoot(
        dependencies: dependencies,
        child: Consumer(
          builder: (context, ref, child) {
            final installed =
                ref.read(sessionRepositoryProvider) is DriftSessionRepository &&
                ref.read(transcriptRepositoryProvider)
                    is DriftTranscriptRepository &&
                ref.read(modelRepositoryProvider) is DriftModelRepository &&
                ref.read(revisionRepositoryProvider) is DriftRevisionRepository;
            return Text(
              installed ? 'installed' : 'missing',
              textDirection: TextDirection.ltr,
            );
          },
        ),
      ),
    );

    expect(find.text('installed'), findsOneWidget);
  });

  testWidgets('root scope installs explicit test overrides', (tester) async {
    final capture = FakeAudioCaptureService();
    addTearDown(capture.dispose);
    final dependencies = AppDependencies.test(
      overrides: [audioCaptureServiceProvider.overrideWithValue(capture)],
    );

    await tester.pumpWidget(
      buildLoquirisRoot(
        dependencies: dependencies,
        child: Consumer(
          builder: (context, ref, child) {
            return Text(
              identical(ref.read(audioCaptureServiceProvider), capture)
                  ? 'overridden'
                  : 'wrong',
              textDirection: TextDirection.ltr,
            );
          },
        ),
      ),
    );

    expect(find.text('overridden'), findsOneWidget);
  });

  testWidgets('Loquiris app renders the offline shell', (tester) async {
    await tester.pumpWidget(
      buildLoquirisRoot(
        dependencies: AppDependencies.test(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(
              FakeSessionRepository(),
            ),
          ],
        ),
        child: const LoquirisApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No meetings yet'), findsOneWidget);
    expect(find.text('Start a recording'), findsOneWidget);
  });

  testWidgets('root observer flushes on pause and refreshes on resume', (
    tester,
  ) async {
    final lifecycle = _RecordingLifecycleActions();
    final dependencies = AppDependencies(
      diagnosticLogSink: const DisabledDiagnosticLogSink(),
      lifecycleActions: lifecycle,
    );
    await tester.pumpWidget(
      buildLoquirisRoot(
        dependencies: dependencies,
        child: const LoquirisApp(),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );

    expect(lifecycle.flushCalls, 1);
    expect(lifecycle.refreshCalls, 1);
  });
}

final class _RecordingLifecycleActions implements AppLifecycleActions {
  int flushCalls = 0;
  int refreshCalls = 0;

  @override
  Future<void> flush() async {
    flushCalls += 1;
  }

  @override
  void refresh() {
    refreshCalls += 1;
  }
}
