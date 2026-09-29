import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:loquiris/theme/primitives.dart';

/// Semantic Loquiris color roles for one brightness.
@immutable
final class LoquirisColors extends ThemeExtension<LoquirisColors> {
  /// Creates a complete semantic color set.
  const LoquirisColors({
    required this.brightness,
    required this.surface,
    required this.surfaceRaised,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.accent,
    required this.onAccent,
    required this.hairline,
    required this.focus,
    required this.recording,
    required this.paused,
    required this.processing,
    required this.success,
    required this.warning,
    required this.danger,
    required this.experimental,
  });

  /// Reads the extension and fails loudly when the app theme omitted it.
  static LoquirisColors of(BuildContext context) {
    final value = Theme.of(context).extension<LoquirisColors>();
    assert(value != null, 'LoquirisColors is missing from ThemeData.');
    return value!;
  }

  /// Brightness this independently authored palette targets.
  final Brightness brightness;

  /// Primary app background.
  final Color surface;

  /// Elevated panel background.
  final Color surfaceRaised;

  /// Primary content on [surface].
  final Color onSurface;

  /// Secondary content on [surface].
  final Color onSurfaceMuted;

  /// Primary interactive accent.
  final Color accent;

  /// Content rendered on [accent].
  final Color onAccent;

  /// Dividers and meaningful boundaries.
  final Color hairline;

  /// Keyboard and accessibility focus indicator.
  final Color focus;

  /// Supporting color for an actively recording state.
  final Color recording;

  /// Supporting color for a user-paused state.
  final Color paused;

  /// Supporting color for local processing.
  final Color processing;

  /// Supporting color for successful completion.
  final Color success;

  /// Supporting color for warnings needing attention.
  final Color warning;

  /// Supporting color for failures.
  final Color danger;

  /// Supporting color for explicitly experimental capability.
  final Color experimental;

  @override
  LoquirisColors copyWith({
    Brightness? brightness,
    Color? surface,
    Color? surfaceRaised,
    Color? onSurface,
    Color? onSurfaceMuted,
    Color? accent,
    Color? onAccent,
    Color? hairline,
    Color? focus,
    Color? recording,
    Color? paused,
    Color? processing,
    Color? success,
    Color? warning,
    Color? danger,
    Color? experimental,
  }) {
    return LoquirisColors(
      brightness: brightness ?? this.brightness,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      hairline: hairline ?? this.hairline,
      focus: focus ?? this.focus,
      recording: recording ?? this.recording,
      paused: paused ?? this.paused,
      processing: processing ?? this.processing,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      experimental: experimental ?? this.experimental,
    );
  }

  @override
  LoquirisColors lerp(covariant LoquirisColors? other, double t) {
    if (other == null) return this;
    return LoquirisColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      recording: Color.lerp(recording, other.recording, t)!,
      paused: Color.lerp(paused, other.paused, t)!,
      processing: Color.lerp(processing, other.processing, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      experimental: Color.lerp(experimental, other.experimental, t)!,
    );
  }
}

/// Light palette with restrained iris accents and neutral meeting surfaces.
const lightLoquirisColors = LoquirisColors(
  brightness: Brightness.light,
  surface: LoquirisPrimitives.neutral98,
  surfaceRaised: LoquirisPrimitives.neutral94,
  onSurface: LoquirisPrimitives.neutral10,
  onSurfaceMuted: LoquirisPrimitives.neutral38,
  accent: LoquirisPrimitives.iris44,
  onAccent: LoquirisPrimitives.neutral98,
  hairline: LoquirisPrimitives.neutral52,
  focus: LoquirisPrimitives.teal36,
  recording: LoquirisPrimitives.red42,
  paused: LoquirisPrimitives.amber42,
  processing: LoquirisPrimitives.teal36,
  success: LoquirisPrimitives.green34,
  warning: LoquirisPrimitives.orange38,
  danger: LoquirisPrimitives.red30,
  experimental: LoquirisPrimitives.iris34,
);

/// Dark palette authored independently for low-light, long-duration use.
const darkLoquirisColors = LoquirisColors(
  brightness: Brightness.dark,
  surface: LoquirisPrimitives.neutral06,
  surfaceRaised: LoquirisPrimitives.neutral14,
  onSurface: LoquirisPrimitives.neutral94,
  onSurfaceMuted: LoquirisPrimitives.neutral72,
  accent: LoquirisPrimitives.iris78,
  onAccent: LoquirisPrimitives.neutral10,
  hairline: LoquirisPrimitives.neutral38,
  focus: LoquirisPrimitives.teal62,
  recording: LoquirisPrimitives.red72,
  paused: LoquirisPrimitives.amber72,
  processing: LoquirisPrimitives.teal62,
  success: LoquirisPrimitives.green68,
  warning: LoquirisPrimitives.orange72,
  danger: LoquirisPrimitives.red60,
  experimental: LoquirisPrimitives.iris62,
);

