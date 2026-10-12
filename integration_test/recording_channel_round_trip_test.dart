import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/method_channel_recording_control_gateway.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Dart restores the persisted snapshot through the Android channel',
    (
      tester,
    ) async {
      const gateway = MethodChannelRecordingControlGateway();

      final result = await gateway.current();

      expect(result, isA<Ok<AudioCaptureSnapshot, AudioCaptureFailure>>());
      final snapshot =
          (result as Ok<AudioCaptureSnapshot, AudioCaptureFailure>).value;
      expect(snapshot.elapsed.inMilliseconds, isNot(isNegative));
      expect(snapshot.bytesWritten, isNot(isNegative));
      expect(snapshot.revision, isNot(isNegative));
      expect(
        snapshot.state == AudioCaptureState.idle,
        snapshot.sessionId == null,
      );
    },
  );
}
