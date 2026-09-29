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