/// Semantic spacing roles.
@immutable
final class LoquirisSpacing extends ThemeExtension<LoquirisSpacing> {
  /// Creates a semantic spacing set.
  const LoquirisSpacing({
    required this.compact,
    required this.related,
    required this.section,
    required this.page,
  });

  /// Default spacing scale.
  static const standard = LoquirisSpacing(
    compact: LoquirisMetrics.space4,
    related: LoquirisMetrics.space8,
    section: LoquirisMetrics.space16,
    page: LoquirisMetrics.space24,
  );

  /// Reads the extension and fails loudly when the app theme omitted it.
  static LoquirisSpacing of(BuildContext context) {
    final value = Theme.of(context).extension<LoquirisSpacing>();
    assert(value != null, 'LoquirisSpacing is missing from ThemeData.');
    return value!;
  }

  /// Space inside dense related content.
  final double compact;

  /// Space between related controls.
  final double related;

  /// Space between content sections.
  final double section;

  /// Standard page edge inset.
  final double page;

  @override
  LoquirisSpacing copyWith({
    double? compact,
    double? related,
    double? section,
    double? page,
  }) => LoquirisSpacing(
    compact: compact ?? this.compact,
    related: related ?? this.related,
    section: section ?? this.section,
    page: page ?? this.page,
  );

  @override
  LoquirisSpacing lerp(covariant LoquirisSpacing? other, double t) {
    if (other == null) return this;
    return LoquirisSpacing(
      compact: lerpDouble(compact, other.compact, t)!,
      related: lerpDouble(related, other.related, t)!,
      section: lerpDouble(section, other.section, t)!,
      page: lerpDouble(page, other.page, t)!,
    );
  }
}

/// Semantic shape roles.
@immutable
final class LoquirisShapes extends ThemeExtension<LoquirisShapes> {
  /// Creates a semantic shape set.
  const LoquirisShapes({
    required this.controlRadius,
    required this.panelRadius,
    required this.heroRadius,
    required this.hairlineWidth,
  });

  /// Default shape scale.
  static const standard = LoquirisShapes(
    controlRadius: LoquirisMetrics.radius10,
    panelRadius: LoquirisMetrics.radius16,
    heroRadius: LoquirisMetrics.radius24,
    hairlineWidth: LoquirisMetrics.stroke1,
  );

  /// Reads the extension and fails loudly when the app theme omitted it.
  static LoquirisShapes of(BuildContext context) {
    final value = Theme.of(context).extension<LoquirisShapes>();
    assert(value != null, 'LoquirisShapes is missing from ThemeData.');
    return value!;
  }

  /// Radius for compact controls.
  final double controlRadius;

  /// Radius for cards and panels.
  final double panelRadius;

  /// Radius for prominent recording surfaces.
  final double heroRadius;

  /// Width of meaningful boundaries.
  final double hairlineWidth;

  @override
  LoquirisShapes copyWith({
    double? controlRadius,
    double? panelRadius,
    double? heroRadius,
    double? hairlineWidth,
  }) => LoquirisShapes(
    controlRadius: controlRadius ?? this.controlRadius,
    panelRadius: panelRadius ?? this.panelRadius,
    heroRadius: heroRadius ?? this.heroRadius,
    hairlineWidth: hairlineWidth ?? this.hairlineWidth,
  );

  @override
  LoquirisShapes lerp(covariant LoquirisShapes? other, double t) {
    if (other == null) return this;
    return LoquirisShapes(
      controlRadius: lerpDouble(controlRadius, other.controlRadius, t)!,
      panelRadius: lerpDouble(panelRadius, other.panelRadius, t)!,
      heroRadius: lerpDouble(heroRadius, other.heroRadius, t)!,
      hairlineWidth: lerpDouble(hairlineWidth, other.hairlineWidth, t)!,
    );
  }
}

/// Semantic motion roles.
@immutable
final class LoquirisMotion extends ThemeExtension<LoquirisMotion> {
  /// Creates a semantic motion set.
  const LoquirisMotion({
    required this.short,
    required this.medium,
    required this.long,
    required this.enter,
    required this.exit,
  });

  /// Default restrained motion scale.
  static const standard = LoquirisMotion(
    short: Duration(milliseconds: 120),
    medium: Duration(milliseconds: 220),
    long: Duration(milliseconds: 360),
    enter: Curves.easeOutCubic,
    exit: Curves.easeInCubic,
  );

