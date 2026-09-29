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
}
