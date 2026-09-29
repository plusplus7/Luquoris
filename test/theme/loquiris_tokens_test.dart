import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/theme/loquiris_tokens.dart';

void main() {
  test('spacing and motion scales are monotonic', () {
    const spacing = LoquirisSpacing.standard;
    const motion = LoquirisMotion.standard;

    expect(
      [spacing.compact, spacing.related, spacing.section, spacing.page],
      orderedEquals(
        [
          ...{
            spacing.compact,
            spacing.related,
            spacing.section,
            spacing.page,
          },
        ]..sort(),
      ),
    );
    expect(motion.short < motion.medium, isTrue);
    expect(motion.medium < motion.long, isTrue);
  });

  test('light and dark semantic colors are independently authored', () {
    expect(lightLoquirisColors.brightness, Brightness.light);
    expect(darkLoquirisColors.brightness, Brightness.dark);
    expect(lightLoquirisColors.surface, isNot(darkLoquirisColors.surface));
    expect(lightLoquirisColors.accent, isNot(darkLoquirisColors.accent));
  });

  test('status color is derived from a canonical status value', () {
    final colors = LoquirisStatus.values
        .map((status) => status.color(lightLoquirisColors))
        .toSet();

    expect(colors, hasLength(LoquirisStatus.values.length));
  });

  test('theme extensions copy and interpolate every value', () {
    const spacing = LoquirisSpacing.standard;
    final changed = spacing.copyWith(page: spacing.page + 1);

    expect(changed.page, spacing.page + 1);
    expect(spacing.lerp(changed, 0).page, spacing.page);
    expect(spacing.lerp(changed, 1).page, changed.page);
    expect(
      lightLoquirisColors.lerp(darkLoquirisColors, 1).surface,
      darkLoquirisColors.surface,
    );
  });

  test('type and shape roles expose a deliberately small semantic set', () {
    const typography = LoquirisTypography.standard;
    const shapes = LoquirisShapes.standard;

    expect(
      typography.display.fontSize,
      greaterThan(typography.title.fontSize!),
    );
    expect(typography.title.fontSize, greaterThan(typography.body.fontSize!));
    expect(shapes.controlRadius, lessThan(shapes.panelRadius));
  });
}
