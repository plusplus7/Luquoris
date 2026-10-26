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
  String get saveRecoveredRecordingAction => 'Save recovered recording';

  @override
  String get continueRecordingAction => 'Continue recording';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get recoveryActionFailed =>
      'Loquiris could not apply that recovery choice. Your saved audio is unchanged.';

  @override
  String get sessionsLoadingLabel => 'Loading meetings';

  @override
  String get sessionsSearchHint => 'Search meetings';

  @override
  String get meetingsLibraryTab => 'Library';

  @override
  String get trashTab => 'Trash';

  @override
  String get meetingActionsTooltip => 'Meeting actions';

  @override
  String get renameMeetingAction => 'Rename';

  @override
  String get moveToTrashAction => 'Move to trash';

  @override
  String get restoreMeetingAction => 'Restore';

  @override
  String get saveAction => 'Save';

  @override
  String get meetingTitleLabel => 'Meeting title';

  @override
  String get trashEmptyTitle => 'Trash is empty';

  @override
  String get trashEmptyBody =>
      'Deleted meetings stay here until you permanently remove them.';

  @override
  String get trashRetentionNotice =>
      'Seven-day local trash. Nothing is deleted automatically; restore or permanently delete items yourself.';

  @override
  String get permanentDeleteMeetingAction => 'Delete permanently';

  @override
  String get retryPermanentDeleteAction => 'Retry permanent deletion';

  @override
  String get permanentDeleteTitle => 'Permanently delete this meeting?';

  @override
  String get permanentDeleteBody =>
      'This removes private audio, transcript, revisions, bookmarks, and meeting metadata from this device. Loquiris cannot delete copies you exported or backed up elsewhere.';

  @override
  String get permanentDeletePending => 'Deleting private meeting data…';

  @override
  String get permanentDeleteFailed =>
      'Deletion did not finish. Your meeting remains locked for a safe retry.';

  @override
  String get searchEmptyTitle => 'No local matches';

  @override
  String get searchEmptyBody =>
      'Try a meeting title or words from the transcript.';

  @override
  String get meetingStatusDraft => 'Draft';

  @override
  String get meetingStatusPreparing => 'Preparing';

  @override
  String get meetingStatusRecording => 'Recording';

  @override
  String get meetingStatusPaused => 'Paused';

  @override
  String get meetingStatusStopping => 'Saving';

  @override
  String get meetingStatusFinished => 'Finished';

  @override
  String get meetingStatusRecoverable => 'Needs review';

  @override
  String get meetingStatusFailed => 'Save incomplete';

  @override
  String get meetingStatusTrashed => 'In trash';

  @override
  String get meetingStatusDeleting => 'Deleting';

  @override
  String meetingDefaultTitle(String date, String time) {
    return 'Meeting $date $time';
  }

  @override
  String meetingMetadata(String date, String duration, String size) {
    return '$date · $duration · $size';
  }

  @override
  String transcriptMatchAt(String offset) {
    return 'Transcript match at $offset';
  }

  @override
  String get newRecordingIntro =>
      'Choose how this meeting will be processed. Audio is always saved locally first.';

  @override
  String get transcriptionModeLabel => 'Transcription timing';

  @override
  String get nearRealTimeMode => 'Near-real-time draft';

  @override
  String get nearRealTimeModeDescription =>
      'Experimental. It may pause or fall back to post-session processing to protect the recording.';

  @override
  String get postSessionMode => 'After recording';

  @override
  String get postSessionModeDescription =>
      'Keeps capture resources focused on saving audio, then analyzes the meeting locally.';

  @override
  String get languageModeLabel => 'Spoken language';

  @override
  String get languageChinese => 'Chinese';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageMixed => 'Chinese + English';

  @override
  String get speakerCountLabel => 'Expected speakers';

  @override
  String get speakerCountAutomatic => 'Automatic';

  @override
  String speakerCountOption(int count) {
    return '$count';
  }

  @override
  String get startRecordingNowAction => 'Start recording';

  @override
  String get recordingPreflightProgress => 'Checking storage and microphone…';

  @override
  String get newRecordingLoadError =>
      'Loquiris could not load the saved recording defaults.';

  @override
  String get newRecordingStartFailed =>
      'Recording did not start. Check the message and try again; no existing audio was changed.';

  @override
  String get recordingMicrophonePermissionDenied =>
      'Microphone access is required to record. If Android does not show the permission prompt again, enable Microphone for Loquiris in Settings.';

  @override
  String recordingStoragePreflightFailed(String available, String required) {
    return '$available available · $required required';
  }

  @override
  String recordingStorageRequired(String required) {
    return 'At least $required is required; available space could not be measured.';
  }

  @override
  String get recordingStartOutcomeUnknown =>
      'Android has not confirmed whether recording started. Do not start again; check the recording notification or reopen Loquiris.';

  @override
  String get recordingSetupCleanupFailed =>
      'Loquiris could not prove that this setup is safe to replace. Reopen the app before trying again.';

  @override
  String get newRecordingOfflineNote =>
      'No audio or setup choice leaves this device unless you explicitly export it.';

  @override
  String recordingTimerSemantic(String time) {
    return 'Recorded time $time';
  }

  @override
  String recordingSizeLabel(String size) {
    return 'Recorded audio size $size';
  }

  @override
  String get recordingStatusActive => 'Recording now';

  @override
  String get recordingStatusPaused => 'Recording paused';

  @override
  String get recordingStatusInterrupted =>
      'Input interrupted — resume when it is safe';

  @override
  String get recordingStatusPreparing => 'Preparing recorder';

  @override
  String get recordingStatusSaving => 'Saving recording safely';

  @override
  String get recordingStatusSaved => 'Recording saved';

  @override
  String get recordingStatusNeedsReview => 'Recording needs review';

  @override
  String get recordingStatusUnavailable => 'No active recording';

  @override
  String get recordingInputActive => 'Microphone input active';

  @override
  String get recordingInputChecking => 'Checking microphone input';

  @override
  String get recordingInputReceived => 'Microphone data received';

  @override
  String get recordingInputNeedsAttention => 'Microphone input needs attention';

  @override
  String get recordingInputUnavailable => 'Microphone input unavailable';

  @override
  String get recordingInputPaused => 'Microphone input paused';

  @override
  String get pauseRecordingAction => 'Pause';

  @override
  String get resumeRecordingAction => 'Resume';

  @override
  String get stopRecordingAction => 'Stop';

  @override
  String get addBookmarkAction => 'Bookmark';

  @override
  String get addHighlightAction => 'Highlight';

  @override
  String get confirmStopRecordingTitle => 'Stop and save this recording?';

  @override
  String get confirmStopRecordingBody =>
      'Loquiris will finish writing the audio already recorded on this device.';

  @override
  String get confirmStopRecordingAction => 'Stop and save';

  @override
  String get bookmarkAddedMessage => 'Bookmark saved';

  @override
  String get highlightAddedMessage => 'Highlight saved';

  @override
  String get markerAddFailed =>
      'Could not save that marker. Recording continues.';

  @override
  String get recordingMetadataSaveWarning =>
      'Local meeting details could not be updated yet.';

  @override
  String get recordingControlFailed =>
      'That recording control did not complete. The saved audio is unchanged.';

  @override
  String get recordingStateLoading => 'Reading recorder state';

  @override
  String get recordingStateUnavailable =>
      'This meeting is not the active recording. The microphone was not started.';

  @override
  String get sessionDetailLoadFailed =>
      'Loquiris could not read this meeting from local storage.';

  @override
  String get sessionDetailMarkersTitle => 'Markers';

  @override
  String get sessionDetailNoMarkers => 'No bookmarks or highlights';

  @override
  String get sessionDetailHighlight => 'Highlight';

  @override
  String get sessionDetailBookmark => 'Bookmark';

  @override
  String get sessionDetailSegmentsTitle => 'Audio segments';

  @override
  String get sessionDetailNoSegments => 'No committed audio segments';

  @override
  String get sessionSegmentOpen => 'Recording';

  @override
  String get sessionSegmentCommitted => 'Saved';

  @override
  String get sessionSegmentCorrupt => 'Needs review';

  @override
  String get sessionSegmentMissing => 'Missing';

  @override
  String sessionDetailSegment(int number) {
    return 'Audio segment $number';
  }

  @override
  String get sessionDetailEventsTitle => 'Recording timeline';

  @override
  String get sessionDetailNoEvents => 'No recording events';

  @override
  String get sessionDetailProcessingTitle => 'Local processing';

  @override
  String get sessionDetailNoProcessing => 'No local processing jobs';

  @override
  String get sessionJobTranscription => 'Transcription';

  @override
  String get sessionJobLanguageIdentification => 'Language identification';

  @override
  String get sessionJobSpeakerDiarization => 'Speaker separation';

  @override
  String get sessionJobAudioMerge => 'Audio preparation';

  @override
  String get sessionJobWaveform => 'Waveform preparation';

  @override
  String get sessionDetailRecoveryTitle => 'Recovery notes';

  @override
  String get sessionDetailNoRecoveryIssues => 'No recovery issues';

  @override
  String sessionDetailPlaybackPosition(String position, String duration) {
    return '$position of $duration';
  }

  @override
  String get sessionDetailPause => 'Pause playback';

  @override
  String get sessionDetailPlay => 'Play recording';

  @override
  String get sessionEventStarted => 'Recording started';

  @override
  String get sessionEventPaused => 'Recording paused';

  @override
  String get sessionEventResumed => 'Recording resumed';

  @override
  String get sessionEventInterrupted => 'Recording interrupted';

  @override
  String get sessionEventStopped => 'Recording stopped';

  @override
  String get sessionEventRecovered => 'Recording recovered';

  @override
  String get sessionProcessingQueued => 'Waiting';

  @override
  String sessionProcessingRunning(int percent) {
    return 'Processing $percent%';
  }

  @override
  String get sessionProcessingPaused => 'Paused';

  @override
  String get sessionProcessingSucceeded => 'Completed';

  @override
  String get sessionAudioPreparationFailed =>
      'Audio preparation failed. Original audio remains safe.';

  @override
  String get sessionProcessingFailed =>
      'Local processing failed. Original audio remains safe.';

  @override
  String get transcriptionPreparingModel => 'Preparing the offline model';

  @override
  String get transcriptionDecodingAudio => 'Decoding saved audio';

  @override
  String transcriptionProgress(int percent) {
    return 'Transcribing locally $percent%';
  }

  @override
  String get transcriptionDelayed =>
      'Transcription is delayed. Your recording is safe and processing will resume locally.';

  @override
  String get transcriptionIncomplete =>
      'The transcript is incomplete. Your recording is safe and you can try again.';

  @override
  String get transcriptionRetryAction => 'Retry transcription';

  @override
  String get transcriptionRetrying => 'Retrying transcription…';

  @override
  String get transcriptionCancelled =>
      'Transcription was cancelled. Your recording is safe.';

  @override
  String get transcriptionCompleted => 'Transcription completed';

  @override
  String get transcriptionFailureModel =>
      'The bundled transcription model could not be verified. Your recording is safe.';

  @override
  String get transcriptionFailureEngine =>
      'The offline transcription engine could not finish. Your recording is safe.';

  @override
  String get transcriptionFailureStorage =>
      'Transcription progress could not be saved locally. Your recording is safe.';

  @override
  String get transcriptionFailureUnknown =>
      'Transcription could not finish. Your recording is safe.';

  @override
  String get transcriptionRetryFailed =>
      'Transcription could not be restarted. You can try again.';

  @override
  String get transcriptPreviewTitle => 'Transcript preview';

  @override
  String get transcriptPreviewEmpty =>
      'The completed transcript contains no stable text.';

  @override
  String get sessionRecoveryTailDiscarded =>
      'An uncommitted audio tail was discarded during recovery.';

  @override
  String get sessionRecoveryTimelineGap =>
      'A gap was found in the recovered recording timeline.';

  @override
  String get sessionRecoverySegmentMissing =>
      'A committed audio segment is missing.';

  @override
  String get sessionRecoverySegmentCorrupt =>
      'A committed audio segment could not be validated.';

  @override
  String get sessionRecoveryUnknown =>
      'The recording has a recovery note that needs review.';

  @override
  String get sessionPlaybackPreparing =>
      'Playback audio is being prepared from saved segments.';

  @override
  String get sessionPlaybackUnavailable =>
      'Playback is unavailable. Meeting details and original saved audio are unchanged.';

  @override
  String get transcriptEditorLoadFailed =>
      'Loquiris could not read this transcript from local storage.';

  @override
  String get transcriptEditorNoTranscript =>
      'No transcript version is selected for this meeting.';

  @override
  String get transcriptEditorReadOnly =>
      'This draft is still active. You can review it now and edit it after recording and analysis finish.';

  @override
  String get transcriptEditorSegmentsTitle => 'Transcript';

  @override
  String get transcriptEditorTextLabel => 'Transcript text';

  @override
  String get transcriptEditorSaveText => 'Save text correction';

  @override
  String get transcriptEditorLanguageLabel => 'Segment language';

  @override
  String get languageUncertain => 'Uncertain';

  @override
  String get transcriptEditorSpeakersTitle => 'Speakers';

  @override
  String get transcriptEditorRenameSpeaker => 'Rename speaker';

  @override
  String get transcriptEditorSpeakerName => 'Speaker name';

  @override
  String get transcriptEditorNoSpeaker => 'No speaker label';

  @override
  String get transcriptEditorHistoryTitle => 'Revision history';

  @override
  String get transcriptEditorNoHistory => 'No human corrections yet';

  @override
  String get transcriptEditorSaveFailed =>
      'That correction could not be saved. The current transcript is unchanged.';

  @override
  String get transcriptEditorRefreshAfterSaveFailed =>
      'Correction saved, but the latest data could not be refreshed.';

  @override
  String get transcriptEditorRevisionText => 'Text corrected';

  @override
  String get transcriptEditorRevisionLanguage => 'Language corrected';

  @override
  String get transcriptEditorRevisionSpeaker => 'Speaker corrected';

  @override
  String get exportPrivacyWarning =>
      'This export may contain sensitive audio and text. Loquiris writes it only to the destination you choose next.';

  @override
  String get exportChooseFormat => 'Choose what to export';

  @override
  String get exportAudioM4a => 'Continuous M4A';

  @override
  String get exportAudioM4aDescription =>
      'Rebuilds a playable audio file from committed recording data when needed.';

  @override
  String get exportAudioSegments => 'Recoverable audio segments';

  @override
  String get exportAudioSegmentsDescription =>
      'Packages the committed AAC segments in a ZIP for recovery or advanced use.';

  @override
  String get exportPlainText => 'Plain text';

  @override
  String get exportPlainTextDescription =>
      'Timestamped corrected transcript text with speaker labels.';

  @override
  String get exportSrt => 'SRT subtitles';

  @override
  String get exportSrtDescription =>
      'Corrected transcript text with millisecond subtitle timestamps.';

  @override
  String get exportJson => 'Structured JSON';

  @override
  String get exportJsonDescription =>
      'Meeting metadata, transcript, corrections, labels, and model provenance.';

  @override
  String get exportArchive => 'Complete ZIP package';

  @override
  String get exportArchiveDescription =>
      'Audio and available text files. If M4A rebuild fails, committed segments are included with a warning.';

  @override
  String get exportConfirm => 'Choose destination and export';

  @override
  String get exportingLabel => 'Exporting locally…';

  @override
  String get exportSelectingDestinationLabel => 'Choosing export destination…';

  @override
  String get exportWritingLabel => 'Writing export…';

  @override
  String get exportFinalizingLabel => 'Finalizing export…';

  @override
  String get exportCancelAction => 'Cancel export';

  @override
  String get exportCancellingLabel => 'Cancelling…';

  @override
  String exportSucceeded(String fileName) {
    return 'Exported $fileName';
  }

  @override
  String get exportSegmentsFallbackWarning =>
      'Continuous audio was unavailable, so the package contains recoverable segments.';

  @override
  String get exportPartialAudioWarning =>
      'This recording is partial. The export contains only the audio Loquiris verified as safely committed.';

  @override
  String get exportCancelled => 'Export cancelled. Nothing was sent anywhere.';

  @override
  String get exportFailed =>
      'Export could not be completed. The original meeting is unchanged.';

  @override
  String get exportTranscriptSelectionRequired =>
      'Choose a transcript version before exporting text or subtitles.';

  @override
  String get exportTranscriptChanged =>
      'The selected transcript changed while preparing export. Try again.';

  @override
  String get exportIncompleteOutputWarning =>
      'Export stopped, but Android could not remove the incomplete file. Check the destination you selected.';

  @override
  String get exportInterruptedOutputWarning =>
      'A previous export was interrupted. An incomplete file may remain in the destination you selected.';

  @override
  String get exportPersistenceWarning =>
      'The export result could not be recorded locally. Check the destination you selected before trying again.';

  @override
  String restoredCopyTitle(String title) {
    return '$title — Restored copy';
  }

  @override
  String transcriptEditorSegmentTime(String start, String end) {
    return '$start–$end';
  }

  @override
  String get storageApplicationAndModels => 'Application and models';

  @override
  String get storageActiveMeetings => 'Active meetings';

  @override
  String get storageRebuildableCache => 'Rebuildable cache';

  @override
  String get storageTrash => 'Trash';

  @override
  String get storageAvailableDeviceSpace => 'Available device space';

  @override
  String get storageAccountingIntro =>
      'These totals stay on this device. Meeting sizes come from Loquiris records; application, cache, and available space come from Android.';

  @override
  String storageApplicationModelsDetail(String size) {
    return 'Includes $size of bundled model files. Bundled models cannot be removed individually in this release; other private support data is grouped here.';
  }

  @override
  String get storageActiveMeetingsDetail =>
      'Committed audio for meetings outside Trash.';

  @override
  String get storageRebuildableCacheDetail =>
      'Temporary data Loquiris can recreate when needed.';

  @override
  String get storageTrashDetail =>
      'Committed audio retained until you permanently delete it.';

  @override
  String get storageAvailableDeviceSpaceDetail =>
      'Space Android currently reports as available to Loquiris.';

  @override
  String get storageLoadingLabel => 'Measuring storage on this device';

  @override
  String get storageLoadError =>
      'Loquiris could not measure storage right now. Your local data is unchanged.';

  @override
  String get clearRebuildableCacheAction => 'Clear rebuildable cache';

  @override
  String get clearRebuildableCacheDescription =>
      'Removes only allowlisted PCM, waveform, search-index, and failed-job temporary files. Meetings, edits, backups, Trash, and unknown cache remain unchanged.';

  @override
  String get clearingRebuildableCacheLabel => 'Clearing rebuildable cache…';

  @override
  String rebuildableCacheCleared(String size, int count) {
    return 'Cleared $size from $count files.';
  }

  @override
  String get rebuildableCacheNothingCleared =>
      'No allowlisted rebuildable cache needed clearing.';

  @override
  String get rebuildableCacheCleanupFailed =>
      'Cache cleanup could not finish. Try again. Meeting data is unchanged.';

  @override
  String rebuildableCacheCleanupPartiallyFailed(String size) {
    return 'Cleanup stopped after clearing $size. Try again. Meeting data is unchanged.';
  }

  @override
  String get benchmarkIntro =>
      'Run a short offline check to see which local processing mode this device can sustain.';

  @override
  String get benchmarkFixedAudioDisclosure =>
      'The check uses a bundled 45-second Mandarin and English audio sample. It never turns on the microphone, saves a recording, or changes settings.';

  @override
  String get performancePolicyHeading =>
      'Operating modes and recording protection';

  @override
  String get performancePolicyLockedBody =>
      'Modes remain informational until a compatible local inference runtime and model pass validation. This screen never changes settings automatically.';

  @override
  String get performancePolicyRecommendedLabel => 'Recommended by this check';

  @override
  String get performancePolicyTimingLiveOrPostSession =>
      'During recording or after recording';

  @override
  String get performancePolicyTimingPostSessionOnly => 'After recording only';

  @override
  String get performancePolicyTimingDisabled => 'AI processing off';

  @override
  String get performancePolicyHighQualityDescription =>
      'Uses a validated higher-quality model after recording.';

  @override
  String get performancePolicyHighQualityFallback =>
      'Falls back to balanced post-session processing, then recording only.';

  @override
  String get performancePolicyBalancedDescription =>
      'Balances transcript quality with device resources.';

  @override
  String get performancePolicyBalancedFallback =>
      'Reduces resource use, defers work, or keeps recording only.';

  @override
  String get performancePolicyPowerSavingDescription =>
      'Uses a smaller model or reduced concurrency when validated.';

  @override
  String get performancePolicyPowerSavingFallback =>
      'Defers work until after recording, then keeps recording only if needed.';

  @override
  String get performancePolicyPostSessionDescription =>
      'Reserves capture-time resources and analyzes locally after recording.';

  @override
  String get performancePolicyPostSessionFallback =>
      'Recording remains available if analysis cannot run.';

  @override
  String get performancePolicyRecordingOnlyDescription =>
      'Saves canonical audio without running AI.';

  @override
  String get performancePolicyRecordingOnlyFallback =>
      'Recording continues without an AI fallback.';

  @override
  String get performancePolicyProtectionHeading =>
      'How Loquiris protects recording';

  @override
  String get performancePolicyProtectionModerateThermal =>
      'Moderate heat reduces AI concurrency.';

  @override
  String get performancePolicyProtectionSevereThermal =>
      'Severe heat pauses AI while recording continues.';

  @override
  String get performancePolicyProtectionBacklog =>
      'Sustained backlog moves unfinished work to after recording.';

  @override
  String get performancePolicyProtectionRecordingFirst =>
      'Engine or resource failure never discards canonical recording audio.';

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

  @override
  String get benchmarkExportAction => 'Export report';

  @override
  String get benchmarkExportingAction => 'Exporting report…';

  @override
  String benchmarkExportSucceeded(String fileName) {
    return 'Saved $fileName.';
  }

  @override
  String get benchmarkExportCancelled => 'Export cancelled. No file was saved.';

  @override
  String get benchmarkExportFailed =>
      'Report could not be exported. Try again.';

  @override
  String get liveTranscriptTitle => 'Live transcript draft';

  @override
  String get liveTranscriptExperimentalLabel => 'Experimental · read only';

  @override
  String get liveTranscriptWaiting => 'Listening for the first local draft…';

  @override
  String get liveTranscriptStableLabel => 'Stable';

  @override
  String get liveTranscriptDraftLabel => 'Draft';

  @override
  String liveTranscriptStableSegment(String text) {
    return 'Stable. $text';
  }

  @override
  String liveTranscriptDraftSegment(String text) {
    return 'Draft. $text';
  }

  @override
  String liveTranscriptBacklog(int seconds) {
    return 'The live draft is about $seconds seconds behind.';
  }

  @override
  String get liveTranscriptIncomplete => 'This live draft may be incomplete.';

  @override
  String get liveTranscriptDiscontinuity =>
      'An audio interval is missing from this draft. Later live text can continue.';

  @override
  String get liveTranscriptThermalFallback =>
      'Live transcription paused because this device is too warm.';

  @override
  String get liveTranscriptModelFallback =>
      'The local model could not start live transcription.';

  @override
  String get liveTranscriptGenericFallback =>
      'Live transcription stopped safely.';

  @override
  String get liveTranscriptPostSessionFallback =>
      'A complete transcript will run after recording.';

  @override
  String get transcriptVersionsTitle => 'Transcript versions';

  @override
  String get transcriptVersionsHelp =>
      'Choose which version to read, search, play back, or export. Other versions and their human corrections are kept separately.';

  @override
  String get transcriptVersionsLoading => 'Loading transcript versions…';

  @override
  String get transcriptVersionsLoadFailed =>
      'Transcript versions could not be read. Try again.';

  @override
  String get transcriptVersionsEmpty =>
      'No transcript versions have been saved yet.';

  @override
  String get transcriptVersionSelectionFailed =>
      'The version could not be changed. Your current transcript is unchanged. Try again.';

  @override
  String get transcriptRefinementReady =>
      'A refined version is available. It will not replace your current transcript automatically.';

  @override
  String transcriptVersionRole(String role) {
    String _temp0 = intl.Intl.selectLogic(
      role,
      {
        'liveDraft': 'Live draft',
        'refinement': 'Refined transcript',
        'unverified': 'Unverified version',
        'other': 'Saved transcript',
      },
    );
    return '$_temp0';
  }

  @override
  String transcriptVersionIdentity(String role, DateTime date, DateTime time) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);
    final intl.DateFormat timeDateFormat = intl.DateFormat.Hms(localeName);
    final String timeString = timeDateFormat.format(time);

    return '$role · $dateString $timeString';
  }

  @override
  String transcriptVersionCoverage(String coverage) {
    String _temp0 = intl.Intl.selectLogic(
      coverage,
      {
        'complete': 'Complete coverage',
        'incomplete': 'Incomplete coverage',
        'other': 'Coverage not recorded',
      },
    );
    return '$_temp0';
  }

  @override
  String transcriptVersionProvenance(
    String model,
    String version,
    String engine,
    String engineVersion,
    String hash,
  ) {
    return 'Model: $model ($version)\nRuntime: $engine $engineVersion\nBundle SHA-256: $hash';
  }

  @override
  String get transcriptVersionUnverified =>
      'Version provenance could not be verified. Selection is unavailable.';

  @override
  String get transcriptVersionNotReady =>
      'This version is not ready to select.';

  @override
  String get transcriptVersionCurrent => 'Current version';

  @override
  String get transcriptVersionUse => 'Use this version';

  @override
  String transcriptVersionUseSemantic(String version) {
    return 'Use $version';
  }

  @override
  String get transcriptVersionSelecting => 'Switching version…';

  @override
  String get recordingOnlyChoice => 'Recording only';

  @override
  String get recordingOnlyChoiceDescription =>
      'Save the original audio without running transcription for this meeting.';

  @override
  String get twoPassChoice => 'Live draft + refinement';

  @override
  String get twoPassUnavailable =>
      'Unavailable until a streaming model pair passes the required checks. Choose post-session transcription or recording only.';

  @override
  String get recordingProcessingUnavailable =>
      'The transcription configuration could not be saved. Try again, or choose recording only. Recording has not started.';

  @override
  String get refinementResumeAction => 'Resume refinement';

  @override
  String get refinementResuming => 'Resuming refinement…';

  @override
  String refinementPausedMessage(String reasonCode) {
    String _temp0 = intl.Intl.selectLogic(
      reasonCode,
      {
        'refinement_thermal_severe':
            'Refinement is paused while this device cools down. Your recording is safe.',
        'refinement_battery_low':
            'Refinement is paused because the battery is low. Charge this device before resuming.',
        'refinement_memory_pressure':
            'Refinement is paused because memory is low. Close other apps before resuming.',
        'refinement_power_save':
            'Refinement is paused while battery saver is on. Turn it off before resuming.',
        'refinement_recording_active':
            'Refinement is paused to prioritize recording. Resume after recording stops.',
        'refinement_resources_unavailable':
            'Refinement is paused because device resources could not be checked. Try resuming later.',
        'other':
            'Refinement is paused. Your recording is safe. You can try resuming later.',
      },
    );
    return '$_temp0';
  }

  @override
  String get remoteTitle => 'Remote transcription';

  @override
  String get remoteExplanation =>
      'Audio stays on this phone. Choosing remote transcription uploads a copy to your configured server. The server reports its retention policy and expiry; local transcripts and edits remain.';

  @override
  String get remoteEndpoint => 'Server address';

  @override
  String get remoteToken => 'Server access token';

  @override
  String get remoteConfigure => 'Save connection';

  @override
  String get remoteStart => 'Start transcription';

  @override
  String get remoteCancel => 'Cancel remote task';

  @override
  String get remoteEdit => 'Edit this version';

  @override
  String get remoteSave => 'Save correction';

  @override
  String get remoteExportText => 'Export text';

  @override
  String get remoteExportJson => 'Export JSON';

  @override
  String get remoteExportSubtitles => 'Export original subtitles';

  @override
  String get remoteEmpty =>
      'Remote results will appear here after recording finishes.';

  @override
  String get remoteInputInvalid =>
      'Enter a valid HTTPS origin or private LAN HTTP IP, and an access token of at least 32 characters.';

  @override
  String remoteVersionSource(String model, String revision) {
    return 'Model: $model · Revision: $revision';
  }

  @override
  String remoteFailure(String code) {
    String _temp0 = intl.Intl.selectLogic(
      code,
      {
        'remote_authentication':
            'Server credentials were rejected. Configure the connection again.',
        'remote_credentials_missing':
            'Local credentials are unavailable. Configure the connection again.',
        'remote_transport':
            'Network unavailable. Check the connection and retry.',
        'remote_quota': 'Server storage quota exceeded.',
        'remote_expired':
            'The server copy expired. Start a new transcription from local audio.',
        'remote_model_failed':
            'Server inference failed. Check the server before starting a new run.',
        'remote_submission_pending': 'Recovering the submitted job identity.',
        'remote_restore_requires_action':
            'Restored work requires an explicit new request and connection setup.',
        'remote_audio_unavailable': 'Recording audio is unavailable.',
        'remote_audio_changed':
            'Recording audio differs from the queued request.',
        'other': 'Remote task needs attention: $code',
      },
    );
    return '$_temp0';
  }

  @override
  String remoteTaskProgress(int done, int total) {
    return '$done / $total bytes uploaded';
  }

  @override
  String remoteState(String state) {
    String _temp0 = intl.Intl.selectLogic(
      state,
      {
        'waitingSetup': 'Configure a server',
        'waitingAudio': 'Waiting for recording to finish',
        'uploading': 'Uploading',
        'submitting': 'Submitting',
        'waitingNetwork': 'Waiting to retry network',
        'queued': 'Queued on server',
        'running': 'Transcribing',
        'completed': 'Saved on phone',
        'failed': 'Failed — create a new run to retry',
        'cancelled': 'Cancelled',
        'restored': 'Restored — new authorization required',
        'expired': 'Remote result expired',
        'other': 'Waiting',
      },
    );
    return '$_temp0';
  }

  @override
  String get remotePostSessionDescription =>
      'Record reliably on this phone, then upload for server transcription. Works without a local model.';

  @override
  String get remoteRecordingNote =>
      'Recording works offline. Remote transcription waits for a configured server and network access.';

  @override
  String remoteRetention(int seconds) {
    return 'Server retention: $seconds seconds';
  }

  @override
  String remoteExpires(String deadline) {
    return 'Server copy expires: $deadline';
  }

  @override
  String get remoteModelPageNote =>
      'Remote transcription runs on your server and requires no phone model installation. This page tests local phone inference only; existing local transcripts remain readable.';

  @override
  String get remoteRestart => 'Transcribe again';

  @override
  String get remoteServerSettings => 'Transcription server';

  @override
  String get remoteAutomaticRecognition =>
      'Language is detected automatically. Transcription starts after recording ends.';

  @override
  String get remoteLanExplanation =>
      'Use a private LAN address such as http://192.168.1.20:18000. HTTP sends audio and the access token without encryption; use it only on your trusted network.';

  @override
  String get remoteConnectionSaved => 'Server connection saved';

  @override
  String get remoteChangeConnection => 'Change connection';

  @override
  String get remoteOpenSettings => 'Configure server';

  @override
  String get remoteResultTitle => 'Transcript';

  @override
  String get remoteExport => 'Export';

  @override
  String get remoteRecordingDetails => 'Recording details';

  @override
  String remoteVersionNumber(int number) {
    return 'Transcript $number';
  }

  @override
  String get remoteNoSpeech => 'No speech detected.';
}
