import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/method_channel_transcription_engine.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Dart cancellation round-trips through the Android channel', (
    tester,
  ) async {
    final engine = MethodChannelTranscriptionEngine();

    final result = await engine.cancel('round-trip-no-active-run');

    expect(result, isA<Ok<void, TranscriptionFailure>>());
  });
}
