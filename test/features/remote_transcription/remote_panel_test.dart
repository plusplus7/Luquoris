import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/remote_transcription/application/remote_feature.dart';
import 'package:loquiris/features/remote_transcription/presentation/remote_transcription_panel.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/services/remote_transcription_repository.dart';
import 'package:loquiris/services/remote_transcription_service.dart';

void main() {
  testWidgets('actual server retention and expiry are visible', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RemoteTaskTile(
            task: RemoteTask(
              id: 'run',
              state: 'running',
              confirmedBytes: 1,
              totalBytes: 2,
              retentionSeconds: 7200,
              expiresAtUtcMs: 2000000000000,
            ),
            onCancel: null,
          ),
        ),
      ),
    );
    expect(find.textContaining('7200'), findsOneWidget);
    expect(find.textContaining('Server copy expires'), findsOneWidget);
  });
  testWidgets(
    'unconfigured intent links to central settings without duplicate run controls',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remoteTranscriptionEnabledProvider.overrideWithValue(true),
            remoteTranscriptionRepositoryProvider.overrideWithValue(
              _Repository(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: RemoteTranscriptionPanel(meetingId: 'meeting-1'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Remote transcription'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Configure a server'), findsOneWidget);
      expect(find.text('Configure server'), findsOneWidget);
      expect(find.text('Start transcription'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

final class _Repository implements RemoteTranscriptionRepository {
  @override
  Future<
    Result<(List<RemoteTask>, List<RemoteVersion>), RemoteTranscriptionFailure>
  >
  load(String meeting) async => const Ok((
    [
      RemoteTask(
        id: 'run',
        state: 'waitingSetup',
        confirmedBytes: 0,
        totalBytes: 0,
      ),
    ],
    <RemoteVersion>[],
  ));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
