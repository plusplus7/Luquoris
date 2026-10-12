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

  /// Finalizes recovered audio without opening the microphone.
  ///
  /// In en, this message translates to:
  /// **'Save recovered recording'**
  String get saveRecoveredRecordingAction;

  /// Explicitly starts a new continuation segment.
  ///
  /// In en, this message translates to:
  /// **'Continue recording'**
  String get continueRecordingAction;

  /// Closes a confirmation without changing local state.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// Privacy-safe retryable failure shown when recovery resolution fails.
  ///
  /// In en, this message translates to:
  /// **'Loquiris could not apply that recovery choice. Your saved audio is unchanged.'**
  String get recoveryActionFailed;

  /// Live-region label announced while the local meeting library loads.
  ///
  /// In en, this message translates to:
  /// **'Loading meetings'**
  String get sessionsLoadingLabel;

  /// Hint shown in the local meeting and transcript search field.
  ///
  /// In en, this message translates to:
  /// **'Search meetings'**
  String get sessionsSearchHint;

  /// Label for the active-meeting library segment inside the Meetings screen.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get meetingsLibraryTab;

  /// Label for the local trash segment inside the Meetings screen.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trashTab;

  /// Tooltip for the menu containing actions for one meeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting actions'**
  String get meetingActionsTooltip;

  /// Action that changes a meeting title.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameMeetingAction;

  /// Action that moves a meeting into local trash.
  ///
  /// In en, this message translates to:
  /// **'Move to trash'**
  String get moveToTrashAction;

  /// Action that restores a meeting from local trash.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreMeetingAction;

  /// Confirms and saves a local edit.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// Input label for an editable meeting title.
  ///
  /// In en, this message translates to:
  /// **'Meeting title'**
  String get meetingTitleLabel;

  /// Heading shown when local meeting trash is empty.
  ///
  /// In en, this message translates to:
  /// **'Trash is empty'**
  String get trashEmptyTitle;

  /// Explanation shown when local meeting trash is empty.
  ///
  /// In en, this message translates to:
  /// **'Deleted meetings stay here until you permanently remove them.'**
  String get trashEmptyBody;

  /// No description provided for @trashRetentionNotice.
  ///
  /// In en, this message translates to:
  /// **'Seven-day local trash. Nothing is deleted automatically; restore or permanently delete items yourself.'**
  String get trashRetentionNotice;

  /// No description provided for @permanentDeleteMeetingAction.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get permanentDeleteMeetingAction;

  /// No description provided for @retryPermanentDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Retry permanent deletion'**
  String get retryPermanentDeleteAction;

  /// No description provided for @permanentDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete this meeting?'**
  String get permanentDeleteTitle;

  /// No description provided for @permanentDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This removes private audio, transcript, revisions, bookmarks, and meeting metadata from this device. Loquiris cannot delete copies you exported or backed up elsewhere.'**
  String get permanentDeleteBody;

  /// No description provided for @permanentDeletePending.
  ///
  /// In en, this message translates to:
  /// **'Deleting private meeting data…'**
  String get permanentDeletePending;

  /// No description provided for @permanentDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Deletion did not finish. Your meeting remains locked for a safe retry.'**
  String get permanentDeleteFailed;

  /// Heading shown when local meeting search has no results.
  ///
  /// In en, this message translates to:
  /// **'No local matches'**
  String get searchEmptyTitle;

  /// Suggestion shown when local meeting search has no results.
  ///
  /// In en, this message translates to:
  /// **'Try a meeting title or words from the transcript.'**
  String get searchEmptyBody;

  /// Badge for a draft meeting.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get meetingStatusDraft;

  /// Badge for a meeting preparing to record.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get meetingStatusPreparing;

  /// Badge for an actively recording meeting.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get meetingStatusRecording;

  /// Badge for a paused recording.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get meetingStatusPaused;

  /// Badge for a recording being safely finalized.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get meetingStatusStopping;

  /// Badge for a finalized meeting.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get meetingStatusFinished;

  /// Badge for an interrupted meeting requiring review.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get meetingStatusRecoverable;

  /// Badge for a meeting whose finalization failed.
  ///
  /// In en, this message translates to:
  /// **'Save incomplete'**
  String get meetingStatusFailed;

  /// Badge for a meeting in local trash.
  ///
  /// In en, this message translates to:
  /// **'In trash'**
  String get meetingStatusTrashed;

  /// Badge for a permanently deleting meeting.
  ///
  /// In en, this message translates to:
  /// **'Deleting'**
  String get meetingStatusDeleting;

  /// Localized default title created when recording starts without a title.
  ///
  /// In en, this message translates to:
  /// **'Meeting {date} {time}'**
  String meetingDefaultTitle(String date, String time);

  /// Compact metadata line shown for one meeting.
  ///
  /// In en, this message translates to:
  /// **'{date} · {duration} · {size}'**
  String meetingMetadata(String date, String duration, String size);

  /// Label identifying the media offset of a transcript search result.
  ///
  /// In en, this message translates to:
  /// **'Transcript match at {offset}'**
  String transcriptMatchAt(String offset);

  /// Recording setup explanation emphasizing recording-first local behavior.
  ///
  /// In en, this message translates to:
  /// **'Choose how this meeting will be processed. Audio is always saved locally first.'**
  String get newRecordingIntro;

  /// Heading for live-versus-post-session transcription choices.
  ///
  /// In en, this message translates to:
  /// **'Transcription timing'**
  String get transcriptionModeLabel;

  /// Choice requesting experimental draft transcription during capture.
  ///
  /// In en, this message translates to:
  /// **'Near-real-time draft'**
  String get nearRealTimeMode;

  /// Honest limitation text for near-real-time draft mode.
  ///
  /// In en, this message translates to:
  /// **'Experimental. It may pause or fall back to post-session processing to protect the recording.'**
  String get nearRealTimeModeDescription;

  /// Choice requesting transcription after capture ends.
  ///
  /// In en, this message translates to:
  /// **'After recording'**
  String get postSessionMode;

  /// Explanation for post-session transcription mode.
  ///
  /// In en, this message translates to:
  /// **'Keeps capture resources focused on saving audio, then analyzes the meeting locally.'**
  String get postSessionModeDescription;

  /// Heading for recognition-language choices.
  ///
  /// In en, this message translates to:
  /// **'Spoken language'**
  String get languageModeLabel;

  /// Chinese recognition-language choice.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageChinese;

  /// English recognition-language choice.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Mixed Chinese-English recognition-language choice.
  ///
  /// In en, this message translates to:
  /// **'Chinese + English'**
  String get languageMixed;

  /// Heading for optional two-to-six-speaker guidance.
  ///
  /// In en, this message translates to:
  /// **'Expected speakers'**
  String get speakerCountLabel;

  /// Choice that leaves speaker-count estimation automatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get speakerCountAutomatic;

  /// A selectable expected-speaker count.
  ///
  /// In en, this message translates to:
  /// **'{count}'**
  String speakerCountOption(int count);

  /// Runs required preflight and starts capture without another confirmation.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get startRecordingNowAction;

  /// Live status while local recording preflight and startup run.
  ///
  /// In en, this message translates to:
  /// **'Checking storage and microphone…'**
  String get recordingPreflightProgress;

  /// Safe local error shown when recording defaults cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Loquiris could not load the saved recording defaults.'**
  String get newRecordingLoadError;

  /// Safe retry message for persistence or native preflight failure.
  ///
  /// In en, this message translates to:
  /// **'Recording did not start. Check the message and try again; no existing audio was changed.'**
  String get newRecordingStartFailed;

  /// Actionable guidance after Android refuses the recording microphone permission.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is required to record. If Android does not show the permission prompt again, enable Microphone for Loquiris in Settings.'**
  String get recordingMicrophonePermissionDenied;

  /// Measured and required local space after recording preflight is refused.
  ///
  /// In en, this message translates to:
  /// **'{available} available · {required} required'**
  String recordingStoragePreflightFailed(String available, String required);

  /// Required local space when Android could not report free bytes.
  ///
  /// In en, this message translates to:
  /// **'At least {required} is required; available space could not be measured.'**
  String recordingStorageRequired(String required);

  /// Non-retryable message after an ambiguous accepted native start command.
  ///
  /// In en, this message translates to:
  /// **'Android has not confirmed whether recording started. Do not start again; check the recording notification or reopen Loquiris.'**
  String get recordingStartOutcomeUnknown;

  /// Non-retryable message when guarded zero-audio setup cleanup is refused.
  ///
  /// In en, this message translates to:
  /// **'Loquiris could not prove that this setup is safe to replace. Reopen the app before trying again.'**
  String get recordingSetupCleanupFailed;

  /// Privacy reminder on the recording setup screen.
  ///
  /// In en, this message translates to:
  /// **'No audio or setup choice leaves this device unless you explicitly export it.'**
  String get newRecordingOfflineNote;

  /// Accessible label for the pause-aware recording timer.
  ///
  /// In en, this message translates to:
  /// **'Recorded time {time}'**
  String recordingTimerSemantic(String time);

  /// Current durable recording file size.
  ///
  /// In en, this message translates to:
  /// **'Recorded audio size {size}'**
  String recordingSizeLabel(String size);

  /// No description provided for @recordingStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Recording now'**
  String get recordingStatusActive;

  /// No description provided for @recordingStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Recording paused'**
  String get recordingStatusPaused;

  /// No description provided for @recordingStatusInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Input interrupted — resume when it is safe'**
  String get recordingStatusInterrupted;

  /// No description provided for @recordingStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing recorder'**
  String get recordingStatusPreparing;

  /// No description provided for @recordingStatusSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving recording safely'**
  String get recordingStatusSaving;

  /// No description provided for @recordingStatusSaved.
  ///
  /// In en, this message translates to:
  /// **'Recording saved'**
  String get recordingStatusSaved;

  /// No description provided for @recordingStatusNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Recording needs review'**
  String get recordingStatusNeedsReview;

  /// No description provided for @recordingStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No active recording'**
  String get recordingStatusUnavailable;

  /// No description provided for @recordingInputActive.
  ///
  /// In en, this message translates to:
  /// **'Microphone input active'**
  String get recordingInputActive;

  /// No description provided for @recordingInputChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking microphone input'**
  String get recordingInputChecking;

  /// No description provided for @recordingInputReceived.
  ///
  /// In en, this message translates to:
  /// **'Microphone data received'**
  String get recordingInputReceived;

  /// No description provided for @recordingInputNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Microphone input needs attention'**
  String get recordingInputNeedsAttention;

  /// No description provided for @recordingInputUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Microphone input unavailable'**
  String get recordingInputUnavailable;

  /// No description provided for @recordingInputPaused.
  ///
  /// In en, this message translates to:
  /// **'Microphone input paused'**
  String get recordingInputPaused;

  /// No description provided for @pauseRecordingAction.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseRecordingAction;

  /// No description provided for @resumeRecordingAction.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeRecordingAction;

  /// No description provided for @stopRecordingAction.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopRecordingAction;

  /// No description provided for @addBookmarkAction.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get addBookmarkAction;

  /// No description provided for @addHighlightAction.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get addHighlightAction;

  /// No description provided for @confirmStopRecordingTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop and save this recording?'**
  String get confirmStopRecordingTitle;

  /// No description provided for @confirmStopRecordingBody.
  ///
  /// In en, this message translates to:
  /// **'Loquiris will finish writing the audio already recorded on this device.'**
  String get confirmStopRecordingBody;

  /// No description provided for @confirmStopRecordingAction.
  ///
  /// In en, this message translates to:
  /// **'Stop and save'**
  String get confirmStopRecordingAction;

  /// No description provided for @bookmarkAddedMessage.
  ///
  /// In en, this message translates to:
  /// **'Bookmark saved'**
  String get bookmarkAddedMessage;

  /// No description provided for @highlightAddedMessage.
  ///
  /// In en, this message translates to:
  /// **'Highlight saved'**
  String get highlightAddedMessage;

  /// No description provided for @markerAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save that marker. Recording continues.'**
  String get markerAddFailed;

  /// No description provided for @recordingMetadataSaveWarning.
  ///
  /// In en, this message translates to:
  /// **'Recording continues, but local meeting details could not be updated yet.'**
  String get recordingMetadataSaveWarning;

  /// No description provided for @recordingControlFailed.
  ///
  /// In en, this message translates to:
  /// **'That recording control did not complete. The saved audio is unchanged.'**
  String get recordingControlFailed;

  /// No description provided for @recordingStateLoading.
  ///
  /// In en, this message translates to:
  /// **'Reading recorder state'**
  String get recordingStateLoading;

  /// No description provided for @recordingStateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This meeting is not the active recording. The microphone was not started.'**
  String get recordingStateUnavailable;

  /// No description provided for @sessionDetailLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Loquiris could not read this meeting from local storage.'**
  String get sessionDetailLoadFailed;

  /// No description provided for @sessionDetailMarkersTitle.
  ///
  /// In en, this message translates to:
  /// **'Markers'**
  String get sessionDetailMarkersTitle;

  /// No description provided for @sessionDetailNoMarkers.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks or highlights'**
  String get sessionDetailNoMarkers;

  /// No description provided for @sessionDetailHighlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get sessionDetailHighlight;

  /// No description provided for @sessionDetailBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get sessionDetailBookmark;

  /// No description provided for @sessionDetailSegmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio segments'**
  String get sessionDetailSegmentsTitle;

  /// No description provided for @sessionDetailNoSegments.
  ///
  /// In en, this message translates to:
  /// **'No committed audio segments'**
  String get sessionDetailNoSegments;

  /// No description provided for @sessionSegmentOpen.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get sessionSegmentOpen;

  /// No description provided for @sessionSegmentCommitted.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get sessionSegmentCommitted;

  /// No description provided for @sessionSegmentCorrupt.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get sessionSegmentCorrupt;

  /// No description provided for @sessionSegmentMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get sessionSegmentMissing;

  /// One committed audio segment in meeting order.
  ///
  /// In en, this message translates to:
  /// **'Audio segment {number}'**
  String sessionDetailSegment(int number);

  /// No description provided for @sessionDetailEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording timeline'**
  String get sessionDetailEventsTitle;

  /// No description provided for @sessionDetailNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No recording events'**
  String get sessionDetailNoEvents;

  /// No description provided for @sessionDetailProcessingTitle.
  ///
  /// In en, this message translates to:
  /// **'Local processing'**
  String get sessionDetailProcessingTitle;

  /// No description provided for @sessionDetailNoProcessing.
  ///
  /// In en, this message translates to:
  /// **'No local processing jobs'**
  String get sessionDetailNoProcessing;

  /// No description provided for @sessionJobTranscription.
  ///
  /// In en, this message translates to:
  /// **'Transcription'**
  String get sessionJobTranscription;

  /// No description provided for @sessionJobLanguageIdentification.
  ///
  /// In en, this message translates to:
  /// **'Language identification'**
  String get sessionJobLanguageIdentification;

  /// No description provided for @sessionJobSpeakerDiarization.
  ///
  /// In en, this message translates to:
  /// **'Speaker separation'**
  String get sessionJobSpeakerDiarization;

  /// No description provided for @sessionJobAudioMerge.
  ///
  /// In en, this message translates to:
  /// **'Audio preparation'**
  String get sessionJobAudioMerge;

  /// No description provided for @sessionJobWaveform.
  ///
  /// In en, this message translates to:
  /// **'Waveform preparation'**
  String get sessionJobWaveform;

  /// No description provided for @sessionDetailRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery notes'**
  String get sessionDetailRecoveryTitle;

  /// No description provided for @sessionDetailNoRecoveryIssues.
  ///
  /// In en, this message translates to:
  /// **'No recovery issues'**
  String get sessionDetailNoRecoveryIssues;

  /// Accessible current and total playback time.
  ///
  /// In en, this message translates to:
  /// **'{position} of {duration}'**
  String sessionDetailPlaybackPosition(String position, String duration);

  /// No description provided for @sessionDetailPause.
  ///
  /// In en, this message translates to:
  /// **'Pause playback'**
  String get sessionDetailPause;

  /// No description provided for @sessionDetailPlay.
  ///
  /// In en, this message translates to:
  /// **'Play recording'**
  String get sessionDetailPlay;

  /// No description provided for @sessionEventStarted.
  ///
  /// In en, this message translates to:
  /// **'Recording started'**
  String get sessionEventStarted;

  /// No description provided for @sessionEventPaused.
  ///
  /// In en, this message translates to:
  /// **'Recording paused'**
  String get sessionEventPaused;

  /// No description provided for @sessionEventResumed.
  ///
  /// In en, this message translates to:
  /// **'Recording resumed'**
  String get sessionEventResumed;

  /// No description provided for @sessionEventInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Recording interrupted'**
  String get sessionEventInterrupted;

  /// No description provided for @sessionEventStopped.
  ///
  /// In en, this message translates to:
  /// **'Recording stopped'**
  String get sessionEventStopped;

  /// No description provided for @sessionEventRecovered.
  ///
  /// In en, this message translates to:
  /// **'Recording recovered'**
  String get sessionEventRecovered;

  /// No description provided for @sessionProcessingQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get sessionProcessingQueued;

  /// Progress of one local processing job.
  ///
  /// In en, this message translates to:
  /// **'Processing {percent}%'**
  String sessionProcessingRunning(int percent);

  /// No description provided for @sessionProcessingPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get sessionProcessingPaused;

  /// No description provided for @sessionProcessingSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get sessionProcessingSucceeded;

  /// No description provided for @sessionAudioPreparationFailed.
  ///
  /// In en, this message translates to:
  /// **'Audio preparation failed. Original audio remains safe.'**
  String get sessionAudioPreparationFailed;

  /// No description provided for @sessionProcessingFailed.
  ///
  /// In en, this message translates to:
  /// **'Local processing failed. Original audio remains safe.'**
  String get sessionProcessingFailed;

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

  /// No description provided for @sessionRecoveryTailDiscarded.
  ///
  /// In en, this message translates to:
  /// **'An uncommitted audio tail was discarded during recovery.'**
  String get sessionRecoveryTailDiscarded;

  /// No description provided for @sessionRecoveryTimelineGap.
  ///
  /// In en, this message translates to:
  /// **'A gap was found in the recovered recording timeline.'**
  String get sessionRecoveryTimelineGap;

  /// No description provided for @sessionRecoverySegmentMissing.
  ///
  /// In en, this message translates to:
  /// **'A committed audio segment is missing.'**
  String get sessionRecoverySegmentMissing;

  /// No description provided for @sessionRecoverySegmentCorrupt.
  ///
  /// In en, this message translates to:
  /// **'A committed audio segment could not be validated.'**
  String get sessionRecoverySegmentCorrupt;

  /// No description provided for @sessionRecoveryUnknown.
  ///
  /// In en, this message translates to:
  /// **'The recording has a recovery note that needs review.'**
  String get sessionRecoveryUnknown;

  /// No description provided for @sessionPlaybackPreparing.
  ///
  /// In en, this message translates to:
  /// **'Playback audio is being prepared from saved segments.'**
  String get sessionPlaybackPreparing;

  /// No description provided for @sessionPlaybackUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Playback is unavailable. Meeting details and original saved audio are unchanged.'**
  String get sessionPlaybackUnavailable;

  /// No description provided for @transcriptEditorLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Loquiris could not read this transcript from local storage.'**
  String get transcriptEditorLoadFailed;

  /// No description provided for @transcriptEditorNoTranscript.
  ///
  /// In en, this message translates to:
  /// **'No transcript version is selected for this meeting.'**
  String get transcriptEditorNoTranscript;

  /// No description provided for @transcriptEditorReadOnly.
  ///
  /// In en, this message translates to:
  /// **'This draft is still active. You can review it now and edit it after recording and analysis finish.'**
  String get transcriptEditorReadOnly;

  /// No description provided for @transcriptEditorSegmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get transcriptEditorSegmentsTitle;

  /// No description provided for @transcriptEditorTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Transcript text'**
  String get transcriptEditorTextLabel;

  /// No description provided for @transcriptEditorSaveText.
  ///
  /// In en, this message translates to:
  /// **'Save text correction'**
  String get transcriptEditorSaveText;

  /// No description provided for @transcriptEditorLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Segment language'**
  String get transcriptEditorLanguageLabel;

  /// No description provided for @languageUncertain.
  ///
  /// In en, this message translates to:
  /// **'Uncertain'**
  String get languageUncertain;

  /// No description provided for @transcriptEditorSpeakersTitle.
  ///
  /// In en, this message translates to:
  /// **'Speakers'**
  String get transcriptEditorSpeakersTitle;

  /// No description provided for @transcriptEditorRenameSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Rename speaker'**
  String get transcriptEditorRenameSpeaker;

  /// No description provided for @transcriptEditorSpeakerName.
  ///
  /// In en, this message translates to:
  /// **'Speaker name'**
  String get transcriptEditorSpeakerName;

  /// No description provided for @transcriptEditorNoSpeaker.
  ///
  /// In en, this message translates to:
  /// **'No speaker label'**
  String get transcriptEditorNoSpeaker;

  /// No description provided for @transcriptEditorHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Revision history'**
  String get transcriptEditorHistoryTitle;

  /// No description provided for @transcriptEditorNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No human corrections yet'**
  String get transcriptEditorNoHistory;

  /// No description provided for @transcriptEditorSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'That correction could not be saved. The current transcript is unchanged.'**
  String get transcriptEditorSaveFailed;

  /// No description provided for @transcriptEditorRefreshAfterSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Correction saved, but the latest data could not be refreshed.'**
  String get transcriptEditorRefreshAfterSaveFailed;

  /// No description provided for @transcriptEditorRevisionText.
  ///
  /// In en, this message translates to:
  /// **'Text corrected'**
  String get transcriptEditorRevisionText;

  /// No description provided for @transcriptEditorRevisionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language corrected'**
  String get transcriptEditorRevisionLanguage;

  /// No description provided for @transcriptEditorRevisionSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker corrected'**
  String get transcriptEditorRevisionSpeaker;

  /// Privacy warning shown before opening the Android export destination picker.
  ///
  /// In en, this message translates to:
  /// **'This export may contain sensitive audio and text. Loquiris writes it only to the destination you choose next.'**
  String get exportPrivacyWarning;

  /// Heading above the list of local export formats.
  ///
  /// In en, this message translates to:
  /// **'Choose what to export'**
  String get exportChooseFormat;

  /// Label for exporting continuous M4A audio.
  ///
  /// In en, this message translates to:
  /// **'Continuous M4A'**
  String get exportAudioM4a;

  /// Description of continuous M4A export.
  ///
  /// In en, this message translates to:
  /// **'Rebuilds a playable audio file from committed recording data when needed.'**
  String get exportAudioM4aDescription;

  /// Label for exporting authoritative committed audio segments.
  ///
  /// In en, this message translates to:
  /// **'Recoverable audio segments'**
  String get exportAudioSegments;

  /// Description of committed audio segment export.
  ///
  /// In en, this message translates to:
  /// **'Packages the committed AAC segments in a ZIP for recovery or advanced use.'**
  String get exportAudioSegmentsDescription;

  /// Label for readable transcript text export.
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get exportPlainText;

  /// Description of readable transcript text export.
  ///
  /// In en, this message translates to:
  /// **'Timestamped corrected transcript text with speaker labels.'**
  String get exportPlainTextDescription;

  /// Label for SRT subtitle export.
  ///
  /// In en, this message translates to:
  /// **'SRT subtitles'**
  String get exportSrt;

  /// Description of SRT subtitle export.
  ///
  /// In en, this message translates to:
  /// **'Corrected transcript text with millisecond subtitle timestamps.'**
  String get exportSrtDescription;

  /// Label for structured meeting JSON export.
  ///
  /// In en, this message translates to:
  /// **'Structured JSON'**
  String get exportJson;

  /// Description of structured meeting JSON export.
  ///
  /// In en, this message translates to:
  /// **'Meeting metadata, transcript, corrections, labels, and model provenance.'**
  String get exportJsonDescription;

  /// Label for a complete local meeting archive.
  ///
  /// In en, this message translates to:
  /// **'Complete ZIP package'**
  String get exportArchive;

  /// Description of the complete ZIP meeting export and its audio fallback.
  ///
  /// In en, this message translates to:
  /// **'Audio and available text files. If M4A rebuild fails, committed segments are included with a warning.'**
  String get exportArchiveDescription;

  /// Button that opens the Android user-selected export destination.
  ///
  /// In en, this message translates to:
  /// **'Choose destination and export'**
  String get exportConfirm;

  /// Status while a local export is being written.
  ///
  /// In en, this message translates to:
  /// **'Exporting locally…'**
  String get exportingLabel;

  /// Status while Android is waiting for the user to choose an export destination.
  ///
  /// In en, this message translates to:
  /// **'Choosing export destination…'**
  String get exportSelectingDestinationLabel;

  /// Status while export bytes are being written to the selected destination.
  ///
  /// In en, this message translates to:
  /// **'Writing export…'**
  String get exportWritingLabel;

  /// Status while an export destination is being closed and finalized.
  ///
  /// In en, this message translates to:
  /// **'Finalizing export…'**
  String get exportFinalizingLabel;

  /// Action to cooperatively cancel a safe active export write.
  ///
  /// In en, this message translates to:
  /// **'Cancel export'**
  String get exportCancelAction;

  /// Status while an export cancellation request is active.
  ///
  /// In en, this message translates to:
  /// **'Cancelling…'**
  String get exportCancellingLabel;

  /// Status after a local export completes.
  ///
  /// In en, this message translates to:
  /// **'Exported {fileName}'**
  String exportSucceeded(String fileName);

  /// Disclosure after a package uses committed audio segments instead of continuous M4A.
  ///
  /// In en, this message translates to:
  /// **'Continuous audio was unavailable, so the package contains recoverable segments.'**
  String get exportSegmentsFallbackWarning;

  /// Disclosure that a local audio export contains only verified committed prefixes from a partial recording.
  ///
  /// In en, this message translates to:
  /// **'This recording is partial. The export contains only the audio Loquiris verified as safely committed.'**
  String get exportPartialAudioWarning;

  /// Status after the user dismisses the Android destination picker.
  ///
  /// In en, this message translates to:
  /// **'Export cancelled. Nothing was sent anywhere.'**
  String get exportCancelled;

  /// Generic local export failure message.
  ///
  /// In en, this message translates to:
  /// **'Export could not be completed. The original meeting is unchanged.'**
  String get exportFailed;

  /// Warning when a document provider refuses cleanup of an incomplete export.
  ///
  /// In en, this message translates to:
  /// **'Export stopped, but Android could not remove the incomplete file. Check the destination you selected.'**
  String get exportIncompleteOutputWarning;

  /// Warning restored from durable history after an export process was interrupted.
  ///
  /// In en, this message translates to:
  /// **'A previous export was interrupted. An incomplete file may remain in the destination you selected.'**
  String get exportInterruptedOutputWarning;

  /// Warning when durable export-attempt persistence fails.
  ///
  /// In en, this message translates to:
  /// **'The export result could not be recorded locally. Check the destination you selected before trying again.'**
  String get exportPersistenceWarning;

  /// Meeting title marker applied when restore keeps a conflicting local meeting and imports the backup as a new copy.
  ///
  /// In en, this message translates to:
  /// **'{title} — Restored copy'**
  String restoredCopyTitle(String title);

  /// Pause-free media range for one transcript segment.
  ///
  /// In en, this message translates to:
  /// **'{start}–{end}'**
  String transcriptEditorSegmentTime(String start, String end);

  /// Storage category for the installed app, private support data, and bundled or installed models.
  ///
  /// In en, this message translates to:
  /// **'Application and models'**
  String get storageApplicationAndModels;

  /// Storage category for audio committed to meetings outside trash.
  ///
  /// In en, this message translates to:
  /// **'Active meetings'**
  String get storageActiveMeetings;

  /// Storage category for temporary data the app can recreate.
  ///
  /// In en, this message translates to:
  /// **'Rebuildable cache'**
  String get storageRebuildableCache;

  /// Storage category for audio committed to meetings in local trash.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get storageTrash;

  /// Storage category for space Android reports as available to this app.
  ///
  /// In en, this message translates to:
  /// **'Available device space'**
  String get storageAvailableDeviceSpace;

  /// Explains the two authoritative sources used by the storage screen.
  ///
  /// In en, this message translates to:
  /// **'These totals stay on this device. Meeting sizes come from Loquiris records; application, cache, and available space come from Android.'**
  String get storageAccountingIntro;

  /// Explains that the model detail is already included in the application category.
  ///
  /// In en, this message translates to:
  /// **'Includes {size} of bundled model files. Bundled models cannot be removed individually in this release; other private support data is grouped here.'**
  String storageApplicationModelsDetail(String size);

  /// No description provided for @storageActiveMeetingsDetail.
  ///
  /// In en, this message translates to:
  /// **'Committed audio for meetings outside Trash.'**
  String get storageActiveMeetingsDetail;

  /// No description provided for @storageRebuildableCacheDetail.
  ///
  /// In en, this message translates to:
  /// **'Temporary data Loquiris can recreate when needed.'**
  String get storageRebuildableCacheDetail;

  /// No description provided for @storageTrashDetail.
  ///
  /// In en, this message translates to:
  /// **'Committed audio retained until you permanently delete it.'**
  String get storageTrashDetail;

  /// No description provided for @storageAvailableDeviceSpaceDetail.
  ///
  /// In en, this message translates to:
  /// **'Space Android currently reports as available to Loquiris.'**
  String get storageAvailableDeviceSpaceDetail;

  /// No description provided for @storageLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Measuring storage on this device'**
  String get storageLoadingLabel;

  /// Privacy-safe retryable failure for storage accounting.
  ///
  /// In en, this message translates to:
  /// **'Loquiris could not measure storage right now. Your local data is unchanged.'**
  String get storageLoadError;

  /// No description provided for @clearRebuildableCacheAction.
  ///
  /// In en, this message translates to:
  /// **'Clear rebuildable cache'**
  String get clearRebuildableCacheAction;

  /// No description provided for @clearRebuildableCacheDescription.
  ///
  /// In en, this message translates to:
  /// **'Removes only allowlisted PCM, waveform, search-index, and failed-job temporary files. Meetings, edits, backups, Trash, and unknown cache remain unchanged.'**
  String get clearRebuildableCacheDescription;

  /// No description provided for @clearingRebuildableCacheLabel.
  ///
  /// In en, this message translates to:
  /// **'Clearing rebuildable cache…'**
  String get clearingRebuildableCacheLabel;

  /// Success after explicit allowlisted cache cleanup.
  ///
  /// In en, this message translates to:
  /// **'Cleared {size} from {count} files.'**
  String rebuildableCacheCleared(String size, int count);

  /// No description provided for @rebuildableCacheNothingCleared.
  ///
  /// In en, this message translates to:
  /// **'No allowlisted rebuildable cache needed clearing.'**
  String get rebuildableCacheNothingCleared;

  /// No description provided for @rebuildableCacheCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'Cache cleanup could not finish. Try again. Meeting data is unchanged.'**
  String get rebuildableCacheCleanupFailed;

  /// Retryable cleanup failure after some derived bytes were already removed.
  ///
  /// In en, this message translates to:
  /// **'Cleanup stopped after clearing {size}. Try again. Meeting data is unchanged.'**
  String rebuildableCacheCleanupPartiallyFailed(String size);

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
