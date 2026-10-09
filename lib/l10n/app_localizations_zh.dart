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
  String get sessionsLoadingLabel => '正在载入会议';

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
  String get sessionJobTranscription => '语音转写';

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
}
