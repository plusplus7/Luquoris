import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loquiris/features/sessions/presentation/sessions_controller.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/routing/routes.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/theme/components/loquiris_adaptive_page.dart';
import 'package:loquiris/theme/loquiris_tokens.dart';

/// Local meeting library with exhaustive async states.
final class SessionLibraryScreen extends ConsumerWidget {
  /// Creates the library screen.
  const SessionLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionsControllerProvider);
    final l10n = AppLocalizations.of(context);
    final content = switch (state) {
      AsyncData(:final value) => switch (value) {
        SessionsLoaded(:final collection) when collection.sessions.isEmpty =>
          _SessionsEmpty(
            onStart: () => context.go(AppRoutes.newRecording),
          ),
        SessionsLoaded(:final collection) => _SessionsContent(
          sessions: collection.sessions,
        ),
        SessionsLoadFailed(:final failure) => _SessionsError(
          message: _messageForFailure(l10n, failure),
          onRetry: () => ref.read(sessionsControllerProvider.notifier).retry(),
        ),
      },
      AsyncError() => _SessionsError(
        message: l10n.sessionsLoadError,
        onRetry: () => ref.read(sessionsControllerProvider.notifier).retry(),
      ),
      _ => const _DelayedSessionsSkeleton(),
    };

    return LoquirisAdaptivePage(child: content);
  }
}

String _messageForFailure(
  AppLocalizations l10n,
  SessionRepositoryFailure failure,
) => l10n.sessionsLoadError;

final class _SessionsEmpty extends StatelessWidget {
  const _SessionsEmpty({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: const ValueKey<String>('sessions-empty'),
      liveRegion: true,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mic_none_rounded,
                    color: LoquirisColors.of(context).accent,
                  ),
                  Text(l10n.sessionsEmptyTitle),
                  Text(l10n.sessionsEmptyBody, textAlign: TextAlign.center),
                  FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.mic_rounded),
                    label: Text(l10n.startRecordingAction),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _SessionsError extends StatelessWidget {
  const _SessionsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: const ValueKey<String>('sessions-error'),
      liveRegion: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded),
          Text(message, textAlign: TextAlign.center),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(l10n.retryAction),
          ),
        ],
      ),
    );
  }
}

final class _SessionsContent extends StatelessWidget {
  const _SessionsContent({required this.sessions});

  final List<SessionSummary> sessions;

  @override
  Widget build(BuildContext context) {
    final hasRecovery = sessions.any((session) => session.isRecoverable);
    return ListView.builder(
      key: ValueKey<String>(
        hasRecovery ? 'sessions-recovery' : 'sessions-content',
      ),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        if (session.isRecoverable) return _RecoveryCard(session: session);
        return ListTile(
          leading: const Icon(Icons.graphic_eq_rounded),
          title: Text(session.title),
          trailing: Icon(Icons.adaptive.arrow_forward),
          onTap: () => context.push(AppRoutes.session(session.id)),
        );
      },
    );
  }
}

final class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({required this.session});

  final SessionSummary session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      key: ValueKey<String>('recovery-card:${session.id}'),
      child: ListTile(
        leading: const Icon(Icons.restore_rounded),
        title: Text(l10n.recoveryTitle),
        subtitle: Text(l10n.recoveryBody),
        trailing: TextButton(
          onPressed: () => context.push(AppRoutes.session(session.id)),
          child: Text(l10n.reviewRecordingAction),
        ),
      ),
    );
  }
}

final class _DelayedSessionsSkeleton extends StatefulWidget {
  const _DelayedSessionsSkeleton();

  @override
  State<_DelayedSessionsSkeleton> createState() =>
      _DelayedSessionsSkeletonState();
}

final class _DelayedSessionsSkeletonState
    extends State<_DelayedSessionsSkeleton> {
  Timer? _timer;
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer ??= Timer(LoquirisMotion.of(context).medium, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final colors = LoquirisColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      key: const ValueKey<String>('sessions-loading'),
      container: true,
      liveRegion: true,
      label: l10n.sessionsLoadingLabel,
      child: ExcludeSemantics(
        child: Column(
          children: List.generate(
            4,
            (index) => Padding(
              padding: EdgeInsetsDirectional.only(
                bottom: LoquirisSpacing.of(context).related,
              ),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  borderRadius: BorderRadiusDirectional.circular(
                    LoquirisShapes.of(context).controlRadius,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
