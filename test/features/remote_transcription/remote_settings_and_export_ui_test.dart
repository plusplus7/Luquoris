import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/remote_transcription/domain/remote_transcript.dart';
import 'package:loquiris/features/remote_transcription/presentation/remote_settings_screen.dart';
import 'package:loquiris/features/remote_transcription/presentation/remote_transcription_panel.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/services/remote_transcription_repository.dart';
import 'package:loquiris/services/remote_transcription_service.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/theme/app_theme.dart';

void main() {
  testWidgets(
    'saved connection is visible while replacement credentials stay collapsed',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remoteTranscriptionRepositoryProvider.overrideWithValue(
              _Repository(),
            ),
          ],
          child: MaterialApp(
            theme: buildLoquirisTheme(Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const RemoteSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('http://192.168.1.20:18000'), findsOneWidget);
      expect(find.byKey(const Key('remote-token')), findsNothing);
      await tester.tap(find.text('Change connection'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('remote-token')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'result edits expose save only when dirty and exports share one menu',
    (tester) async {
      const fixtures = 'contracts/remote_transcription/v1/fixtures';
      final upload =
          jsonDecode(File('$fixtures/upload.json').readAsStringSync())
              as Map<String, Object?>;
      final json =
          jsonDecode(File('$fixtures/result.json').readAsStringSync())
              as Map<String, Object?>;
      final result = RemoteTranscript.tryParse(
        json,
        meetingId: 'meeting-1',
        runId: 'run-1',
        manifestDigest: remoteManifestDigest(upload),
      )!;
      String? saved;
      ExportFormat? exported;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RemoteVersionCard(
                version: RemoteVersion(
                  id: 'run-1',
                  result: result,
                  resultJson: jsonEncode(json),
                ),
                onSave: (text) => saved = text,
                onExport: (format) => exported = format,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Save correction'), findsNothing);
      await tester.enterText(find.byType(TextField), 'corrected');
      await tester.pump();
      await tester.tap(find.text('Save correction'));
      expect(saved, 'corrected');
      expect(find.byType(PopupMenuButton<ExportFormat>), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<ExportFormat>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export JSON'));
      await tester.pumpAndSettle();
      expect(exported, ExportFormat.json);
      expect(tester.takeException(), isNull);
    },
  );
}

final class _Repository implements RemoteTranscriptionRepository {
  @override
  Future<Result<RemoteDestination?, RemoteTranscriptionFailure>>
  latestDestination() async => const Ok(
    RemoteDestination('http://192.168.1.20:18000', 'reference', 'qwen-1.7b'),
  );
  @override
  Future<Result<void, RemoteTranscriptionFailure>> configurePending(
    RemoteDestination destination,
  ) async => const Ok(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
