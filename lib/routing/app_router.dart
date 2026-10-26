import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loquiris/features/export_backup/presentation/export_screen.dart';
import 'package:loquiris/features/models_performance/presentation/models_performance_screen.dart';
import 'package:loquiris/features/recording/presentation/active_recording_screen.dart';
import 'package:loquiris/features/recording/presentation/new_recording_screen.dart';
import 'package:loquiris/features/remote_transcription/application/remote_feature.dart';
import 'package:loquiris/features/remote_transcription/presentation/remote_settings_screen.dart';
import 'package:loquiris/features/sessions/presentation/session_detail_screen.dart';
import 'package:loquiris/features/sessions/presentation/session_library_screen.dart';
import 'package:loquiris/features/storage_privacy/presentation/storage_privacy_screen.dart';
import 'package:loquiris/features/transcript/presentation/transcript_editor_screen.dart';
import 'package:loquiris/features/transcript/presentation/transcript_versions_screen.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/routing/app_navigation_shell.dart';
import 'package:loquiris/routing/routes.dart';

/// Provides the single application router.
final appRouterProvider = Provider<GoRouter>((ref) {
  final remoteEnabled = ref.watch(remoteTranscriptionEnabledProvider);
  final router = GoRouter(
    initialLocation: AppRoutes.sessions,
    errorBuilder: (context, state) => const AppRouteScreen(
      destination: AppDestination.notFound,
    ),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppNavigationShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.sessions,
                builder: (context, state) => const SessionLibraryScreen(),
                routes: [
                  GoRoute(
                    path: ':meetingId',
                    builder: (context, state) => SessionDetailScreen(
                      meetingId: state.pathParameters['meetingId']!,
                      initialOffset: _parseMediaOffset(
                        state.uri.queryParameters['atUs'],
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => TranscriptEditorScreen(
                          meetingId: state.pathParameters['meetingId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'versions',
                        builder: (context, state) => TranscriptVersionsScreen(
                          meetingId: state.pathParameters['meetingId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'export',
                        builder: (context, state) => ExportScreen(
                          meetingId: state.pathParameters['meetingId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.newRecording,
                builder: (context, state) => const NewRecordingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.modelsPerformance,
                builder: (context, state) => remoteEnabled
                    ? const RemoteSettingsScreen()
                    : const ModelsPerformanceScreen(),
              ),
              GoRoute(
                path: AppRoutes.storagePrivacy,
                builder: (context, state) => const StoragePrivacyScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/recordings/:meetingId',
        builder: (context, state) => ActiveRecordingScreen(
          meetingId: state.pathParameters['meetingId']!,
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Stable route identities for the initial navigation skeleton.
enum AppDestination {
  /// Meeting library.
  sessions,

  /// New-recording setup.
  newRecording,

  /// Active recording and live draft.
  activeRecording,

  /// Saved meeting detail.
  sessionDetail,

  /// Transcript editor.
  transcriptEditor,

  /// Export flow.
  export,

  /// Model and performance settings.
  modelsPerformance,

  /// Storage and privacy settings.
  storagePrivacy,

  /// Unknown location.
  notFound,
}

/// Minimal destination used until feature screens replace the routing skeleton.
final class AppRouteScreen extends StatelessWidget {
  /// Creates a route destination from URL-derived identity.
  const AppRouteScreen({required this.destination, this.meetingId, super.key});

  /// Destination represented by this screen.
  final AppDestination destination;

  /// Meeting identity read from the URL, when applicable.
  final String? meetingId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = switch (destination) {
      AppDestination.sessions => l10n.sessionsTitle,
      AppDestination.newRecording => l10n.newRecordingTitle,
      AppDestination.activeRecording => l10n.activeRecordingTitle,
      AppDestination.sessionDetail => l10n.sessionDetailTitle,
      AppDestination.transcriptEditor => l10n.transcriptEditorTitle,
      AppDestination.export => l10n.exportTitle,
      AppDestination.modelsPerformance => l10n.modelsPerformanceTitle,
      AppDestination.storagePrivacy => l10n.storagePrivacyTitle,
      AppDestination.notFound => l10n.notFoundTitle,
    };
    final keySuffix = meetingId == null ? '' : ':$meetingId';
    final keyName = '${_keyName(destination)}$keySuffix';
    return Scaffold(
      key: ValueKey<String>(keyName),
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}

String _keyName(AppDestination destination) => switch (destination) {
  AppDestination.sessions => 'sessions',
  AppDestination.newRecording => 'new-recording',
  AppDestination.activeRecording => 'active-recording',
  AppDestination.sessionDetail => 'session-detail',
  AppDestination.transcriptEditor => 'transcript-editor',
  AppDestination.export => 'export',
  AppDestination.modelsPerformance => 'models-performance',
  AppDestination.storagePrivacy => 'storage-privacy',
  AppDestination.notFound => 'not-found',
};

Duration? _parseMediaOffset(String? value) {
  final microseconds = int.tryParse(value ?? '');
  if (microseconds == null || microseconds < 0) return null;
  return Duration(microseconds: microseconds);
}
