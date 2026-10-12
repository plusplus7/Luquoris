import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/l10n/app_localizations_en.dart';
import 'package:loquiris/l10n/app_localizations_zh.dart';

void main() {
  test('phase 8 privacy and correction messages exist in both locales', () {
    final english = AppLocalizationsEn();
    final chinese = AppLocalizationsZh();

    expect(english.sessionsSearchHint, 'Search meetings');
    expect(chinese.sessionsSearchHint, '搜索会议');
    expect(english.transcriptEditorSaveText, 'Save text correction');
    expect(chinese.transcriptEditorSaveText, '保存文本修正');
    expect(english.transcriptionPreparingModel, 'Preparing the offline model');
    expect(chinese.transcriptionPreparingModel, '正在准备离线模型');
    expect(english.transcriptionProgress(42), 'Transcribing locally 42%');
    expect(chinese.transcriptionProgress(42), '正在本地转写 42%');
    expect(english.transcriptionDelayed, contains('recording is safe'));
    expect(chinese.transcriptionDelayed, contains('录音仍然安全'));
    expect(english.transcriptionIncomplete, contains('incomplete'));
    expect(chinese.transcriptionIncomplete, contains('不完整'));
    expect(english.transcriptionRetryAction, 'Retry transcription');
    expect(chinese.transcriptionRetryAction, '重试转写');
    expect(english.transcriptionCancelled, contains('cancelled'));
    expect(chinese.transcriptionCancelled, contains('已取消'));
    expect(
      english.trashRetentionNotice,
      contains('Nothing is deleted automatically'),
    );
    expect(chinese.trashRetentionNotice, contains('不会自动清空'));
    expect(english.permanentDeleteBody, contains('exported or backed up'));
    expect(chinese.permanentDeleteBody, contains('导出或备份'));
    expect(english.permanentDeleteFailed, contains('safe retry'));
    expect(chinese.permanentDeleteFailed, contains('安全重试'));
  });
}
