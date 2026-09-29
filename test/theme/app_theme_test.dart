import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/theme/app_theme.dart';
import 'package:loquiris/theme/loquiris_tokens.dart';

void main() {
  test('both themes install every Loquiris extension', () {
    for (final brightness in Brightness.values) {
      final theme = buildLoquirisTheme(brightness);

      expect(theme.brightness, brightness);
      expect(theme.extension<LoquirisColors>(), isNotNull);
      expect(theme.extension<LoquirisSpacing>(), isNotNull);
      expect(theme.extension<LoquirisShapes>(), isNotNull);
      expect(theme.extension<LoquirisMotion>(), isNotNull);
      expect(theme.extension<LoquirisTypography>(), isNotNull);
    }
  });

  test('declared foreground and boundary pairs meet contrast floors', () {
    for (final colors in [lightLoquirisColors, darkLoquirisColors]) {
      expect(
        _contrast(colors.onSurface, colors.surface),
        greaterThanOrEqualTo(4.5),
        reason: '${colors.brightness} onSurface',
      );
      expect(
        _contrast(colors.onSurfaceMuted, colors.surface),
        greaterThanOrEqualTo(4.5),
        reason: '${colors.brightness} onSurfaceMuted',
      );
      expect(
        _contrast(colors.onAccent, colors.accent),
        greaterThanOrEqualTo(4.5),
        reason: '${colors.brightness} onAccent',
      );
      expect(
        _contrast(colors.accent, colors.surface),
        greaterThanOrEqualTo(3),
        reason: '${colors.brightness} accent',
      );
      expect(
        _contrast(colors.hairline, colors.surface),
        greaterThanOrEqualTo(3),
        reason: '${colors.brightness} hairline',
      );
      expect(
        _contrast(colors.focus, colors.surface),
        greaterThanOrEqualTo(3),
        reason: '${colors.brightness} focus',
      );
    }
  });

  test('theme identity is hand-authored rather than seed-derived', () {
    final source = File('lib/theme/app_theme.dart').readAsStringSync();
    expect(source, isNot(contains('ColorScheme.fromSeed')));
  });
}

double _contrast(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
