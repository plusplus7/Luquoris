import 'package:flutter/material.dart';
import 'package:loquiris/theme/loquiris_tokens.dart';

/// Builds one independently authored Loquiris Material 3 theme.
ThemeData buildLoquirisTheme(Brightness brightness) {
  final colors = switch (brightness) {
    Brightness.light => lightLoquirisColors,
    Brightness.dark => darkLoquirisColors,
  };
  const spacing = LoquirisSpacing.standard;
  const shapes = LoquirisShapes.standard;
  const motion = LoquirisMotion.standard;
  const typography = LoquirisTypography.standard;
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: colors.accent,
    onPrimary: colors.onAccent,
    secondary: colors.processing,
    onSecondary: colors.onAccent,
    error: colors.danger,
    onError: colors.onAccent,
    surface: colors.surface,
    onSurface: colors.onSurface,
    surfaceContainer: colors.surfaceRaised,
    surfaceContainerHigh: colors.surfaceRaised,
    surfaceContainerHighest: colors.surfaceRaised,
    onSurfaceVariant: colors.onSurfaceMuted,
    outline: colors.hairline,
    outlineVariant: colors.hairline,
  );
  final textTheme = TextTheme(
    displayLarge: typography.display.copyWith(color: colors.onSurface),
    headlineSmall: typography.title.copyWith(color: colors.onSurface),
    bodyLarge: typography.body.copyWith(color: colors.onSurface),
    labelLarge: typography.label.copyWith(color: colors.onSurface),
    bodySmall: typography.caption.copyWith(color: colors.onSurfaceMuted),
  );

  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colors.surface,
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    focusColor: colors.focus,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: typography.title.copyWith(color: colors.onSurface),
    ),
    cardTheme: CardThemeData(
      color: colors.surfaceRaised,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(shapes.panelRadius),
        side: BorderSide(color: colors.hairline, width: shapes.hairlineWidth),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        textStyle: typography.label,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.controlRadius),
        ),
      ),
    ),
    extensions: [spacing, shapes, motion, typography, colors],
  );
}
