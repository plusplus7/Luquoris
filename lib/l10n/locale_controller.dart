import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Owns the optional user locale override; `null` follows the operating system.
final localeControllerProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

/// Controls the locale selected inside Loquiris.
final class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  /// Follows the operating-system locale.
  void useSystemLocale() => state = null;

  /// Forces English regardless of the operating-system locale.
  void useEnglish() => state = const Locale('en');

  /// Forces simplified Chinese regardless of the operating-system locale.
  void useSimplifiedChinese() => state = const Locale('zh');
}
