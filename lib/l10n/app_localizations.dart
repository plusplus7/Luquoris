import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Product name shown in application chrome.
  ///
  /// In en, this message translates to:
  /// **'Loquiris'**
  String get appTitle;

  /// Short description on the initial application shell.
  ///
  /// In en, this message translates to:
  /// **'Offline meeting recorder'**
  String get appTagline;

  /// Title of the meeting library.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get sessionsTitle;

  /// Title of the recording setup screen.
  ///
  /// In en, this message translates to:
  /// **'New recording'**
  String get newRecordingTitle;

  /// Title of the active recording and live draft screen.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get activeRecordingTitle;

  /// Title of a saved meeting detail screen.
  ///
  /// In en, this message translates to:
  /// **'Meeting details'**
  String get sessionDetailTitle;

  /// Title of the transcript and label editor.
  ///
  /// In en, this message translates to:
  /// **'Edit transcript'**
  String get transcriptEditorTitle;

  /// Title of the local export flow.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportTitle;

  /// Title of model and performance settings.
  ///
  /// In en, this message translates to:
  /// **'Models and performance'**
  String get modelsPerformanceTitle;

  /// Title of storage and privacy settings.
  ///
  /// In en, this message translates to:
  /// **'Storage and privacy'**
  String get storagePrivacyTitle;

  /// Title shown for an unknown deep link.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get notFoundTitle;

  /// Primary navigation label for the meeting library.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get navMeetings;

  /// Primary navigation label for starting a recording.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get navRecord;

  /// Primary navigation label for local app settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Heading shown when the local meeting library is empty.
  ///
  /// In en, this message translates to:
  /// **'No meetings yet'**
  String get sessionsEmptyTitle;

  /// Privacy-oriented explanation shown in an empty meeting library.
  ///
  /// In en, this message translates to:
  /// **'Record a conversation and it will stay safely on this device.'**
  String get sessionsEmptyBody;

  /// Primary action shown in an empty meeting library.
  ///
  /// In en, this message translates to:
  /// **'Start a recording'**
  String get startRecordingAction;

  /// Safe user-facing message for a local meeting repository failure.
  ///
  /// In en, this message translates to:
  /// **'Loquiris could not read the meetings saved on this device.'**
  String get sessionsLoadError;

  /// Action label for retrying a failed local operation.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retryAction;

  /// Heading for committed audio recovered after an interruption.
  ///
  /// In en, this message translates to:
  /// **'Interrupted recording found'**
  String get recoveryTitle;

  /// Recovery explanation that does not imply automatic microphone restart.
  ///
  /// In en, this message translates to:
  /// **'Saved audio is intact. Review it before deciding whether to continue.'**
  String get recoveryBody;

  /// Action opening an interrupted meeting without restarting capture.
  ///
  /// In en, this message translates to:
  /// **'Review recording'**
  String get reviewRecordingAction;

  /// Live-region label announced while the local meeting library loads.
  ///
  /// In en, this message translates to:
  /// **'Loading meetings'**
  String get sessionsLoadingLabel;

  /// Introduces the optional first-run performance benchmark.
  ///
  /// In en, this message translates to:
  /// **'Run a short offline check to see which local processing mode this device can sustain.'**
  String get benchmarkIntro;

  /// Discloses the fixed benchmark input and guarantees microphone and settings isolation.
  ///
  /// In en, this message translates to:
  /// **'The check uses a bundled 45-second Mandarin and English audio sample. It never turns on the microphone, saves a recording, or changes settings.'**
  String get benchmarkFixedAudioDisclosure;

  /// Heading above the read-only performance policy overview on the Models and Performance screen.
  ///
  /// In en, this message translates to:
  /// **'Operating modes and recording protection'**
  String get performancePolicyHeading;

  /// Locked-availability explanation repeated in each performance policy card.
  ///
  /// In en, this message translates to:
  /// **'Modes remain informational until a compatible local inference runtime and model pass validation. This screen never changes settings automatically.'**
  String get performancePolicyLockedBody;

  /// Non-interactive marker on the policy card recommended by the completed benchmark.
  ///
  /// In en, this message translates to:
  /// **'Recommended by this check'**
  String get performancePolicyRecommendedLabel;

  /// Timing label on performance policy cards that permit live or post-session processing.
  ///
  /// In en, this message translates to:
  /// **'During recording or after recording'**
  String get performancePolicyTimingLiveOrPostSession;

  /// Timing label on performance policy cards restricted to post-session processing.
  ///
  /// In en, this message translates to:
  /// **'After recording only'**
  String get performancePolicyTimingPostSessionOnly;

  /// Timing label on the recording-only policy card.
  ///
  /// In en, this message translates to:
  /// **'AI processing off'**
  String get performancePolicyTimingDisabled;

  /// Description on the high-quality performance policy card.
  ///
  /// In en, this message translates to:
  /// **'Uses a validated higher-quality model after recording.'**
  String get performancePolicyHighQualityDescription;

  /// Fallback explanation on the high-quality performance policy card.
  ///
  /// In en, this message translates to:
  /// **'Falls back to balanced post-session processing, then recording only.'**
  String get performancePolicyHighQualityFallback;

  /// Description on the balanced performance policy card.
  ///
  /// In en, this message translates to:
  /// **'Balances transcript quality with device resources.'**
  String get performancePolicyBalancedDescription;

  /// Fallback explanation on the balanced performance policy card.
  ///
  /// In en, this message translates to:
  /// **'Reduces resource use, defers work, or keeps recording only.'**
  String get performancePolicyBalancedFallback;

  /// Description on the power-saving performance policy card.
  ///
  /// In en, this message translates to:
  /// **'Uses a smaller model or reduced concurrency when validated.'**
  String get performancePolicyPowerSavingDescription;

  /// Fallback explanation on the power-saving performance policy card.
  ///
  /// In en, this message translates to:
  /// **'Defers work until after recording, then keeps recording only if needed.'**
  String get performancePolicyPowerSavingFallback;

  /// Description on the post-session performance policy card.
  ///
  /// In en, this message translates to:
  /// **'Reserves capture-time resources and analyzes locally after recording.'**
  String get performancePolicyPostSessionDescription;

  /// Fallback explanation on the post-session performance policy card.
  ///
  /// In en, this message translates to:
  /// **'Recording remains available if analysis cannot run.'**
  String get performancePolicyPostSessionFallback;

  /// Description on the recording-only performance policy card.
  ///
  /// In en, this message translates to:
  /// **'Saves canonical audio without running AI.'**
  String get performancePolicyRecordingOnlyDescription;

  /// Fallback explanation on the recording-only performance policy card.
  ///
  /// In en, this message translates to:
  /// **'Recording continues without an AI fallback.'**
  String get performancePolicyRecordingOnlyFallback;

  /// Heading above recording-protection explanations in the performance policy overview.
  ///
  /// In en, this message translates to:
  /// **'How Loquiris protects recording'**
  String get performancePolicyProtectionHeading;

  /// Moderate-thermal protection explanation in the performance policy overview.
  ///
  /// In en, this message translates to:
  /// **'Moderate heat reduces AI concurrency.'**
  String get performancePolicyProtectionModerateThermal;

  /// Severe-thermal protection explanation in the performance policy overview.
  ///
  /// In en, this message translates to:
  /// **'Severe heat pauses AI while recording continues.'**
  String get performancePolicyProtectionSevereThermal;

  /// Backlog protection explanation in the performance policy overview.
  ///
  /// In en, this message translates to:
  /// **'Sustained backlog moves unfinished work to after recording.'**
  String get performancePolicyProtectionBacklog;

  /// Recording-first failure protection explanation in the performance policy overview.
  ///
  /// In en, this message translates to:
  /// **'Engine or resource failure never discards canonical recording audio.'**
  String get performancePolicyProtectionRecordingFirst;

  /// No description provided for @benchmarkUnavailableHeading.
  ///
  /// In en, this message translates to:
  /// **'Performance check unavailable'**
  String get benchmarkUnavailableHeading;

  /// No description provided for @benchmarkUnavailableRuntimeBody.
  ///
  /// In en, this message translates to:
  /// **'The local benchmark runtime is not installed in this build. Recording remains available.'**
  String get benchmarkUnavailableRuntimeBody;

  /// No description provided for @benchmarkReadyHeading.
  ///
  /// In en, this message translates to:
  /// **'Ready for the offline check'**
  String get benchmarkReadyHeading;

  /// No description provided for @benchmarkStartAction.
  ///
  /// In en, this message translates to:
  /// **'Start performance check'**
  String get benchmarkStartAction;

  /// No description provided for @benchmarkRunningHeading.
  ///
  /// In en, this message translates to:
  /// **'Performance check running'**
  String get benchmarkRunningHeading;

  /// Visible normalized progress for the short performance benchmark.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String benchmarkProgressPercent(int percent);

  /// No description provided for @benchmarkCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel performance check'**
  String get benchmarkCancelAction;

  /// No description provided for @benchmarkCancelledHeading.
  ///
  /// In en, this message translates to:
  /// **'Check cancelled'**
  String get benchmarkCancelledHeading;

  /// No description provided for @benchmarkCancelledBody.
  ///
  /// In en, this message translates to:
  /// **'No result was saved and no setting was changed.'**
  String get benchmarkCancelledBody;

  /// No description provided for @benchmarkRecommendationHeading.
  ///
  /// In en, this message translates to:
  /// **'Recommended mode'**
  String get benchmarkRecommendationHeading;

  /// No description provided for @benchmarkShortCheckLimitation.
  ///
  /// In en, this message translates to:
  /// **'This recommendation comes from a short check, not a long-session guarantee. Review it before choosing a mode.'**
  String get benchmarkShortCheckLimitation;

  /// No description provided for @benchmarkRerunAction.
  ///
  /// In en, this message translates to:
  /// **'Run the check again'**
  String get benchmarkRerunAction;

  /// No description provided for @benchmarkFailureHeading.
  ///
  /// In en, this message translates to:
  /// **'Check could not finish'**
  String get benchmarkFailureHeading;

  /// No description provided for @benchmarkRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry performance check'**
  String get benchmarkRetryAction;

  /// No description provided for @benchmarkEvidenceHeading.
  ///
  /// In en, this message translates to:
  /// **'Mode evidence'**
  String get benchmarkEvidenceHeading;

  /// No description provided for @benchmarkStatusPassed.
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get benchmarkStatusPassed;

  /// No description provided for @benchmarkStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get benchmarkStatusFailed;

  /// No description provided for @benchmarkStatusUnmeasured.
  ///
  /// In en, this message translates to:
  /// **'Unmeasured'**
  String get benchmarkStatusUnmeasured;

  /// No description provided for @benchmarkStatusMeasured.
  ///
  /// In en, this message translates to:
  /// **'Measured'**
  String get benchmarkStatusMeasured;

  /// No description provided for @benchmarkModeHighQuality.
  ///
  /// In en, this message translates to:
  /// **'High quality'**
  String get benchmarkModeHighQuality;

  /// No description provided for @benchmarkModeBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get benchmarkModeBalanced;

  /// No description provided for @benchmarkModePowerSaving.
  ///
  /// In en, this message translates to:
  /// **'Power saving'**
  String get benchmarkModePowerSaving;

  /// No description provided for @benchmarkModeRecordingOnly.
  ///
  /// In en, this message translates to:
  /// **'Recording only'**
  String get benchmarkModeRecordingOnly;

  /// No description provided for @benchmarkModePostSession.
  ///
  /// In en, this message translates to:
  /// **'Post-session processing'**
  String get benchmarkModePostSession;

  /// Measured processing-to-audio time ratio for one benchmark mode.
  ///
  /// In en, this message translates to:
  /// **'Real-time factor: {value}×'**
  String benchmarkRtfMetric(num value);

  /// Measured time until the first non-empty local transcript text.
  ///
  /// In en, this message translates to:
  /// **'First text latency: {milliseconds} ms'**
  String benchmarkLatencyMetric(int milliseconds);

  /// Screen-reader label combining a benchmark mode and its evidence status.
  ///
  /// In en, this message translates to:
  /// **'{mode}: {status}'**
  String benchmarkModeStatusSemantic(String mode, String status);

  /// No description provided for @benchmarkRecommendationBalanced.
  ///
  /// In en, this message translates to:
  /// **'This device sustained the balanced live-processing thresholds in the short check.'**
  String get benchmarkRecommendationBalanced;

  /// No description provided for @benchmarkRecommendationPowerSaving.
  ///
  /// In en, this message translates to:
  /// **'Power-saving live processing met the short-check thresholds when balanced mode did not.'**
  String get benchmarkRecommendationPowerSaving;

  /// No description provided for @benchmarkRecommendationPostSession.
  ///
  /// In en, this message translates to:
  /// **'Processing after recording is the safest measured AI option for this device.'**
  String get benchmarkRecommendationPostSession;

  /// No description provided for @benchmarkRecommendationRecordingOnly.
  ///
  /// In en, this message translates to:
  /// **'No measured AI mode met every short-check threshold, so recording only is the safe fallback.'**
  String get benchmarkRecommendationRecordingOnly;

  /// No description provided for @benchmarkFailureInvalidAsset.
  ///
  /// In en, this message translates to:
  /// **'The bundled benchmark audio is missing or failed its integrity check.'**
  String get benchmarkFailureInvalidAsset;

  /// No description provided for @benchmarkFailureInvalidOutput.
  ///
  /// In en, this message translates to:
  /// **'The benchmark runtime returned invalid output. No recommendation was produced.'**
  String get benchmarkFailureInvalidOutput;

  /// No description provided for @benchmarkFailureEngine.
  ///
  /// In en, this message translates to:
  /// **'The local inference engine stopped before the check completed.'**
  String get benchmarkFailureEngine;

  /// No description provided for @benchmarkFailureRuntimeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The local benchmark runtime is unavailable. Recording remains available.'**
  String get benchmarkFailureRuntimeUnavailable;

  /// No description provided for @benchmarkFailureGeneric.
  ///
  /// In en, this message translates to:
  /// **'The local check stopped unexpectedly. No recommendation was saved.'**
  String get benchmarkFailureGeneric;

  /// No description provided for @benchmarkCompletedSemantic.
  ///
  /// In en, this message translates to:
  /// **'Performance check completed'**
  String get benchmarkCompletedSemantic;

  /// No description provided for @benchmarkFailedSemantic.
  ///
  /// In en, this message translates to:
  /// **'Performance check failed'**
  String get benchmarkFailedSemantic;

  /// No description provided for @benchmarkExportAction.
  ///
  /// In en, this message translates to:
  /// **'Export report'**
  String get benchmarkExportAction;

  /// No description provided for @benchmarkExportingAction.
  ///
  /// In en, this message translates to:
  /// **'Exporting report…'**
  String get benchmarkExportingAction;

  /// Confirms a benchmark report export using only the destination-provided display filename.
  ///
  /// In en, this message translates to:
  /// **'Saved {fileName}.'**
  String benchmarkExportSucceeded(String fileName);

  /// No description provided for @benchmarkExportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export cancelled. No file was saved.'**
  String get benchmarkExportCancelled;

  /// No description provided for @benchmarkExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Report could not be exported. Try again.'**
  String get benchmarkExportFailed;

  /// No description provided for @sessionJobTranscription.
  ///
  /// In en, this message translates to:
  /// **'Transcription'**
  String get sessionJobTranscription;

  /// No description provided for @transcriptionPreparingModel.
  ///
  /// In en, this message translates to:
  /// **'Preparing the offline model'**
  String get transcriptionPreparingModel;

  /// No description provided for @transcriptionDecodingAudio.
  ///
  /// In en, this message translates to:
  /// **'Decoding saved audio'**
  String get transcriptionDecodingAudio;

  /// Durably persisted post-session transcription progress.
  ///
  /// In en, this message translates to:
  /// **'Transcribing locally {percent}%'**
  String transcriptionProgress(int percent);

  /// No description provided for @transcriptionDelayed.
  ///
  /// In en, this message translates to:
  /// **'Transcription is delayed. Your recording is safe and processing will resume locally.'**
  String get transcriptionDelayed;

  /// No description provided for @transcriptionIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The transcript is incomplete. Your recording is safe and you can try again.'**
  String get transcriptionIncomplete;

  /// No description provided for @transcriptionRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry transcription'**
  String get transcriptionRetryAction;

  /// No description provided for @transcriptionRetrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying transcription…'**
  String get transcriptionRetrying;

  /// No description provided for @transcriptionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Transcription was cancelled. Your recording is safe.'**
  String get transcriptionCancelled;

  /// No description provided for @transcriptionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Transcription completed'**
  String get transcriptionCompleted;

  /// No description provided for @transcriptionFailureModel.
  ///
  /// In en, this message translates to:
  /// **'The bundled transcription model could not be verified. Your recording is safe.'**
  String get transcriptionFailureModel;

  /// No description provided for @transcriptionFailureEngine.
  ///
  /// In en, this message translates to:
  /// **'The offline transcription engine could not finish. Your recording is safe.'**
  String get transcriptionFailureEngine;

  /// No description provided for @transcriptionFailureStorage.
  ///
  /// In en, this message translates to:
  /// **'Transcription progress could not be saved locally. Your recording is safe.'**
  String get transcriptionFailureStorage;

  /// No description provided for @transcriptionFailureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Transcription could not finish. Your recording is safe.'**
  String get transcriptionFailureUnknown;

  /// No description provided for @transcriptionRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Transcription could not be restarted. You can try again.'**
  String get transcriptionRetryFailed;

  /// No description provided for @transcriptPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Transcript preview'**
  String get transcriptPreviewTitle;

  /// No description provided for @transcriptPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'The completed transcript contains no stable text.'**
  String get transcriptPreviewEmpty;

  /// No description provided for @liveTranscriptTitle.
  ///
  /// In en, this message translates to:
  /// **'Live transcript draft'**
  String get liveTranscriptTitle;

  /// No description provided for @liveTranscriptExperimentalLabel.
  ///
  /// In en, this message translates to:
  /// **'Experimental · read only'**
  String get liveTranscriptExperimentalLabel;

  /// No description provided for @liveTranscriptWaiting.
  ///
  /// In en, this message translates to:
  /// **'Listening for the first local draft…'**
  String get liveTranscriptWaiting;

  /// No description provided for @liveTranscriptStableLabel.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get liveTranscriptStableLabel;

  /// No description provided for @liveTranscriptDraftLabel.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get liveTranscriptDraftLabel;

  /// Screen-reader label for a stable live transcript segment.
  ///
  /// In en, this message translates to:
  /// **'Stable. {text}'**
  String liveTranscriptStableSegment(String text);

  /// Screen-reader label for a replaceable live transcript segment.
  ///
  /// In en, this message translates to:
  /// **'Draft. {text}'**
  String liveTranscriptDraftSegment(String text);

  /// Visible live-transcription backlog rounded up to whole seconds.
  ///
  /// In en, this message translates to:
  /// **'The live draft is about {seconds} seconds behind.'**
  String liveTranscriptBacklog(int seconds);

  /// No description provided for @liveTranscriptIncomplete.
  ///
  /// In en, this message translates to:
  /// **'This live draft may be incomplete.'**
  String get liveTranscriptIncomplete;

  /// No description provided for @liveTranscriptThermalFallback.
  ///
  /// In en, this message translates to:
  /// **'Live transcription paused because this device is too warm.'**
  String get liveTranscriptThermalFallback;

  /// No description provided for @liveTranscriptModelFallback.
  ///
  /// In en, this message translates to:
  /// **'The local model could not start live transcription.'**
  String get liveTranscriptModelFallback;

  /// No description provided for @liveTranscriptGenericFallback.
  ///
  /// In en, this message translates to:
  /// **'Live transcription stopped safely.'**
  String get liveTranscriptGenericFallback;

  /// No description provided for @liveTranscriptPostSessionFallback.
  ///
  /// In en, this message translates to:
  /// **'A complete transcript will run after recording.'**
  String get liveTranscriptPostSessionFallback;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