  /// Reads the extension and fails loudly when the app theme omitted it.
  static LoquirisMotion of(BuildContext context) {
    final value = Theme.of(context).extension<LoquirisMotion>();
    assert(value != null, 'LoquirisMotion is missing from ThemeData.');
    return value!;
  }

  /// Feedback duration for a small local change.
  final Duration short;

  /// Duration for a component transition.
  final Duration medium;

  /// Duration for a deliberate large transition.
  final Duration long;

  /// Standard entrance curve.
  final Curve enter;

  /// Standard exit curve.
  final Curve exit;

  @override
  LoquirisMotion copyWith({
    Duration? short,
    Duration? medium,
    Duration? long,
    Curve? enter,
    Curve? exit,
  }) => LoquirisMotion(
    short: short ?? this.short,
    medium: medium ?? this.medium,
    long: long ?? this.long,
    enter: enter ?? this.enter,
    exit: exit ?? this.exit,
  );

  @override
  LoquirisMotion lerp(covariant LoquirisMotion? other, double t) {
    if (other == null) return this;
    return LoquirisMotion(
      short: Duration(
        microseconds: lerpDouble(
          short.inMicroseconds,
          other.short.inMicroseconds,
          t,
        )!.round(),
      ),
      medium: Duration(
        microseconds: lerpDouble(
          medium.inMicroseconds,
          other.medium.inMicroseconds,
          t,
        )!.round(),
      ),
      long: Duration(
        microseconds: lerpDouble(
          long.inMicroseconds,
          other.long.inMicroseconds,
          t,
        )!.round(),
      ),
      enter: t < 0.5 ? enter : other.enter,
      exit: t < 0.5 ? exit : other.exit,
    );
  }
}

/// Small semantic type scale for information-dense recording surfaces.
@immutable
final class LoquirisTypography extends ThemeExtension<LoquirisTypography> {
  /// Creates a semantic type scale.
  const LoquirisTypography({
    required this.display,
    required this.title,
    required this.body,
    required this.label,
    required this.caption,
  });

  /// Default bilingual-friendly type metrics using platform-local glyphs.
  static const standard = LoquirisTypography(
    display: TextStyle(fontSize: 40, height: 1.1, fontWeight: FontWeight.w500),
    title: TextStyle(fontSize: 24, height: 1.25, fontWeight: FontWeight.w600),
    body: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w400),
    label: TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w600),
    caption: TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w500),
  );

  /// Reads the extension and fails loudly when the app theme omitted it.
  static LoquirisTypography of(BuildContext context) {
    final value = Theme.of(context).extension<LoquirisTypography>();
    assert(value != null, 'LoquirisTypography is missing from ThemeData.');
    return value!;
  }

  /// Large timer and hero metric style.
  final TextStyle display;

  /// Page and section title style.
  final TextStyle title;

  /// Primary readable body style.
  final TextStyle body;

  /// Interactive label style.
  final TextStyle label;

  /// Supporting metadata style.
  final TextStyle caption;

  @override
  LoquirisTypography copyWith({
    TextStyle? display,
    TextStyle? title,
    TextStyle? body,
    TextStyle? label,
    TextStyle? caption,
  }) => LoquirisTypography(
    display: display ?? this.display,
    title: title ?? this.title,
    body: body ?? this.body,
    label: label ?? this.label,
    caption: caption ?? this.caption,
  );

  @override
  LoquirisTypography lerp(covariant LoquirisTypography? other, double t) {
    if (other == null) return this;
    return LoquirisTypography(
      display: TextStyle.lerp(display, other.display, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
    );
  }
}

/// Canonical product states whose supporting color is resolved last.
enum LoquirisStatus {
  /// Microphone capture is active.
  recording,

  /// Capture is intentionally paused.
  paused,

  /// Local analysis is running.
  processing,

  /// Work completed successfully.
  completed,

  /// Attention is needed but work may continue.
  warning,

  /// Work failed and needs recovery.
  failed,

  /// Capability has not passed production gates.
  experimental,
}

/// Resolves supporting appearance from a canonical [LoquirisStatus].
extension LoquirisStatusAppearance on LoquirisStatus {
  /// Supporting color; status meaning must also use label, glyph, and emphasis.
  Color color(LoquirisColors colors) => switch (this) {
    LoquirisStatus.recording => colors.recording,
    LoquirisStatus.paused => colors.paused,
    LoquirisStatus.processing => colors.processing,
    LoquirisStatus.completed => colors.success,
    LoquirisStatus.warning => colors.warning,
    LoquirisStatus.failed => colors.danger,
    LoquirisStatus.experimental => colors.experimental,
  };
}

/// Resolves a motion duration while honoring the platform reduce-motion flag.
Duration resolveLoquirisMotion(BuildContext context, Duration full) {
  return MediaQuery.disableAnimationsOf(context) ? Duration.zero : full;
}
