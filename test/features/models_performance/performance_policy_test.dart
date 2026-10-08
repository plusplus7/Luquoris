import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/features/models_performance/domain/performance_policy.dart';
import 'package:loquiris/features/models_performance/domain/processing_entities.dart';

void main() {
  test('standard catalog defines exactly one immutable policy per mode', () {
    final catalog = PerformancePolicyCatalog.standard;

    expect(
      catalog.policies.map((policy) => policy.mode),
      orderedEquals(PerformanceMode.values),
    );
    expect(
      () => catalog.policies.add(_recordingOnlyPolicy()),
      throwsUnsupportedError,
    );
    expect(
      () => catalog
          .policyFor(PerformanceMode.highQuality)
          .safeFallbacks
          .add(PerformanceMode.highQuality),
      throwsUnsupportedError,
    );
  });

  test(
    'standard policies expose the approved timing quality resource and fallback matrix',
    () {
      final expected =
          <
            PerformanceMode,
            (
              PerformanceExecutionTiming,
              PerformanceQualityIntent,
              PerformanceResourceIntent,
              List<PerformanceMode>,
            )
          >{
            PerformanceMode.highQuality: (
              PerformanceExecutionTiming.postSessionOnly,
              PerformanceQualityIntent.highest,
              PerformanceResourceIntent.expanded,
              const [
                PerformanceMode.balanced,
                PerformanceMode.postSession,
                PerformanceMode.recordingOnly,
              ],
            ),
            PerformanceMode.balanced: (
              PerformanceExecutionTiming.liveOrPostSession,
              PerformanceQualityIntent.balanced,
              PerformanceResourceIntent.standard,
              const [
                PerformanceMode.powerSaving,
                PerformanceMode.postSession,
                PerformanceMode.recordingOnly,
              ],
            ),
            PerformanceMode.powerSaving: (
              PerformanceExecutionTiming.liveOrPostSession,
              PerformanceQualityIntent.conservative,
              PerformanceResourceIntent.reduced,
              const [
                PerformanceMode.postSession,
                PerformanceMode.recordingOnly,
              ],
            ),
            PerformanceMode.postSession: (
              PerformanceExecutionTiming.postSessionOnly,
              PerformanceQualityIntent.balanced,
              PerformanceResourceIntent.standard,
              const [PerformanceMode.recordingOnly],
            ),
            PerformanceMode.recordingOnly: (
              PerformanceExecutionTiming.disabled,
              PerformanceQualityIntent.none,
              PerformanceResourceIntent.captureOnly,
              const [],
            ),
          };

      for (final entry in expected.entries) {
        final policy = PerformancePolicyCatalog.standard.policyFor(entry.key);
        final (timing, quality, resource, fallbacks) = entry.value;

        expect(policy.timing, timing, reason: entry.key.name);
        expect(policy.qualityIntent, quality, reason: entry.key.name);
        expect(policy.resourceIntent, resource, reason: entry.key.name);
        expect(
          policy.safeFallbacks,
          orderedEquals(fallbacks),
          reason: entry.key.name,
        );
      }
    },
  );

  test('high quality fallback never advances post session timing', () {
    final policy = PerformancePolicyCatalog.standard.policyFor(
      PerformanceMode.highQuality,
    );

    expect(policy.timing, PerformanceExecutionTiming.postSessionOnly);
    expect(
      policy.safeFallbacks,
      orderedEquals(const [
        PerformanceMode.balanced,
        PerformanceMode.postSession,
        PerformanceMode.recordingOnly,
      ]),
    );
  });

  test(
    'catalog rejects missing duplicate self cyclic and aggressive fallback definitions',
    () {
      final valid = _standardPolicies();

      expect(
        () => PerformancePolicyCatalog(valid.sublist(0, valid.length - 1)),
        throwsArgumentError,
      );
      expect(
        () => PerformancePolicyCatalog([...valid, valid.first]),
        throwsArgumentError,
      );
      expect(
        () => PerformancePolicyCatalog([
          _policy(
            PerformanceMode.highQuality,
            timing: PerformanceExecutionTiming.postSessionOnly,
            quality: PerformanceQualityIntent.highest,
            resource: PerformanceResourceIntent.expanded,
            fallbacks: const [PerformanceMode.highQuality],
          ),
          ...valid.skip(1),
        ]),
        throwsArgumentError,
      );
      expect(
        () => PerformancePolicyCatalog([
          valid.first,
          _policy(
            PerformanceMode.balanced,
            fallbacks: const [PerformanceMode.powerSaving],
          ),
          _policy(
            PerformanceMode.powerSaving,
            quality: PerformanceQualityIntent.conservative,
            resource: PerformanceResourceIntent.reduced,
            fallbacks: const [PerformanceMode.balanced],
          ),
          ...valid.skip(3),
        ]),
        throwsArgumentError,
      );
      expect(
        () => PerformancePolicyCatalog([
          ...valid.take(3),
          _policy(
            PerformanceMode.postSession,
            timing: PerformanceExecutionTiming.postSessionOnly,
            fallbacks: const [PerformanceMode.highQuality],
          ),
          valid.last,
        ]),
        throwsArgumentError,
      );
    },
  );
}

List<PerformanceModePolicy> _standardPolicies() => [
  _policy(
    PerformanceMode.highQuality,
    timing: PerformanceExecutionTiming.postSessionOnly,
    quality: PerformanceQualityIntent.highest,
    resource: PerformanceResourceIntent.expanded,
    fallbacks: const [
      PerformanceMode.balanced,
      PerformanceMode.postSession,
      PerformanceMode.recordingOnly,
    ],
  ),
  _policy(
    PerformanceMode.balanced,
    fallbacks: const [
      PerformanceMode.powerSaving,
      PerformanceMode.postSession,
      PerformanceMode.recordingOnly,
    ],
  ),
  _policy(
    PerformanceMode.powerSaving,
    quality: PerformanceQualityIntent.conservative,
    resource: PerformanceResourceIntent.reduced,
    fallbacks: const [
      PerformanceMode.postSession,
      PerformanceMode.recordingOnly,
    ],
  ),
  _policy(
    PerformanceMode.postSession,
    timing: PerformanceExecutionTiming.postSessionOnly,
    fallbacks: const [PerformanceMode.recordingOnly],
  ),
  _recordingOnlyPolicy(),
];

PerformanceModePolicy _recordingOnlyPolicy() => _policy(
  PerformanceMode.recordingOnly,
  timing: PerformanceExecutionTiming.disabled,
  quality: PerformanceQualityIntent.none,
  resource: PerformanceResourceIntent.captureOnly,
);

PerformanceModePolicy _policy(
  PerformanceMode mode, {
  PerformanceExecutionTiming timing =
      PerformanceExecutionTiming.liveOrPostSession,
  PerformanceQualityIntent quality = PerformanceQualityIntent.balanced,
  PerformanceResourceIntent resource = PerformanceResourceIntent.standard,
  List<PerformanceMode> fallbacks = const [],
}) => PerformanceModePolicy(
  mode: mode,
  timing: timing,
  qualityIntent: quality,
  resourceIntent: resource,
  safeFallbacks: fallbacks,
);
