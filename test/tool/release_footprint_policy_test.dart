import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_size/release_footprint_policy.dart';

void main() {
  test('exact binary limits pass and one byte over fails', () {
    final exact = evaluateReleaseFootprint(
      _report(
        artifactBytes: maxReleaseArtifactBytes,
        appBytes: maxInstalledFootprintBytes - 1,
        dataBytes: 1,
      ),
    );

    expect(exact.status, ReleaseFootprintStatus.passed);
    expect(exact.violations, isEmpty);

    final artifactOver = evaluateReleaseFootprint(
      _report(artifactBytes: maxReleaseArtifactBytes + 1),
    );
    expect(artifactOver.status, ReleaseFootprintStatus.failed);
    expect(
      artifactOver.violations.map((violation) => violation.code),
      contains(ReleaseFootprintViolationCode.artifactBudgetExceeded),
    );

    final installedOver = evaluateReleaseFootprint(
      _report(
        appBytes: maxInstalledFootprintBytes,
        dataBytes: 1,
      ),
    );
    expect(installedOver.status, ReleaseFootprintStatus.failed);
    expect(
      installedOver.violations.map((violation) => violation.code),
      contains(ReleaseFootprintViolationCode.installedBudgetExceeded),
    );
  });

  test(
    'installed footprint is app plus data and cache remains evidence only',
    () {
      final report = _report(
        appBytes: 500000000,
        dataBytes: 338860800,
        cacheBytes: 900000000,
      );

      expect(report.installedMeasurement!.installedBytes, 838860800);
      expect(
        evaluateReleaseFootprint(report).status,
        ReleaseFootprintStatus.passed,
      );
      expect(
        report.toCanonicalJson()['installedMeasurement'],
        containsPair('cacheBytes', 900000000),
      );
    },
  );

  test('every required artifact variant must be present exactly once', () {
    final noAab = _report(
      artifacts: <ReleaseArtifactMeasurement>[_apk()],
    );
    final duplicateAab = _report(
      artifacts: <ReleaseArtifactMeasurement>[
        _apk(),
        _aab(),
        _aab(label: 'bundle-copy', relativePath: 'build/app-copy.aab'),
      ],
    );
    final duplicateApkLabel = _report(
      artifacts: <ReleaseArtifactMeasurement>[
        _apk(),
        _apk(relativePath: 'build/app-second.apk'),
        _aab(),
      ],
    );

    expect(
      evaluateReleaseFootprint(noAab).violations.single.code,
      ReleaseFootprintViolationCode.requiredArtifactMissing,
    );
    expect(
      evaluateReleaseFootprint(duplicateAab).violations.single.code,
      ReleaseFootprintViolationCode.requiredArtifactDuplicated,
    );
    expect(
      evaluateReleaseFootprint(duplicateApkLabel).violations.single.code,
      ReleaseFootprintViolationCode.artifactLabelDuplicated,
    );
  });

  test('unverified installed measurement cannot pass production selection', () {
    final decision = evaluateReleaseFootprint(
      _report(installedMeasurement: null),
    );

    expect(decision.status, ReleaseFootprintStatus.incomplete);
    expect(
      decision.violations.single.code,
      ReleaseFootprintViolationCode.installedMeasurementMissing,
    );
  });

  test('canonical report ordering and equality are deterministic', () {
    final first = _report(
      artifacts: <ReleaseArtifactMeasurement>[
        _apk(relativePath: 'build/universal.apk'),
        _aab(),
        _apk(label: 'arm64-v8a', relativePath: 'build/arm64.apk'),
      ],
    );
    final second = _report(
      artifacts: <ReleaseArtifactMeasurement>[
        _apk(label: 'arm64-v8a', relativePath: 'build/arm64.apk'),
        _apk(relativePath: 'build/universal.apk'),
        _aab(),
      ],
    );

    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(
      jsonEncode(first.toCanonicalJson()),
      jsonEncode(second.toCanonicalJson()),
    );
    expect(
      (first.toCanonicalJson()['artifacts']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .map((artifact) => artifact['label']),
      <String>['release-bundle', 'arm64-v8a', 'universal'],
    );
  });
}

ReleaseFootprintReport _report({
  int artifactBytes = 100,
  int appBytes = 200,
  int dataBytes = 50,
  int cacheBytes = 25,
  List<ReleaseArtifactMeasurement>? artifacts,
  InstalledFootprintMeasurement? installedMeasurement =
      const InstalledFootprintMeasurement(
        packageName: 'com.loquiris',
        versionCode: 1,
        deviceSerial: 'device-serial',
        deviceModel: 'M2104K10AC',
        buildFingerprint: 'redmi/chopin/build:fingerprint',
        observedAtUtc: '2026-10-08T00:00:00Z',
        cleanInstall: true,
        installedApkSha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        appBytes: 200,
        dataBytes: 50,
        cacheBytes: 25,
      ),
}) {
  final measurement = installedMeasurement == null
      ? null
      : InstalledFootprintMeasurement(
          packageName: installedMeasurement.packageName,
          versionCode: installedMeasurement.versionCode,
          deviceSerial: installedMeasurement.deviceSerial,
          deviceModel: installedMeasurement.deviceModel,
          buildFingerprint: installedMeasurement.buildFingerprint,
          observedAtUtc: installedMeasurement.observedAtUtc,
          cleanInstall: installedMeasurement.cleanInstall,
          installedApkSha256: installedMeasurement.installedApkSha256,
          appBytes: appBytes,
          dataBytes: dataBytes,
          cacheBytes: cacheBytes,
        );
  return ReleaseFootprintReport(
    schemaVersion: 1,
    buildId: 'release-2026-10-08',
    artifacts:
        artifacts ??
        <ReleaseArtifactMeasurement>[
          _apk(bytes: artifactBytes),
          _aab(bytes: artifactBytes),
        ],
    installedMeasurement: measurement,
  );
}

ReleaseArtifactMeasurement _apk({
  String label = 'universal',
  String relativePath = 'build/app-release.apk',
  int bytes = 100,
}) => ReleaseArtifactMeasurement(
  kind: ReleaseArtifactKind.apk,
  label: label,
  relativePath: relativePath,
  bytes: bytes,
  sha256: 'a' * 64,
);

ReleaseArtifactMeasurement _aab({
  String label = 'release-bundle',
  String relativePath = 'build/app-release.aab',
  int bytes = 100,
}) => ReleaseArtifactMeasurement(
  kind: ReleaseArtifactKind.aab,
  label: label,
  relativePath: relativePath,
  bytes: bytes,
  sha256: 'c' * 64,
);
