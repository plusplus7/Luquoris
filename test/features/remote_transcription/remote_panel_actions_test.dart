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
  testWidgets(
    'an active run offers cancellation without duplicate start or credentials',
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
                child: RemoteTranscriptionPanel(meetingId: 'meeting'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Start transcription'), findsNothing);
      expect(find.byTooltip('Cancel remote task'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('failed terminal runs have no ineffective cancel button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RemoteTaskTile(
            task: RemoteTask(
              id: 'run',
              state: 'failed',
              confirmedBytes: 0,
              totalBytes: 0,
            ),
            onCancel: null,
          ),
        ),
      ),
    );
    expect(find.byTooltip('Cancel remote task'), findsNothing);
  });
}

final class _Repository implements RemoteTranscriptionRepository {
  @override
  Future<
    Result<(List<RemoteTask>, List<RemoteVersion>), RemoteTranscriptionFailure>
  >
  load(String meeting) async => const Ok((
    [RemoteTask(id: 'run', state: 'running', confirmedBytes: 1, totalBytes: 2)],
    <RemoteVersion>[],
  ));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
