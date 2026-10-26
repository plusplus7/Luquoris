import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/remote_transcription/application/remote_feature.dart';
import 'package:loquiris/services/remote_transcription_repository.dart';
import 'package:loquiris/services/remote_transcription_service.dart';
import 'package:loquiris/services/service_providers.dart';
import '../../support/fakes/fake_services.dart';
import '../../support/recording_processing_fixture.dart';

void main() {
  testWidgets('remote capture omits unused language and speaker controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...recordingProcessingOverrides(),
          remoteTranscriptionEnabledProvider.overrideWithValue(true),
          sessionRepositoryProvider.overrideWithValue(FakeSessionRepository()),
          remoteTranscriptionRepositoryProvider.overrideWithValue(
            _Repository(),
          ),
        ],
        child: const LoquirisApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('new-recording-language-english')),
      findsNothing,
    );
    expect(find.byKey(const Key('new-recording-speakers-4')), findsNothing);
    expect(
      find.byKey(const Key('new-recording-mode-post-session')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('new-recording-mode-recording-only')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('new-recording-start')), findsOneWidget);
  });
}

final class _Repository implements RemoteTranscriptionRepository {
  @override
  Future<Result<RemoteDestination?, RemoteTranscriptionFailure>>
  latestDestination() async => const Ok(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
