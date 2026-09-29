import 'package:flutter/material.dart';

/// Measured visual primitives. Widgets must consume semantic extensions instead.
abstract final class LoquirisPrimitives {
  /// Neutral primitive near measured lightness 6.
  static const neutral06 = Color(0xFF0F1115);

  /// Neutral primitive near measured lightness 10.
  static const neutral10 = Color(0xFF181B22);

  /// Neutral primitive near measured lightness 14.
  static const neutral14 = Color(0xFF222630);

  /// Neutral primitive near measured lightness 20.
  static const neutral20 = Color(0xFF303641);

  /// Neutral primitive near measured lightness 38.
  static const neutral38 = Color(0xFF5B6474);

  /// Neutral primitive near measured lightness 52.
  static const neutral52 = Color(0xFF7E899A);

  /// Neutral primitive near measured lightness 72.
  static const neutral72 = Color(0xFFAEB8C7);

  /// Neutral primitive near measured lightness 86.
  static const neutral86 = Color(0xFFD4DAE4);

  /// Neutral primitive near measured lightness 94.
  static const neutral94 = Color(0xFFEDEFF4);

  /// Neutral primitive near measured lightness 98.
  static const neutral98 = Color(0xFFF9FAFC);

  /// Iris primitive near measured lightness 34.
  static const iris34 = Color(0xFF49398F);

  /// Iris primitive near measured lightness 44.
  static const iris44 = Color(0xFF6251B5);

  /// Iris primitive near measured lightness 62.
  static const iris62 = Color(0xFF9788E2);

  /// Iris primitive near measured lightness 78.
  static const iris78 = Color(0xFFC2B8F4);

  /// Teal primitive near measured lightness 36.
  static const teal36 = Color(0xFF236B70);

  /// Teal primitive near measured lightness 62.
  static const teal62 = Color(0xFF76BEC2);

  /// Green primitive near measured lightness 34.
  static const green34 = Color(0xFF326A4D);

  /// Green primitive near measured lightness 68.
  static const green68 = Color(0xFF8FD0AC);

  /// Amber primitive near measured lightness 42.
  static const amber42 = Color(0xFF8C5A08);

  /// Amber primitive near measured lightness 72.
  static const amber72 = Color(0xFFE5B75E);

  /// Orange primitive near measured lightness 38.
  static const orange38 = Color(0xFF9A480D);

  /// Orange primitive near measured lightness 72.
  static const orange72 = Color(0xFFF0A06A);

  /// Red primitive near measured lightness 30.
  static const red30 = Color(0xFF79283A);

  /// Red primitive near measured lightness 42.
  static const red42 = Color(0xFFA33E50);

  /// Red primitive near measured lightness 60.
  static const red60 = Color(0xFFD46D80);

  /// Red primitive near measured lightness 72.
  static const red72 = Color(0xFFE99AAA);
}

/// Measured layout primitives used to build semantic spacing and shapes.
abstract final class LoquirisMetrics {
  /// Four logical pixels.
  static const space4 = 4.0;

  /// Eight logical pixels.
  static const space8 = 8.0;

  /// Twelve logical pixels.
  static const space12 = 12.0;

  /// Sixteen logical pixels.
  static const space16 = 16.0;

  /// Twenty-four logical pixels.
  static const space24 = 24.0;

  /// Thirty-two logical pixels.
  static const space32 = 32.0;

  /// Ten logical pixels of radius.
  static const radius10 = 10.0;

  /// Sixteen logical pixels of radius.
  static const radius16 = 16.0;

  /// Twenty-four logical pixels of radius.
  static const radius24 = 24.0;

  /// One logical pixel of stroke width.
  static const stroke1 = 1.0;
}
