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
}
