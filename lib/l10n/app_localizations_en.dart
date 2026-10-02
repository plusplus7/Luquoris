// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Loquiris';

  @override
  String get appTagline => 'Offline meeting recorder';

  @override
  String get sessionsTitle => 'Meetings';

  @override
  String get newRecordingTitle => 'New recording';

  @override
  String get activeRecordingTitle => 'Recording';

  @override
  String get sessionDetailTitle => 'Meeting details';

  @override
  String get transcriptEditorTitle => 'Edit transcript';

  @override
  String get exportTitle => 'Export';

  @override
  String get modelsPerformanceTitle => 'Models and performance';

  @override
  String get storagePrivacyTitle => 'Storage and privacy';

  @override
  String get notFoundTitle => 'Page not found';

  @override
  String get navMeetings => 'Meetings';

  @override
  String get navRecord => 'Record';

  @override
  String get navSettings => 'Settings';

  @override
  String get sessionsEmptyTitle => 'No meetings yet';

  @override
  String get sessionsEmptyBody =>
      'Record a conversation and it will stay safely on this device.';

  @override
  String get startRecordingAction => 'Start a recording';

  @override
  String get sessionsLoadError =>
      'Loquiris could not read the meetings saved on this device.';

  @override
  String get retryAction => 'Try again';

  @override
  String get recoveryTitle => 'Interrupted recording found';

  @override
  String get recoveryBody =>
      'Saved audio is intact. Review it before deciding whether to continue.';

  @override
  String get reviewRecordingAction => 'Review recording';

  @override
  String get sessionsLoadingLabel => 'Loading meetings';

  @override
  String get benchmarkIntro =>
      'Run a short offline check to see which local processing mode this device can sustain.';

  @override
  String get benchmarkFixedAudioDisclosure =>
      'The check uses a bundled 45-second Mandarin and English audio sample. It never turns on the microphone, saves a recording, or changes settings.';

  @override
  String get benchmarkUnavailableHeading => 'Performance check unavailable';

  @override
  String get benchmarkUnavailableRuntimeBody =>
      'The local benchmark runtime is not installed in this build. Recording remains available.';

  @override
  String get benchmarkReadyHeading => 'Ready for the offline check';

  @override
  String get benchmarkStartAction => 'Start performance check';

  @override
  String get benchmarkRunningHeading => 'Performance check running';

  @override
  String benchmarkProgressPercent(int percent) {
    return '$percent% complete';
  }

  @override
  String get benchmarkCancelAction => 'Cancel performance check';

  @override
  String get benchmarkCancelledHeading => 'Check cancelled';

  @override
  String get benchmarkCancelledBody =>
      'No result was saved and no setting was changed.';

  @override
  String get benchmarkRecommendationHeading => 'Recommended mode';

  @override
  String get benchmarkShortCheckLimitation =>
      'This recommendation comes from a short check, not a long-session guarantee. Review it before choosing a mode.';

  @override
  String get benchmarkRerunAction => 'Run the check again';

  @override
  String get benchmarkFailureHeading => 'Check could not finish';

  @override
  String get benchmarkRetryAction => 'Retry performance check';

  @override
  String get benchmarkEvidenceHeading => 'Mode evidence';

  @override
  String get benchmarkStatusPassed => 'Passed';

  @override
  String get benchmarkStatusFailed => 'Failed';

  @override
  String get benchmarkStatusUnmeasured => 'Unmeasured';

  @override
  String get benchmarkStatusMeasured => 'Measured';

  @override
  String get benchmarkModeHighQuality => 'High quality';

  @override
  String get benchmarkModeBalanced => 'Balanced';

  @override
  String get benchmarkModePowerSaving => 'Power saving';

  @override
  String get benchmarkModeRecordingOnly => 'Recording only';

  @override
  String get benchmarkModePostSession => 'Post-session processing';

  @override
  String benchmarkRtfMetric(num value) {
    return 'Real-time factor: $value×';
  }

  @override
  String benchmarkLatencyMetric(int milliseconds) {
    return 'First text latency: $milliseconds ms';
  }

  @override
  String benchmarkModeStatusSemantic(String mode, String status) {
    return '$mode: $status';
  }

  @override
  String get benchmarkRecommendationBalanced =>
      'This device sustained the balanced live-processing thresholds in the short check.';

  @override
  String get benchmarkRecommendationPowerSaving =>
      'Power-saving live processing met the short-check thresholds when balanced mode did not.';

  @override
  String get benchmarkRecommendationPostSession =>
      'Processing after recording is the safest measured AI option for this device.';

  @override
  String get benchmarkRecommendationRecordingOnly =>
      'No measured AI mode met every short-check threshold, so recording only is the safe fallback.';

  @override
  String get benchmarkFailureInvalidAsset =>
      'The bundled benchmark audio is missing or failed its integrity check.';

  @override
  String get benchmarkFailureInvalidOutput =>
      'The benchmark runtime returned invalid output. No recommendation was produced.';

  @override
  String get benchmarkFailureEngine =>
      'The local inference engine stopped before the check completed.';

  @override
  String get benchmarkFailureRuntimeUnavailable =>
      'The local benchmark runtime is unavailable. Recording remains available.';

  @override
  String get benchmarkFailureGeneric =>
      'The local check stopped unexpectedly. No recommendation was saved.';

  @override
  String get benchmarkCompletedSemantic => 'Performance check completed';

  @override
  String get benchmarkFailedSemantic => 'Performance check failed';
}
