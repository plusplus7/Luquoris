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
}
