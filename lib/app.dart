import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/bootstrap/bootstrap.dart';
import 'package:loquiris/features/recording/presentation/recording_controller.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/l10n/locale_controller.dart';
import 'package:loquiris/routing/app_router.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/theme/app_theme.dart';

/// Root application widget, independent of concrete infrastructure.
final class LoquirisApp extends ConsumerStatefulWidget {
  /// Creates the application widget.
  const LoquirisApp({super.key});

  @override
  ConsumerState<LoquirisApp> createState() => _LoquirisAppState();
}

final class _LoquirisAppState extends ConsumerState<LoquirisApp>
    with RootLifecycleObserver<LoquirisApp> {
  @override
  void initState() {
    super.initState();
    registerRootLifecycleObserver();
  }

  @override
  void dispose() {
    unregisterRootLifecycleObserver();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..watch(recordingControllerProvider)
      ..watch(transcriptionCoordinatorProvider)
      ..listen(recordingControllerProvider, (previous, next) {
        final meetingId = _transcriptionReadyMeetingId(next);
        if (meetingId != null) {
          ref.read(transcriptionFinalizationHandlerProvider)(meetingId);
        }
      });
    final locale = ref.watch(localeControllerProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      theme: buildLoquirisTheme(Brightness.light),
      darkTheme: buildLoquirisTheme(Brightness.dark),
      themeAnimationStyle: AnimationStyle.noAnimation,
    );
  }
}

String? _transcriptionReadyMeetingId(
  AsyncValue<RecordingViewState> value,
) {
  final recording = value.value;
  final snapshot = recording?.snapshot;
  return snapshot?.state == AudioCaptureState.finalized &&
          recording?.persistencePending == false &&
          recording?.persistenceFailure == null
      ? snapshot?.sessionId
      : null;
}
