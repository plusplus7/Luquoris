import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/services/service_providers.dart';

import 'fakes/fake_services.dart';

/// Logical test surface and its physical pixel density.
final class TestDevice {
  const TestDevice(this.name, this.logicalSize, this.dpr);

  final String name;
  final Size logicalSize;
  final double dpr;

  static const compact = TestDevice('compact_320', Size(320, 640), 2);
  static const constrained = TestDevice('constrained_280', Size(280, 600), 2);
  static const smallLandscape = TestDevice(
    'small_landscape_640',
    Size(640, 320),
    2,
  );
  static const medium = TestDevice('medium_720', Size(720, 1024), 2);
}

/// Shared pinned-surface harness for Loquiris widget tests.
extension LoquirisWidgetHarness on WidgetTester {
  /// Pins logical size and DPR and restores both after the test.
  void useDevice(TestDevice device) {
    view.devicePixelRatio = device.dpr;
    view.physicalSize = device.logicalSize * device.dpr;
    addTearDown(view.reset);
  }

  /// Pumps the app with deterministic local-only dependencies and a11y axes.
  Future<void> pumpLoquirisApp({
    List<Override> overrides = const [],
    TextScaler textScaler = TextScaler.noScaling,
    bool boldText = false,
    bool accessibleNavigation = false,
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: [
          audioCaptureServiceProvider.overrideWithValue(
            FakeAudioCaptureService(),
          ),
          sessionRepositoryProvider.overrideWithValue(
            FakeSessionRepository(),
          ),
          ...overrides,
        ],
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: textScaler,
              boldText: boldText,
              accessibleNavigation: accessibleNavigation,
            ),
            child: const LoquirisApp(),
          ),
        ),
      ),
    );
    await pump();
  }
}
