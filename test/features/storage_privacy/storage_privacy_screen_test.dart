import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';
import 'package:loquiris/features/storage_privacy/domain/rebuildable_cache.dart';
import 'package:loquiris/features/storage_privacy/domain/storage_accounting.dart';
import 'package:loquiris/features/storage_privacy/presentation/storage_privacy_screen.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/services/analysis_repository_contracts.dart';
import 'package:loquiris/services/service_providers.dart';

import '../../support/fakes/fake_services.dart';

void main() {
  testWidgets('shows formatted explainable totals and model disclosure', (
    tester,
  ) async {
    final service = _MutableStorageMetricsService(
      const Ok(
        PlatformStorageMetrics(
          appBytes: 2 * 1024 * 1024,
          dataBytes: 1024 * 1024,
          cacheBytes: 512 * 1024,
          availableBytes: 3 * 1024 * 1024 * 1024,
        ),
      ),
    );

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('2.5 MB'), findsOneWidget);
    expect(find.text('512 KB'), findsOneWidget);
    expect(find.text('3 GB'), findsOneWidget);
    expect(find.textContaining('model files'), findsOneWidget);
  });

  testWidgets('shows a retryable localized failure then reloads', (
    tester,
  ) async {
    final service = _MutableStorageMetricsService(
      const Err(StorageMetricsUnavailable('storage_stats_unavailable')),
    );

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('storage-retry')), findsOneWidget);

    service.result = const Ok(
      PlatformStorageMetrics(
        appBytes: 1,
        dataBytes: 0,
        cacheBytes: 0,
        availableBytes: 2,
      ),
    );
    await tester.tap(find.byKey(const Key('storage-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('storage-retry')), findsNothing);
    expect(service.calls, 2);
  });

  testWidgets('remains scrollable at compact width and 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final service = _MutableStorageMetricsService(
      const Ok(
        PlatformStorageMetrics(
          appBytes: 1,
          dataBytes: 2,
          cacheBytes: 0,
          availableBytes: 3,
        ),
      ),
    );

    await tester.pumpWidget(_app(service, locale: const Locale('zh')));
    await tester.pumpAndSettle();

    expect(find.text('应用与模型'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clears only rebuildable cache and refreshes accounting', (
    tester,
  ) async {
    final service = _MutableStorageMetricsService(
      const Ok(
        PlatformStorageMetrics(
          appBytes: 1,
          dataBytes: 42,
          cacheBytes: 42,
          availableBytes: 100,
        ),
      ),
      cleanupResult: const Ok(
        RebuildableCacheCleanupReceipt(filesDeleted: 2, bytesDeleted: 42),
      ),
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    final action = find.byKey(const Key('clear-rebuildable-cache'));
    await tester.ensureVisible(action);

    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(service.cleanupCalls, 1);
    expect(service.calls, 2);
    expect(find.text('Cleared 42 B from 2 files.'), findsOneWidget);
  });

  testWidgets('shows a retryable partial cleanup failure', (tester) async {
    final service = _MutableStorageMetricsService(
      const Ok(
        PlatformStorageMetrics(
          appBytes: 1,
          dataBytes: 7,
          cacheBytes: 7,
          availableBytes: 100,
        ),
      ),
      cleanupResult: const Err(
        RebuildableCacheFailure(
          code: 'rebuildable_cache_cleanup_failed',
          filesDeleted: 1,
          bytesDeleted: 7,
        ),
      ),
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    final action = find.byKey(const Key('clear-rebuildable-cache'));
    await tester.ensureVisible(action);

    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.textContaining('stopped after clearing 7 B'), findsOneWidget);
    expect(find.byKey(const Key('clear-rebuildable-cache')), findsOneWidget);
  });

  testWidgets('disables repeat cleanup while native work is pending', (
    tester,
  ) async {
    final pending =
        Completer<
          Result<RebuildableCacheCleanupReceipt, RebuildableCacheFailure>
        >();
    final service = _MutableStorageMetricsService(
      const Ok(
        PlatformStorageMetrics(
          appBytes: 1,
          dataBytes: 0,
          cacheBytes: 0,
          availableBytes: 100,
        ),
      ),
      pendingCleanup: pending.future,
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();
    final action = find.byKey(const Key('clear-rebuildable-cache'));
    await tester.ensureVisible(action);

    await tester.tap(action);
    await tester.pump();

    expect(find.byKey(const Key('cache-cleanup-progress')), findsOneWidget);
    expect(tester.widget<OutlinedButton>(action).onPressed, isNull);
    pending.complete(
      const Ok(
        RebuildableCacheCleanupReceipt(filesDeleted: 0, bytesDeleted: 0),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cache-cleanup-progress')), findsNothing);
  });
}

Widget _app(
  _MutableStorageMetricsService service, {
  Locale locale = const Locale('en'),
}) => ProviderScope(
  overrides: [
    storageMetricsServiceProvider.overrideWithValue(service),
    rebuildableCacheServiceProvider.overrideWithValue(service),
    sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
    modelRepositoryProvider.overrideWithValue(_EmptyModelRepository()),
  ],
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: const StoragePrivacyScreen(),
  ),
);

final class _MutableStorageMetricsService
    implements StorageMetricsService, RebuildableCacheService {
  _MutableStorageMetricsService(
    this.result, {
    this.cleanupResult = const Ok(
      RebuildableCacheCleanupReceipt(filesDeleted: 0, bytesDeleted: 0),
    ),
    this.pendingCleanup,
  });

  Result<PlatformStorageMetrics, StorageMetricsFailure> result;
  Result<RebuildableCacheCleanupReceipt, RebuildableCacheFailure> cleanupResult;
  final Future<Result<RebuildableCacheCleanupReceipt, RebuildableCacheFailure>>?
  pendingCleanup;
  int calls = 0;
  int cleanupCalls = 0;

  @override
  Future<Result<PlatformStorageMetrics, StorageMetricsFailure>>
  measure() async {
    calls += 1;
    return result;
  }

  @override
  Future<Result<RebuildableCacheCleanupReceipt, RebuildableCacheFailure>>
  clear() async {
    cleanupCalls += 1;
    if (pendingCleanup case final pending?) return pending;
    return cleanupResult;
  }
}

final class _EmptyModelRepository implements ModelRepository {
  @override
  Future<Result<List<InstalledModel>, AnalysisRepositoryFailure>>
  listInstalled() async => const Ok(<InstalledModel>[]);

  @override
  Future<Result<InstalledModel, AnalysisRepositoryFailure>> registerBundled(
    InstalledModel model, {
    required int observedAtUtcMs,
  }) async => Ok(model);
}
