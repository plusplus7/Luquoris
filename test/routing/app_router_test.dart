import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_provider.dart';
import 'package:loquiris/features/models_performance/application/performance_benchmark_runner.dart';
import 'package:loquiris/routing/app_router.dart';
import 'package:loquiris/routing/routes.dart';
import 'package:loquiris/services/service_providers.dart';

import '../support/fakes/fake_services.dart';

void main() {
  test('id-bearing locations encode identity in the path', () {
    expect(AppRoutes.session('meeting/one'), '/sessions/meeting%2Fone');
    expect(AppRoutes.editor('meeting one'), '/sessions/meeting%20one/edit');
    expect(AppRoutes.export('会议 1'), '/sessions/%E4%BC%9A%E8%AE%AE%201/export');
    expect(AppRoutes.activeRecording('draft/1'), '/recordings/draft%2F1');
  });

  testWidgets('every required surface is reconstructable from its URL', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
        performanceBenchmarkRunnerProvider.overrideWithValue(
          const UnavailablePerformanceBenchmarkRunner(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LoquirisApp(),
      ),
    );

    const routes = <(String, String)>[
      (AppRoutes.sessions, 'sessions-empty'),
      (AppRoutes.newRecording, 'new-recording'),
      ('/recordings/draft-1', 'active-recording:draft-1'),
      ('/sessions/meeting-1', 'session-detail:meeting-1'),
      ('/sessions/meeting-1/edit', 'transcript-editor:meeting-1'),
      ('/sessions/meeting-1/export', 'export:meeting-1'),
      (AppRoutes.modelsPerformance, 'models-performance'),
      (AppRoutes.storagePrivacy, 'storage-privacy'),
    ];

    for (final (location, key) in routes) {
      router.go(location);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
      if (location == AppRoutes.modelsPerformance) {
        expect(find.textContaining('runtime is not installed'), findsOneWidget);
      }
    }
  });

  testWidgets('an unknown deep link renders the localized not-found screen', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(appRouterProvider).go('/missing');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LoquirisApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('not-found')), findsOneWidget);
    expect(find.text('Page not found'), findsWidgets);
  });
}
