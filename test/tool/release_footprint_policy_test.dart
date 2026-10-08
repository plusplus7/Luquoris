import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_size/android_storage_measurement_adapter.dart';
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

  group('Android installed measurement adapter', () {
    test('accepts Android unpadded base64url payloads', () {
      final document = parseAndroidStorageMeasurement(
        _instrumentationOutput(omitBase64Padding: true),
        expectation: _androidExpectation(),
      );

      expect(document.measurement.packageName, 'com.loquiris');
      expect(document.measurement.installedBytes, 250);
    });

    test('rejects malformed instrumentation values', () {
      expect(
        () => parseAndroidStorageMeasurement(
          'INSTRUMENTATION_STATUS: loquirisFootprint=not-base64!\n',
          expectation: _androidExpectation(),
        ),
        throwsA(
          isA<AndroidStorageMeasurementFailure>().having(
            (failure) => failure.reason,
            'reason',
            AndroidStorageMeasurementFailureReason.malformedPayload,
          ),
        ),
      );
    });

    test('rejects mismatched package and build provenance', () {
      expect(
        () => parseAndroidStorageMeasurement(
          _instrumentationOutput(packageName: 'com.example.other'),
          expectation: _androidExpectation(),
        ),
        throwsA(
          isA<AndroidStorageMeasurementFailure>().having(
            (failure) => failure.reason,
            'reason',
            AndroidStorageMeasurementFailureReason.provenanceMismatch,
          ),
        ),
      );
      expect(
        () => parseAndroidStorageMeasurement(
          _instrumentationOutput(buildId: 'different-build'),
          expectation: _androidExpectation(),
        ),
        throwsA(
          isA<AndroidStorageMeasurementFailure>().having(
            (failure) => failure.reason,
            'reason',
            AndroidStorageMeasurementFailureReason.provenanceMismatch,
          ),
        ),
      );
    });

    test('rejects dirty-install evidence and missing device identity', () {
      expect(
        () => parseAndroidStorageMeasurement(
          _instrumentationOutput(cleanInstall: false),
          expectation: _androidExpectation(),
        ),
        throwsA(
          isA<AndroidStorageMeasurementFailure>().having(
            (failure) => failure.reason,
            'reason',
            AndroidStorageMeasurementFailureReason.cleanInstallNotVerified,
          ),
        ),
      );
      expect(
        () => parseAndroidStorageMeasurement(
          _instrumentationOutput(deviceSerial: ''),
          expectation: _androidExpectation(),
        ),
        throwsA(
          isA<AndroidStorageMeasurementFailure>().having(
            (failure) => failure.reason,
            'reason',
            AndroidStorageMeasurementFailureReason.deviceIdentityMissing,
          ),
        ),
      );
    });

    test('rejects signed 64-bit overflow before adding installed bytes', () {
      expect(
        () => parseAndroidStorageMeasurement(
          _instrumentationOutput(appBytes: 9223372036854775807, dataBytes: 1),
          expectation: _androidExpectation(),
        ),
        throwsA(
          isA<AndroidStorageMeasurementFailure>().having(
            (failure) => failure.reason,
            'reason',
            AndroidStorageMeasurementFailureReason.invalidByteCount,
          ),
        ),
      );
    });

    test('installed value is app plus data while cache stays separate', () {
      final document = parseAndroidStorageMeasurement(
        _instrumentationOutput(
          appBytes: 500000000,
          dataBytes: 123456789,
          cacheBytes: 987654321,
        ),
        expectation: _androidExpectation(),
      );

      expect(document.measurement.installedBytes, 623456789);
      expect(document.measurement.cacheBytes, 987654321);
      expect(document.toCanonicalJson(), <String, Object?>{
        'schemaVersion': 1,
        'buildId': 'release-2026-10-08',
        'packageName': 'com.loquiris',
        'versionCode': 1,
        'deviceSerial': 'device-serial',
        'deviceModel': 'M2104K10AC',
        'buildFingerprint': 'redmi/chopin/build:fingerprint',
        'observedAtUtc': '2026-10-08T00:00:00Z',
        'cleanInstall': true,
        'installedApkSha256': 'd' * 64,
        'appBytes': 500000000,
        'dataBytes': 123456789,
        'cacheBytes': 987654321,
      });
    });

    test(
      'adapter command writes only canonical validated measurement JSON',
      () async {
        final projectRoot = await Directory.systemTemp.createTemp(
          'loquiris-android-footprint-',
        );
        addTearDown(() => projectRoot.delete(recursive: true));
        final raw = File('${projectRoot.path}/build/instrumentation.txt');
        await raw.create(recursive: true);
        await raw.writeAsString(_instrumentationOutput());
        final outputFile = File('${projectRoot.path}/build/installed.json');
        final output = <String>[];
        final errors = <String>[];

        final code = await runAndroidStorageMeasurementAdapter(
          <String>[
            '--instrumentation-output',
            'build/instrumentation.txt',
            '--package-name',
            'com.loquiris',
            '--version-code',
            '1',
            '--build-id',
            'release-2026-10-08',
            '--device-serial',
            'device-serial',
            '--device-model',
            'M2104K10AC',
            '--build-fingerprint',
            'redmi/chopin/build:fingerprint',
            '--installed-apk-sha256',
            'd' * 64,
            '--clean-install-verified',
            'true',
            '--output',
            'build/installed.json',
          ],
          projectRoot: projectRoot,
          writeOutput: output.add,
          writeError: errors.add,
        );

        expect(code, 0);
        expect(errors, isEmpty);
        expect(output, <String>['release_footprint.android_measurement_ready']);
        expect(
          jsonDecode(await outputFile.readAsString()),
          parseAndroidStorageMeasurement(
            _instrumentationOutput(),
            expectation: _androidExpectation(),
          ).toCanonicalJson(),
        );
      },
    );
  });
}

AndroidStorageMeasurementExpectation _androidExpectation() =>
    AndroidStorageMeasurementExpectation(
      packageName: 'com.loquiris',
      versionCode: 1,
      buildId: 'release-2026-10-08',
      deviceSerial: 'device-serial',
      deviceModel: 'M2104K10AC',
      buildFingerprint: 'redmi/chopin/build:fingerprint',
      installedApkSha256: 'd' * 64,
      cleanInstallWasVerified: true,
    );

String _instrumentationOutput({
  String packageName = 'com.loquiris',
  int versionCode = 1,
  String buildId = 'release-2026-10-08',
  String deviceSerial = 'device-serial',
  String deviceModel = 'M2104K10AC',
  String buildFingerprint = 'redmi/chopin/build:fingerprint',
  bool cleanInstall = true,
  int appBytes = 200,
  int dataBytes = 50,
  int cacheBytes = 25,
  bool omitBase64Padding = false,
}) {
  var payload = base64Url.encode(
    utf8.encode(
      jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'buildId': buildId,
        'packageName': packageName,
        'versionCode': versionCode,
        'deviceSerial': deviceSerial,
        'deviceModel': deviceModel,
        'buildFingerprint': buildFingerprint,
        'observedAtUtc': '2026-10-08T00:00:00Z',
        'cleanInstall': cleanInstall,
        'installedApkSha256': 'd' * 64,
        'appBytes': appBytes,
        'dataBytes': dataBytes,
        'cacheBytes': cacheBytes,
      }),
    ),
  );
  if (omitBase64Padding) {
    payload = payload.replaceAll('=', '');
  }
  return 'INSTRUMENTATION_STATUS: loquirisFootprint=$payload\n'
      'INSTRUMENTATION_STATUS_CODE: 0\n';
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
