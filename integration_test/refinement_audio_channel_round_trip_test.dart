import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/method_channel_refinement_audio_service.dart';
import 'package:loquiris/services/refinement_audio_inventory_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('read-only inspection reaches Android without a recorder or DB', (
    tester,
  ) async {
    final result = await const MethodChannelRefinementAudioService().inspect(
      'round-trip-refinement-intentionally-absent',
    );
    final failure =
        (result as Err<RefinementAudioInventory, RefinementAudioFailure>)
            .failure;
    expect(failure, isA<RefinementAudioUnavailable>());
    // MissingPluginException has a different sanitized code. This proves that
    // Android's actual strict resolver handled the request, not a test fake.
    expect(failure.code, 'transcription_audio_missing');
  });
}
