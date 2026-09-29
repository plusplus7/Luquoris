import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/data/database/open_connection.dart';
import 'package:loquiris/data/files/private_meeting_audio_store.dart';
import 'package:loquiris/data/repositories/drift_analysis_repositories.dart';
import 'package:loquiris/data/repositories/drift_session_repository.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:path_provider/path_provider.dart';

/// App-wide work that must react to process lifecycle transitions.
abstract interface class AppLifecycleActions {
  /// Flushes pending durable state before the process can be killed.
  Future<void> flush();

  /// Refreshes time-sensitive state after returning to the foreground.
  void refresh();
}

final class _NoopAppLifecycleActions implements AppLifecycleActions {
  const _NoopAppLifecycleActions();

  @override
  Future<void> flush() async {}

  @override
  void refresh() {}
}

/// Lifecycle actions installed by the composition root.
final appLifecycleActionsProvider = Provider<AppLifecycleActions>(
  (ref) => throw UnimplementedError('AppLifecycleActions is not installed'),
);

/// Local diagnostic sink installed before application infrastructure opens.
final diagnosticLogSinkProvider = Provider<DiagnosticLogSink>(
  (ref) => throw UnimplementedError('DiagnosticLogSink is not installed'),
);

final _applicationDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('AppDatabase is not installed'),
);

/// Dependencies constructed before the Flutter widget tree starts.
final class AppDependencies {
  /// Creates production dependencies and explicit provider [overrides].
  AppDependencies({
    required this.diagnosticLogSink,
    required this.lifecycleActions,
    List<Override> overrides = const [],
  }) : overrides = List.unmodifiable(overrides);

  /// Creates isolated dependencies for widget and integration tests.
  factory AppDependencies.test({List<Override> overrides = const []}) {
    return AppDependencies(
      diagnosticLogSink: const DisabledDiagnosticLogSink(),
      lifecycleActions: const _NoopAppLifecycleActions(),
      overrides: overrides,
    );
  }

  /// App-private, structured diagnostic sink.
  final DiagnosticLogSink diagnosticLogSink;

  /// Root lifecycle coordinator.
  final AppLifecycleActions lifecycleActions;

  /// Concrete boundary implementations installed at the root scope.
  final List<Override> overrides;
}

/// Constructs application infrastructure without loading optional AI engines.
Future<AppDependencies> bootstrap({
  required DiagnosticLogSink diagnosticLogSink,
  Future<AppDatabase> Function() openDatabase = openApplicationDatabase,
}) async {
  final database = await openDatabase();
  return AppDependencies(
    diagnosticLogSink: diagnosticLogSink,
    lifecycleActions: const _NoopAppLifecycleActions(),
    overrides: [
      _applicationDatabaseProvider.overrideWith((ref) {
        ref.onDispose(database.close);
        return database;
      }),
      sessionRepositoryProvider.overrideWith((ref) {
        return DriftSessionRepository(
          ref.watch(_applicationDatabaseProvider),
          audioStore: const PrivateMeetingAudioStore(
            getApplicationSupportDirectory,
          ),
          diagnosticSink: diagnosticLogSink,
        );
      }),
      transcriptRepositoryProvider.overrideWith(
        (ref) => DriftTranscriptRepository(
          ref.watch(_applicationDatabaseProvider),
          diagnosticSink: diagnosticLogSink,
        ),
      ),
      modelRepositoryProvider.overrideWith(
        (ref) => DriftModelRepository(
          ref.watch(_applicationDatabaseProvider),
          diagnosticSink: diagnosticLogSink,
        ),
      ),
      revisionRepositoryProvider.overrideWith(
        (ref) => DriftRevisionRepository(
          ref.watch(_applicationDatabaseProvider),
          diagnosticSink: diagnosticLogSink,
        ),
      ),
    ],
  );
}

/// Builds the single dependency-injection root used by production and tests.
Widget buildLoquirisRoot({
  required AppDependencies dependencies,
  required Widget child,
}) {
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      diagnosticLogSinkProvider.overrideWithValue(
        dependencies.diagnosticLogSink,
      ),
      appLifecycleActionsProvider.overrideWithValue(
        dependencies.lifecycleActions,
      ),
      ...dependencies.overrides,
    ],
    child: child,
  );
}

/// Owns the one application lifecycle observer.
mixin RootLifecycleObserver<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  late final WidgetsBindingObserver _observer = _RootObserver(
    onStateChanged: _onLifecycleStateChanged,
  );

  /// Registers the root lifecycle observer.
  void registerRootLifecycleObserver() {
    WidgetsBinding.instance.addObserver(_observer);
  }

  /// Removes the root lifecycle observer.
  void unregisterRootLifecycleObserver() {
    WidgetsBinding.instance.removeObserver(_observer);
  }

  void _onLifecycleStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        unawaited(_flushDurableState());
      case AppLifecycleState.resumed:
        ref.read(appLifecycleActionsProvider).refresh();
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _flushDurableState() async {
    try {
      await ref.read(appLifecycleActionsProvider).flush();
    } on Object catch (error) {
      ref
          .read(diagnosticLogSinkProvider)
          .record(
            DiagnosticEvent(
              code: DiagnosticCode.lifecycleFlushFailed,
              errorType: error.runtimeType,
            ),
          );
    }
  }
}

final class _RootObserver with WidgetsBindingObserver {
  _RootObserver({required this.onStateChanged});

  final void Function(AppLifecycleState state) onStateChanged;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onStateChanged(state);
  }
}
