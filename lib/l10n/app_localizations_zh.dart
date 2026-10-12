// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Loquiris';

  @override
  String get appTagline => '离线会议录音';

  @override
  String get sessionsTitle => '会议';

  @override
  String get newRecordingTitle => '新建录音';

  @override
  String get activeRecordingTitle => '正在录音';

  @override
  String get sessionDetailTitle => '会议详情';

  @override
  String get transcriptEditorTitle => '编辑转写';

  @override
  String get exportTitle => '导出';

  @override
  String get modelsPerformanceTitle => '模型与性能';

  @override
  String get storagePrivacyTitle => '存储与隐私';

  @override
  String get notFoundTitle => '页面不存在';

  @override
  String get navMeetings => '会议';

  @override
  String get navRecord => '录音';

  @override
  String get navSettings => '设置';

  @override
  String get sessionsEmptyTitle => '还没有会议';

  @override
  String get sessionsEmptyBody => '录下一次谈话，内容将安全地留在此设备上。';

  @override
  String get startRecordingAction => '开始录音';

  @override
  String get sessionsLoadError => 'Loquiris 无法读取保存在此设备上的会议。';

  @override
  String get retryAction => '重试';

  @override
  String get recoveryTitle => '发现中断的录音';

  @override
  String get recoveryBody => '已保存的音频仍然完好。请先检查，再决定是否继续。';

  @override
  String get reviewRecordingAction => '检查录音';

  @override
  String get saveRecoveredRecordingAction => '保存已恢复的录音';

  @override
  String get continueRecordingAction => '继续录音';

  @override
  String get cancelAction => '取消';

  @override
  String get recoveryActionFailed => 'Loquiris 无法应用此恢复选择。已保存的音频没有改变。';

  @override
  String get sessionsLoadingLabel => '正在载入会议';

  @override
  String get sessionsSearchHint => '搜索会议';

  @override
  String get meetingsLibraryTab => '列表';

  @override
  String get trashTab => '回收站';

  @override
  String get meetingActionsTooltip => '会议操作';

  @override
  String get renameMeetingAction => '重命名';

  @override
  String get moveToTrashAction => '移到回收站';

  @override
  String get restoreMeetingAction => '恢复';

  @override
  String get saveAction => '保存';

  @override
  String get meetingTitleLabel => '会议标题';

  @override
  String get trashEmptyTitle => '回收站为空';

  @override
  String get trashEmptyBody => '删除的会议会保留在这里，直到你明确永久删除。';

  @override
  String get trashRetentionNotice => '本地七天回收站不会自动清空；请自行恢复或永久删除会议。';

  @override
  String get permanentDeleteMeetingAction => '永久删除';

  @override
  String get retryPermanentDeleteAction => '重试永久删除';

  @override
  String get permanentDeleteTitle => '永久删除此会议？';

  @override
  String get permanentDeleteBody =>
      '这会从本设备删除私有音频、转写、修订记录、书签和会议元数据。Loquiris 无法删除你已导出或备份到其他位置的副本。';

  @override
  String get permanentDeletePending => '正在删除私有会议数据…';

  @override
  String get permanentDeleteFailed => '删除未完成。会议保持锁定，可安全重试。';

  @override
  String get searchEmptyTitle => '没有本地匹配结果';

  @override
  String get searchEmptyBody => '可尝试搜索会议标题或转写中的文字。';

  @override
  String get meetingStatusDraft => '草稿';

  @override
  String get meetingStatusPreparing => '准备中';

  @override
  String get meetingStatusRecording => '录音中';

  @override
  String get meetingStatusPaused => '已暂停';

  @override
  String get meetingStatusStopping => '保存中';

  @override
  String get meetingStatusFinished => '已完成';

  @override
  String get meetingStatusRecoverable => '需要检查';

  @override
  String get meetingStatusFailed => '保存未完成';

  @override
  String get meetingStatusTrashed => '在回收站';

  @override
  String get meetingStatusDeleting => '正在删除';

  @override
  String meetingDefaultTitle(String date, String time) {
    return '会议 $date $time';
  }

  @override
  String meetingMetadata(String date, String duration, String size) {
    return '$date · $duration · $size';
  }

  @override
  String transcriptMatchAt(String offset) {
    return '转写匹配位置 $offset';
  }

  @override
  String get newRecordingIntro => '选择本次会议的处理方式。Loquiris 始终优先在本机保存录音。';

  @override
  String get transcriptionModeLabel => '转写时机';

  @override
  String get nearRealTimeMode => '近实时草稿';

  @override
  String get nearRealTimeModeDescription => '实验性能力。为保护录音，系统可能暂停实时处理或改为录音结束后处理。';

  @override
  String get postSessionMode => '录音结束后';

  @override
  String get postSessionModeDescription => '录音时优先使用资源安全保存音频，结束后再在本机分析。';

  @override
  String get languageModeLabel => '发言语言';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => '英文';

  @override
  String get languageMixed => '中文 + 英文';

  @override
  String get speakerCountLabel => '预计发言人数';

  @override
  String get speakerCountAutomatic => '自动判断';

  @override
  String speakerCountOption(int count) {
    return '$count';
  }

  @override
  String get startRecordingNowAction => '开始录音';

  @override
  String get recordingPreflightProgress => '正在检查存储空间和麦克风…';

  @override
  String get newRecordingLoadError => 'Loquiris 无法读取已保存的录音默认设置。';

  @override
  String get newRecordingStartFailed => '录音未能开始。请检查提示后重试；已有音频没有改变。';

  @override
  String get recordingMicrophonePermissionDenied =>
      '录音需要麦克风权限。如果 Android 未再次显示授权提示，请在系统设置中为 Loquiris 开启麦克风权限。';

  @override
  String recordingStoragePreflightFailed(String available, String required) {
    return '可用 $available · 安全开始需要 $required';
  }

  @override
  String recordingStorageRequired(String required) {
    return '安全开始至少需要 $required；系统未能读取可用空间。';
  }

  @override
  String get recordingStartOutcomeUnknown =>
      'Android 尚未确认录音是否已开始。请勿再次开始；请检查录音通知或重新打开 Loquiris。';

  @override
  String get recordingSetupCleanupFailed =>
      'Loquiris 无法确认此录音设置可被安全替换。请重新打开应用后再试。';

  @override
  String get newRecordingOfflineNote => '除非你明确导出，否则音频和设置都不会离开此设备。';

  @override
  String recordingTimerSemantic(String time) {
    return '已录制 $time';
  }

  @override
  String recordingSizeLabel(String size) {
    return '录音大小 $size';
  }

  @override
  String get recordingStatusActive => '正在录音';

  @override
  String get recordingStatusPaused => '录音已暂停';

  @override
  String get recordingStatusInterrupted => '输入被中断，请确认安全后继续';

  @override
  String get recordingStatusPreparing => '正在准备录音';

  @override
  String get recordingStatusSaving => '正在安全保存录音';

  @override
  String get recordingStatusSaved => '录音已保存';

  @override
  String get recordingStatusNeedsReview => '录音需要检查';

  @override
  String get recordingStatusUnavailable => '当前没有活动录音';

  @override
  String get recordingInputActive => '麦克风输入正常';

  @override
  String get recordingInputChecking => '正在检查麦克风输入';

  @override
  String get recordingInputReceived => '已接收到麦克风数据';

  @override
  String get recordingInputNeedsAttention => '麦克风输入需要检查';

  @override
  String get recordingInputUnavailable => '麦克风输入不可用';

  @override
  String get recordingInputPaused => '麦克风输入已暂停';

  @override
  String get pauseRecordingAction => '暂停';

  @override
  String get resumeRecordingAction => '继续';

  @override
  String get stopRecordingAction => '停止';

  @override
  String get addBookmarkAction => '书签';

  @override
  String get addHighlightAction => '重点';

  @override
  String get confirmStopRecordingTitle => '停止并保存这段录音？';

  @override
  String get confirmStopRecordingBody => 'Loquiris 将完成写入已保存在本机的音频。';

  @override
  String get confirmStopRecordingAction => '停止并保存';

  @override
  String get bookmarkAddedMessage => '书签已保存';

  @override
  String get highlightAddedMessage => '重点已保存';

  @override
  String get markerAddFailed => '无法保存此标记，录音仍在继续。';

  @override
  String get recordingMetadataSaveWarning => '录音仍在继续，但会议信息暂时无法写入本地数据库。';

  @override
  String get recordingControlFailed => '录音操作未完成，已保存的音频没有改变。';

  @override
  String get recordingStateLoading => '正在读取录音状态';

  @override
  String get recordingStateUnavailable => '此会议不是当前活动录音，麦克风没有被启动。';

  @override
  String get sessionDetailLoadFailed => 'Loquiris 无法从本地存储读取此会议。';

  @override
  String get sessionDetailMarkersTitle => '标记';

  @override
  String get sessionDetailNoMarkers => '没有书签或重点';

  @override
  String get sessionDetailHighlight => '重点';

  @override
  String get sessionDetailBookmark => '书签';

  @override
  String get sessionDetailSegmentsTitle => '音频分片';

  @override
  String get sessionDetailNoSegments => '没有已提交的音频分片';

  @override
  String get sessionSegmentOpen => '录制中';

  @override
  String get sessionSegmentCommitted => '已保存';

  @override
  String get sessionSegmentCorrupt => '需要检查';

  @override
  String get sessionSegmentMissing => '缺失';

  @override
  String sessionDetailSegment(int number) {
    return '音频分片 $number';
  }

  @override
  String get sessionDetailEventsTitle => '录音时间线';

  @override
  String get sessionDetailNoEvents => '没有录音事件';

  @override
  String get sessionDetailProcessingTitle => '本地处理';

  @override
  String get sessionDetailNoProcessing => '没有本地处理任务';

  @override
  String get sessionJobTranscription => '语音转写';

  @override
  String get sessionJobLanguageIdentification => '语言识别';

  @override
  String get sessionJobSpeakerDiarization => '说话人区分';

  @override
  String get sessionJobAudioMerge => '播放音频准备';

  @override
  String get sessionJobWaveform => '波形准备';

  @override
  String get sessionDetailRecoveryTitle => '恢复说明';

  @override
  String get sessionDetailNoRecoveryIssues => '没有恢复问题';

  @override
  String sessionDetailPlaybackPosition(String position, String duration) {
    return '$position / $duration';
  }

  @override
  String get sessionDetailPause => '暂停播放';

  @override
  String get sessionDetailPlay => '播放录音';

  @override
  String get sessionEventStarted => '录音已开始';

  @override
  String get sessionEventPaused => '录音已暂停';

  @override
  String get sessionEventResumed => '录音已继续';

  @override
  String get sessionEventInterrupted => '录音被中断';

  @override
  String get sessionEventStopped => '录音已停止';

  @override
  String get sessionEventRecovered => '录音已恢复';

  @override
  String get sessionProcessingQueued => '等待中';

  @override
  String sessionProcessingRunning(int percent) {
    return '处理中 $percent%';
  }

  @override
  String get sessionProcessingPaused => '已暂停';

  @override
  String get sessionProcessingSucceeded => '已完成';

  @override
  String get sessionAudioPreparationFailed => '播放音频准备失败，原始录音仍然安全。';

  @override
  String get sessionProcessingFailed => '本地处理失败，原始录音仍然安全。';

  @override
  String get transcriptionPreparingModel => '正在准备离线模型';

  @override
  String get transcriptionDecodingAudio => '正在解码已保存的音频';

  @override
  String transcriptionProgress(int percent) {
    return '正在本地转写 $percent%';
  }

  @override
  String get transcriptionDelayed => '转写有所延迟。录音仍然安全，处理会在本地继续。';

  @override
  String get transcriptionIncomplete => '转写内容不完整。录音仍然安全，你可以重试。';

  @override
  String get transcriptionRetryAction => '重试转写';

  @override
  String get transcriptionRetrying => '正在重试转写…';

  @override
  String get transcriptionCancelled => '转写已取消，录音仍然安全。';

  @override
  String get transcriptionCompleted => '转写已完成';

  @override
  String get transcriptionFailureModel => '无法验证内置转写模型，录音仍然安全。';

  @override
  String get transcriptionFailureEngine => '离线转写引擎未能完成处理，录音仍然安全。';

  @override
  String get transcriptionFailureStorage => '无法在本地保存转写进度，录音仍然安全。';

  @override
  String get transcriptionFailureUnknown => '转写未能完成，录音仍然安全。';

  @override
  String get transcriptionRetryFailed => '无法重新启动转写，你可以再次重试。';

  @override
  String get transcriptPreviewTitle => '转写预览';

  @override
  String get transcriptPreviewEmpty => '已完成的转写中没有稳定文本。';

  @override
  String get sessionRecoveryTailDiscarded => '恢复时已丢弃尚未提交的音频尾部。';

  @override
  String get sessionRecoveryTimelineGap => '恢复后的录音时间线存在缺口。';

  @override
  String get sessionRecoverySegmentMissing => '有一个已提交的音频分片缺失。';

  @override
  String get sessionRecoverySegmentCorrupt => '有一个已提交的音频分片无法通过校验。';

  @override
  String get sessionRecoveryUnknown => '此录音有一项恢复说明需要检查。';

  @override
  String get sessionPlaybackPreparing => '正在从已保存的分片准备播放音频。';

  @override
  String get sessionPlaybackUnavailable => '当前无法播放。会议详情和已保存的原始录音没有改变。';

  @override
  String get transcriptEditorLoadFailed => 'Loquiris 无法从本地存储读取此转写。';

  @override
  String get transcriptEditorNoTranscript => '此会议尚未选择转写版本。';

  @override
  String get transcriptEditorReadOnly => '此草稿仍在生成中。现在可以查看，录音和分析结束后才能编辑。';

  @override
  String get transcriptEditorSegmentsTitle => '转写文本';

  @override
  String get transcriptEditorTextLabel => '转写内容';

  @override
  String get transcriptEditorSaveText => '保存文本修正';

  @override
  String get transcriptEditorLanguageLabel => '片段语言';

  @override
  String get languageUncertain => '不确定';

  @override
  String get transcriptEditorSpeakersTitle => '说话人';

  @override
  String get transcriptEditorRenameSpeaker => '重命名说话人';

  @override
  String get transcriptEditorSpeakerName => '说话人姓名';

  @override
  String get transcriptEditorNoSpeaker => '没有说话人标签';

  @override
  String get transcriptEditorHistoryTitle => '修订记录';

  @override
  String get transcriptEditorNoHistory => '还没有人工修正';

  @override
  String get transcriptEditorSaveFailed => '此修正未能保存，当前转写没有改变。';

  @override
  String get transcriptEditorRefreshAfterSaveFailed => '修正已保存，但无法刷新最新数据。';

  @override
  String get transcriptEditorRevisionText => '已修正文本';

  @override
  String get transcriptEditorRevisionLanguage => '已修正语言';

  @override
  String get transcriptEditorRevisionSpeaker => '已修正说话人';

  @override
  String get exportPrivacyWarning =>
      '导出内容可能包含敏感音频和文本。Loquiris 只会将其写入你接下来明确选择的位置。';

  @override
  String get exportChooseFormat => '选择导出内容';

  @override
  String get exportAudioM4a => '连续 M4A';

  @override
  String get exportAudioM4aDescription => '需要时会从已提交的录音数据重建可播放音频。';

  @override
  String get exportAudioSegments => '可恢复音频分片';

  @override
  String get exportAudioSegmentsDescription =>
      '将已提交的 AAC 分片打包为 ZIP，供恢复或高级用途使用。';

  @override
  String get exportPlainText => '纯文本';

  @override
  String get exportPlainTextDescription => '包含时间戳、修订文本和说话人标签的可读转写。';

  @override
  String get exportSrt => 'SRT 字幕';

  @override
  String get exportSrtDescription => '包含毫秒级字幕时间戳的修订转写文本。';

  @override
  String get exportJson => '结构化 JSON';

  @override
  String get exportJsonDescription => '会议元数据、转写、修订、标签和模型溯源信息。';

  @override
  String get exportArchive => '完整 ZIP 包';

  @override
  String get exportArchiveDescription => '包含音频和已有文本；若 M4A 重建失败，将附带说明并改用已提交分片。';

  @override
  String get exportConfirm => '选择位置并导出';

  @override
  String get exportingLabel => '正在本地导出…';

  @override
  String get exportSelectingDestinationLabel => '正在选择导出位置…';

  @override
  String get exportWritingLabel => '正在写入导出内容…';

  @override
  String get exportFinalizingLabel => '正在完成导出…';

  @override
  String get exportCancelAction => '取消导出';

  @override
  String get exportCancellingLabel => '正在取消…';

  @override
  String exportSucceeded(String fileName) {
    return '已导出 $fileName';
  }

  @override
  String get exportSegmentsFallbackWarning => '连续音频不可用，导出包已改为包含可恢复分片。';

  @override
  String get exportPartialAudioWarning =>
      '这段录音并不完整。导出内容只包含 Loquiris 已确认安全提交的音频。';

  @override
  String get exportCancelled => '已取消导出，没有向任何位置发送内容。';

  @override
  String get exportFailed => '导出未能完成，原始会议没有改变。';

  @override
  String get exportIncompleteOutputWarning =>
      '导出已停止，但 Android 无法删除未完成文件。请检查你选择的保存位置。';

  @override
  String get exportInterruptedOutputWarning => '上一次导出意外中断，你选择的保存位置中可能仍有未完成文件。';

  @override
  String get exportPersistenceWarning => '无法在本机记录导出结果。再次尝试前，请先检查你选择的保存位置。';

  @override
  String restoredCopyTitle(String title) {
    return '$title — 恢复的副本';
  }

  @override
  String transcriptEditorSegmentTime(String start, String end) {
    return '$start–$end';
  }

  @override
  String get storageApplicationAndModels => '应用与模型';

  @override
  String get storageActiveMeetings => '使用中的会议';

  @override
  String get storageRebuildableCache => '可重建缓存';

  @override
  String get storageTrash => '回收站';

  @override
  String get storageAvailableDeviceSpace => '设备可用空间';

  @override
  String get storageAccountingIntro =>
      '这些统计数据仅保留在本设备。会议大小来自 Loquiris 记录；应用、缓存和可用空间来自 Android。';

  @override
  String storageApplicationModelsDetail(String size) {
    return '其中包含 $size 的内置模型文件。本版本不能单独移除内置模型；其他私有支持数据也归入此项。';
  }

  @override
  String get storageActiveMeetingsDetail => '回收站以外会议的已提交音频。';

  @override
  String get storageRebuildableCacheDetail => 'Loquiris 可在需要时重新生成的临时数据。';

  @override
  String get storageTrashDetail => '已保留的提交音频，直到你将其永久删除。';

  @override
  String get storageAvailableDeviceSpaceDetail =>
      'Android 当前报告 Loquiris 可使用的空间。';

  @override
  String get storageLoadingLabel => '正在测量本设备存储空间';

  @override
  String get storageLoadError => 'Loquiris 目前无法测量存储空间。你的本地数据没有改变。';

  @override
  String get clearRebuildableCacheAction => '清理可重建缓存';

  @override
  String get clearRebuildableCacheDescription =>
      '只移除白名单中的 PCM、波形、搜索索引和失败任务临时文件。会议、编辑内容、备份、回收站和未知缓存不会改变。';

  @override
  String get clearingRebuildableCacheLabel => '正在清理可重建缓存…';

  @override
  String rebuildableCacheCleared(String size, int count) {
    return '已从 $count 个文件中清理 $size。';
  }

  @override
  String get rebuildableCacheNothingCleared => '没有需要清理的白名单可重建缓存。';

  @override
  String get rebuildableCacheCleanupFailed => '缓存清理未能完成，请重试。会议数据没有改变。';

  @override
  String rebuildableCacheCleanupPartiallyFailed(String size) {
    return '清理 $size 后操作停止，请重试。会议数据没有改变。';
  }

  @override
  String get benchmarkIntro => '运行一次简短的离线检查，了解此设备可稳定支持哪种本地处理模式。';

  @override
  String get benchmarkFixedAudioDisclosure =>
      '检查使用内置的 45 秒中英文混合音频。它不会启动麦克风、保存录音或更改设置。';

  @override
  String get performancePolicyHeading => '运行模式与录音保护';

  @override
  String get performancePolicyLockedBody =>
      '在兼容的本地推理运行时和模型通过验证前，这些模式仅供说明。本页面绝不会自动更改设置。';

  @override
  String get performancePolicyRecommendedLabel => '本次检查推荐';

  @override
  String get performancePolicyTimingLiveOrPostSession => '录音期间或录音结束后';

  @override
  String get performancePolicyTimingPostSessionOnly => '仅在录音结束后';

  @override
  String get performancePolicyTimingDisabled => 'AI 处理已关闭';

  @override
  String get performancePolicyHighQualityDescription => '录音结束后使用通过验证的更高质量模型。';

  @override
  String get performancePolicyHighQualityFallback => '可降为均衡的会后处理，最后仅保留录音。';

  @override
  String get performancePolicyBalancedDescription => '在转写质量与设备资源之间取得平衡。';

  @override
  String get performancePolicyBalancedFallback => '可降低资源使用、延后处理，或仅保留录音。';

  @override
  String get performancePolicyPowerSavingDescription => '通过验证后，使用更小的模型或更低的并发。';

  @override
  String get performancePolicyPowerSavingFallback => '可将处理延后到录音结束后，必要时仅保留录音。';

  @override
  String get performancePolicyPostSessionDescription => '录音时保留资源，结束后再在本机分析。';

  @override
  String get performancePolicyPostSessionFallback => '即使无法分析，录音仍然可用。';

  @override
  String get performancePolicyRecordingOnlyDescription => '保存权威音频，不运行 AI。';

  @override
  String get performancePolicyRecordingOnlyFallback => '录音继续，不再执行 AI 降级。';

  @override
  String get performancePolicyProtectionHeading => 'Loquiris 如何保护录音';

  @override
  String get performancePolicyProtectionModerateThermal => '中度发热时会降低 AI 并发。';

  @override
  String get performancePolicyProtectionSevereThermal => '严重发热时会暂停 AI，但录音继续。';

  @override
  String get performancePolicyProtectionBacklog => '持续积压会把未完成的工作移到录音结束后。';

  @override
  String get performancePolicyProtectionRecordingFirst => '引擎或资源故障绝不会丢弃权威录音音频。';

  @override
  String get benchmarkUnavailableHeading => '性能检查不可用';

  @override
  String get benchmarkUnavailableRuntimeBody => '此版本尚未安装本地性能检查运行环境。录音功能仍可使用。';

  @override
  String get benchmarkReadyHeading => '可以开始离线检查';

  @override
  String get benchmarkStartAction => '开始性能检查';

  @override
  String get benchmarkRunningHeading => '性能检查正在运行';

  @override
  String benchmarkProgressPercent(int percent) {
    return '已完成 $percent%';
  }

  @override
  String get benchmarkCancelAction => '取消性能检查';

  @override
  String get benchmarkCancelledHeading => '检查已取消';

  @override
  String get benchmarkCancelledBody => '没有保存结果，也没有更改任何设置。';

  @override
  String get benchmarkRecommendationHeading => '推荐模式';

  @override
  String get benchmarkShortCheckLimitation =>
      '此建议仅来自短时检查，并不保证长时间会议中的表现。选择模式前请先查看结果。';

  @override
  String get benchmarkRerunAction => '重新检查';

  @override
  String get benchmarkFailureHeading => '检查未能完成';

  @override
  String get benchmarkRetryAction => '重试性能检查';

  @override
  String get benchmarkEvidenceHeading => '模式依据';

  @override
  String get benchmarkStatusPassed => '通过';

  @override
  String get benchmarkStatusFailed => '未通过';

  @override
  String get benchmarkStatusUnmeasured => '未测量';

  @override
  String get benchmarkStatusMeasured => '已测量';

  @override
  String get benchmarkModeHighQuality => '高质量';

  @override
  String get benchmarkModeBalanced => '平衡';

  @override
  String get benchmarkModePowerSaving => '节能';

  @override
  String get benchmarkModeRecordingOnly => '仅录音';

  @override
  String get benchmarkModePostSession => '会后处理';

  @override
  String benchmarkRtfMetric(num value) {
    return '实时系数：$value×';
  }

  @override
  String benchmarkLatencyMetric(int milliseconds) {
    return '首段文字延迟：$milliseconds 毫秒';
  }

  @override
  String benchmarkModeStatusSemantic(String mode, String status) {
    return '$mode：$status';
  }

  @override
  String get benchmarkRecommendationBalanced => '此设备在短时检查中达到了平衡实时处理模式的阈值。';

  @override
  String get benchmarkRecommendationPowerSaving => '平衡模式未达标时，节能实时处理达到了短时检查阈值。';

  @override
  String get benchmarkRecommendationPostSession =>
      '对这台设备而言，录音结束后处理是测得的最稳妥 AI 选项。';

  @override
  String get benchmarkRecommendationRecordingOnly =>
      '没有已测 AI 模式达到全部短时检查阈值，因此仅录音是安全的回退选项。';

  @override
  String get benchmarkFailureInvalidAsset => '内置基准音频缺失或未通过完整性校验。';

  @override
  String get benchmarkFailureInvalidOutput => '性能检查运行环境返回了无效输出，因此没有生成建议。';

  @override
  String get benchmarkFailureEngine => '本地推理引擎在检查完成前停止。';

  @override
  String get benchmarkFailureRuntimeUnavailable => '本地性能检查运行环境不可用。录音功能仍可使用。';

  @override
  String get benchmarkFailureGeneric => '本地检查意外停止，没有保存任何建议。';

  @override
  String get benchmarkCompletedSemantic => '性能检查已完成';

  @override
  String get benchmarkFailedSemantic => '性能检查失败';

  @override
  String get benchmarkExportAction => '导出报告';

  @override
  String get benchmarkExportingAction => '正在导出报告…';

  @override
  String benchmarkExportSucceeded(String fileName) {
    return '已保存 $fileName。';
  }

  @override
  String get benchmarkExportCancelled => '已取消导出，未保存任何文件。';

  @override
  String get benchmarkExportFailed => '无法导出报告，请重试。';

  @override
  String get liveTranscriptTitle => '实时转写草稿';

  @override
  String get liveTranscriptExperimentalLabel => '实验功能 · 只读';

  @override
  String get liveTranscriptWaiting => '正在等待首段本地草稿…';

  @override
  String get liveTranscriptStableLabel => '已稳定';

  @override
  String get liveTranscriptDraftLabel => '草稿';

  @override
  String liveTranscriptStableSegment(String text) {
    return '已稳定。$text';
  }

  @override
  String liveTranscriptDraftSegment(String text) {
    return '草稿。$text';
  }

  @override
  String liveTranscriptBacklog(int seconds) {
    return '实时草稿大约落后 $seconds 秒。';
  }

  @override
  String get liveTranscriptIncomplete => '这份实时草稿可能不完整。';

  @override
  String get liveTranscriptThermalFallback => '设备温度过高，实时转写已暂停。';

  @override
  String get liveTranscriptModelFallback => '本地模型无法启动实时转写。';

  @override
  String get liveTranscriptGenericFallback => '实时转写已安全停止。';

  @override
  String get liveTranscriptPostSessionFallback => '录音结束后将运行完整转写。';
}
