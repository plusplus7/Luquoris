import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/l10n/app_localizations_en.dart';
import 'package:loquiris/l10n/app_localizations_zh.dart';

void main() {
  test('benchmark copy and numeric messages exist in both locales', () {
    final english = AppLocalizationsEn();
    final chinese = AppLocalizationsZh();

    expect(english.benchmarkIntro, contains('device'));
    expect(chinese.benchmarkIntro, contains('设备'));
    expect(english.benchmarkFixedAudioDisclosure, contains('microphone'));
    expect(chinese.benchmarkFixedAudioDisclosure, contains('麦克风'));
    expect(english.benchmarkProgressPercent(42), '42% complete');
    expect(chinese.benchmarkProgressPercent(42), '已完成 42%');
    expect(english.benchmarkRtfMetric(0.5), 'Real-time factor: 0.5×');
    expect(chinese.benchmarkRtfMetric(0.5), '实时系数：0.5×');
    expect(
      english.benchmarkLatencyMetric(2000),
      'First text latency: 2000 ms',
    );
    expect(chinese.benchmarkLatencyMetric(2000), '首段文字延迟：2000 毫秒');
    expect(english.benchmarkModeRecordingOnly, 'Recording only');
    expect(chinese.benchmarkModeRecordingOnly, '仅录音');
    expect(english.benchmarkShortCheckLimitation, contains('short check'));
    expect(chinese.benchmarkShortCheckLimitation, contains('短时检查'));
  });

  test('benchmark export copy exists in English and Chinese', () {
    final english = AppLocalizationsEn();
    final chinese = AppLocalizationsZh();

    expect(english.benchmarkExportAction, 'Export report');
    expect(chinese.benchmarkExportAction, '导出报告');
    expect(english.benchmarkExportingAction, 'Exporting report…');
    expect(chinese.benchmarkExportingAction, '正在导出报告…');
    expect(
      english.benchmarkExportSucceeded('benchmark-report.json'),
      'Saved benchmark-report.json.',
    );
    expect(
      chinese.benchmarkExportSucceeded('benchmark-report.json'),
      '已保存 benchmark-report.json。',
    );
    expect(
      english.benchmarkExportCancelled,
      'Export cancelled. No file was saved.',
    );
    expect(chinese.benchmarkExportCancelled, '已取消导出，未保存任何文件。');
    expect(
      english.benchmarkExportFailed,
      'Report could not be exported. Try again.',
    );
    expect(chinese.benchmarkExportFailed, '无法导出报告，请重试。');
  });

  test('performance policy vocabulary exists in both locales', () {
    final english = AppLocalizationsEn();
    final chinese = AppLocalizationsZh();

    expect(
      english.performancePolicyHeading,
      'Operating modes and recording protection',
    );
    expect(chinese.performancePolicyHeading, '运行模式与录音保护');
    expect(
      english.performancePolicyLockedBody,
      'Modes remain informational until a compatible local inference runtime '
      'and model pass validation. This screen never changes settings '
      'automatically.',
    );
    expect(
      chinese.performancePolicyLockedBody,
      '在兼容的本地推理运行时和模型通过验证前，这些模式仅供说明。本页面绝不会自动更改设置。',
    );
    expect(
      english.performancePolicyRecommendedLabel,
      'Recommended by this check',
    );
    expect(chinese.performancePolicyRecommendedLabel, '本次检查推荐');
    expect(
      english.performancePolicyTimingLiveOrPostSession,
      'During recording or after recording',
    );
    expect(
      chinese.performancePolicyTimingLiveOrPostSession,
      '录音期间或录音结束后',
    );
    expect(
      english.performancePolicyTimingPostSessionOnly,
      'After recording only',
    );
    expect(chinese.performancePolicyTimingPostSessionOnly, '仅在录音结束后');
    expect(english.performancePolicyTimingDisabled, 'AI processing off');
    expect(chinese.performancePolicyTimingDisabled, 'AI 处理已关闭');
    expect(
      english.performancePolicyProtectionHeading,
      'How Loquiris protects recording',
    );
    expect(chinese.performancePolicyProtectionHeading, 'Loquiris 如何保护录音');
    expect(
      english.performancePolicyProtectionModerateThermal,
      'Moderate heat reduces AI concurrency.',
    );
    expect(
      chinese.performancePolicyProtectionModerateThermal,
      '中度发热时会降低 AI 并发。',
    );
    expect(
      english.performancePolicyProtectionSevereThermal,
      'Severe heat pauses AI while recording continues.',
    );
    expect(
      chinese.performancePolicyProtectionSevereThermal,
      '严重发热时会暂停 AI，但录音继续。',
    );
    expect(
      english.performancePolicyProtectionBacklog,
      'Sustained backlog moves unfinished work to after recording.',
    );
    expect(
      chinese.performancePolicyProtectionBacklog,
      '持续积压会把未完成的工作移到录音结束后。',
    );
    expect(
      english.performancePolicyProtectionRecordingFirst,
      'Engine or resource failure never discards canonical recording audio.',
    );
    expect(
      chinese.performancePolicyProtectionRecordingFirst,
      '引擎或资源故障绝不会丢弃权威录音音频。',
    );
  });
}
