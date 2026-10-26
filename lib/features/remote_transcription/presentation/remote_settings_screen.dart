import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loquiris/features/remote_transcription/application/remote_settings_controller.dart';
import 'package:loquiris/features/remote_transcription/presentation/remote_connection_form.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/routing/routes.dart';
import 'package:loquiris/services/remote_transcription_service.dart';
import 'package:loquiris/theme/components/loquiris_adaptive_page.dart';
import 'package:loquiris/theme/loquiris_tokens.dart';

/// Central server configuration, separate from meeting-specific upload consent.
final class RemoteSettingsScreen extends ConsumerWidget {
  /// Reconstructs the default server from the durable platform boundary.
  const RemoteSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(remoteSettingsControllerProvider);
    final connection = state.value;
    final l10n = AppLocalizations.of(context);
    final spacing = LoquirisSpacing.of(context);
    final form = RemoteConnectionForm(
      key: ValueKey(connection?.credentialRef),
      busy: state.isLoading,
      initialEndpoint: connection?.endpoint ?? '',
      onSubmit: (endpoint, token) => unawaited(
        ref
            .read(remoteSettingsControllerProvider.notifier)
            .save(endpoint, token),
      ),
    );
    return Scaffold(
      key: const Key('remote-settings'),
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: LoquirisAdaptivePage(
        child: ListView(
          children: [
            Text(
              l10n.remoteServerSettings,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: spacing.related),
            Text(l10n.remoteLanExplanation),
            SizedBox(height: spacing.section),
            if (state.isLoading) const LinearProgressIndicator(),
            if (state case AsyncError(:final error))
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.remoteFailure(
                    switch (error) {
                      RemoteSettingsLoadException(:final failure) =>
                        failure.code,
                      RemoteTranscriptionFailure(:final code) => code,
                      _ => 'remote_storage_unavailable',
                    },
                  ),
                ),
              ),
            if (connection == null)
              form
            else ...[
              ListTile(
                contentPadding: EdgeInsetsDirectional.zero,
                leading: const Icon(Icons.check_circle_outline),
                title: Text(l10n.remoteConnectionSaved),
                subtitle: Text(
                  connection.endpoint,
                  key: const Key('remote-saved-endpoint'),
                ),
              ),
              ExpansionTile(
                key: ValueKey('edit-${connection.credentialRef}'),
                title: Text(l10n.remoteChangeConnection),
                children: [form],
              ),
            ],
            SizedBox(height: spacing.section),
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: Text(l10n.storagePrivacyTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.storagePrivacy),
            ),
          ],
        ),
      ),
    );
  }
}
