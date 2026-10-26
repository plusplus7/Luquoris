import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';
import 'package:loquiris/native/method_channel_refinement_execution_service.dart';
import 'package:loquiris/services/refinement_execution_service.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'frozen execution profile reaches strict Android input without DB or microphone',
    (tester) async {
      final profile =
          (ProcessingModelProfile.tryCreate(
                    bundleManifestJson: await rootBundle.loadString(
                      'build/generated/model_assets/model_manifests/whisper-base-q5_1.json',
                    ),
                    engineVersion: '1.9.4',
                    parametersJson:
                        '{"executionMode":"postSession","requestedTiming":"postSession","languageHint":"mixed","parameterVersion":1}',
                  )
                  as Ok<ProcessingModelProfile, InvalidProcessingSelection>)
              .value;
      final result = await const MethodChannelRefinementExecutionService()
          .transcribe(
            RefinementExecutionInput(
              meetingId: 'round-trip-refinement-intentionally-absent',
              runId: 'round-trip-refinement-run',
              audioInventorySha256: 'a' * 64,
              totalSamples: 1024,
              profile: profile,
            ),
          );
      final failure =
          (result as Err<TranscriptionOutput, RefinementExecutionFailure>)
              .failure;
      // This response can only originate after native profile validation and the
      // actual strict audio reader. MissingPluginException is a different code.
      expect(failure.code, 'transcription_audio_missing');
    },
  );
}
