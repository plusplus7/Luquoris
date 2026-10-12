import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

import 'release_footprint_policy.dart';

const _maxSignedInt64 = 9223372036854775807;

/// Stable reasons Android instrumentation evidence cannot be trusted.
enum AndroidStorageMeasurementFailureReason {
  markerMissing,
  markerDuplicated,
  malformedPayload,
  unsupportedSchema,
  provenanceMismatch,
  cleanInstallNotVerified,
  deviceIdentityMissing,
  invalidByteCount,
  appBytesUnderreported,
}

/// Typed, privacy-safe rejection of Android storage evidence.
@immutable
final class AndroidStorageMeasurementFailure implements Exception {
  /// Creates a failure with a stable machine-actionable [reason].
  const AndroidStorageMeasurementFailure(this.reason);

  /// Reason the evidence is unusable.
  final AndroidStorageMeasurementFailureReason reason;

  /// Stable diagnostic code that contains no raw instrumentation content.
  String get code => 'release_footprint.android.${reason.name}';

  @override
  String toString() => code;
}

/// Host-observed provenance that the device result must match exactly.
@immutable
final class AndroidStorageMeasurementExpectation {
  /// Creates the expected identity for one clean-install measurement.
  const AndroidStorageMeasurementExpectation({
    required this.packageName,
    required this.versionCode,
    required this.buildId,
    required this.deviceSerial,
    required this.deviceModel,
    required this.buildFingerprint,
    required this.installedApkSha256,
    required this.minimumAppBytes,
    required this.cleanInstallWasVerified,
  });

  /// Expected release package identifier.
  final String packageName;

  /// Expected installed Android version code.
  final int versionCode;

  /// Stable host build identifier supplied to instrumentation.
  final String buildId;

  /// Exact connected ADB serial.
  final String deviceSerial;

  /// Exact target hardware model.
  final String deviceModel;

  /// Exact Android build fingerprint observed by the host.
  final String buildFingerprint;

  /// SHA-256 of the exact release APK installed by the host.
  final String installedApkSha256;

  /// Host-observed byte length of the exact installed APK.
  final int minimumAppBytes;

  /// Whether the host proved absence before installing the target package.
  final bool cleanInstallWasVerified;
}

/// Canonical installed-measurement JSON document consumed by the size CLI.
@immutable
final class AndroidStorageMeasurementDocument {
  /// Creates one document bound to a stable [buildId].
  const AndroidStorageMeasurementDocument({
    required this.buildId,
    required this.measurement,
  });

  /// Stable host release build identifier.
  final String buildId;

  /// Verified device storage evidence.
  final InstalledFootprintMeasurement measurement;

  /// JSON schema accepted by `check_release_footprint.dart`.
  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'schemaVersion': 1,
    'buildId': buildId,
    'packageName': measurement.packageName,
    'versionCode': measurement.versionCode,
    'deviceSerial': measurement.deviceSerial,
    'deviceModel': measurement.deviceModel,
    'buildFingerprint': measurement.buildFingerprint,
    'observedAtUtc': measurement.observedAtUtc,
    'cleanInstall': measurement.cleanInstall,
    'installedApkSha256': measurement.installedApkSha256,
    'appBytes': measurement.appBytes,
    'dataBytes': measurement.dataBytes,
    'cacheBytes': measurement.cacheBytes,
  };
}

/// Parses the one base64url JSON result emitted by Android instrumentation.
AndroidStorageMeasurementDocument parseAndroidStorageMeasurement(
  String instrumentationOutput, {
  required AndroidStorageMeasurementExpectation expectation,
}) {
  final matches = RegExp(
    r'^INSTRUMENTATION_STATUS: loquirisFootprint=([^\r\n]+)$',
    multiLine: true,
  ).allMatches(instrumentationOutput).toList(growable: false);
  if (matches.isEmpty) {
    throw const AndroidStorageMeasurementFailure(
      AndroidStorageMeasurementFailureReason.markerMissing,
    );
  }
  if (matches.length != 1) {
    throw const AndroidStorageMeasurementFailure(
      AndroidStorageMeasurementFailureReason.markerDuplicated,
    );
  }

  final Map<String, Object?> payload;
  try {
    final encoded = matches.single.group(1)!;
    final paddingLength = (4 - encoded.length % 4) % 4;
    final bytes = base64Url.decode('$encoded${'=' * paddingLength}');
    final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('payload is not an object');
    }
    payload = decoded;
  } on FormatException {
    throw const AndroidStorageMeasurementFailure(
      AndroidStorageMeasurementFailureReason.malformedPayload,
    );
  }

  if (payload['schemaVersion'] != 1) {
    throw const AndroidStorageMeasurementFailure(
      AndroidStorageMeasurementFailureReason.unsupportedSchema,
    );
  }
  final packageName = _readString(payload, 'packageName');
  final buildId = _readString(payload, 'buildId');
  final deviceSerial = _readString(payload, 'deviceSerial');
  final deviceModel = _readString(payload, 'deviceModel');
  final buildFingerprint = _readString(payload, 'buildFingerprint');
  final observedAtUtc = _readString(payload, 'observedAtUtc');
  final installedApkSha256 = _readString(payload, 'installedApkSha256');
  final versionCode = _readInteger(payload, 'versionCode');
  final cleanInstall = _readBoolean(payload, 'cleanInstall');
  final appBytes = _readByteCount(payload, 'appBytes');
  final dataBytes = _readByteCount(payload, 'dataBytes');
  final cacheBytes = _readByteCount(payload, 'cacheBytes');

  if (deviceSerial.isEmpty ||
      deviceModel.isEmpty ||
      buildFingerprint.isEmpty ||
      observedAtUtc.isEmpty) {
    throw const AndroidStorageMeasurementFailure(
      AndroidStorageMeasurementFailureReason.deviceIdentityMissing,
    );
  }
  if (!cleanInstall || !expectation.cleanInstallWasVerified) {
    throw const AndroidStorageMeasurementFailure(
      AndroidStorageMeasurementFailureReason.cleanInstallNotVerified,
    );
  }
  if (appBytes > _maxSignedInt64 - dataBytes) {
    throw const AndroidStorageMeasurementFailure(
      AndroidStorageMeasurementFailureReason.invalidByteCount,
    );
  }
  if (appBytes < expectation.minimumAppBytes) {
    throw const AndroidStorageMeasurementFailure(
      AndroidStorageMeasurementFailureReason.appBytesUnderreported,
    );
  }
  if (packageName != expectation.packageName ||
      versionCode != expectation.versionCode ||
      buildId != expectation.buildId ||
      deviceSerial != expectation.deviceSerial ||
      deviceModel != expectation.deviceModel ||
      buildFingerprint != expectation.buildFingerprint ||
      installedApkSha256 != expectation.installedApkSha256) {
    throw const AndroidStorageMeasurementFailure(
      AndroidStorageMeasurementFailureReason.provenanceMismatch,
    );
  }
  final instant = DateTime.tryParse(observedAtUtc);
  if (instant == null || !instant.isUtc) {
    throw const AndroidStorageMeasurementFailure(
      AndroidStorageMeasurementFailureReason.deviceIdentityMissing,
    );
  }

  return AndroidStorageMeasurementDocument(
    buildId: buildId,
    measurement: InstalledFootprintMeasurement(
      packageName: packageName,
      versionCode: versionCode,
      deviceSerial: deviceSerial,
      deviceModel: deviceModel,
      buildFingerprint: buildFingerprint,
      observedAtUtc: observedAtUtc,
      cleanInstall: cleanInstall,
      installedApkSha256: installedApkSha256,
      appBytes: appBytes,
      dataBytes: dataBytes,
      cacheBytes: cacheBytes,
    ),
  );
}

/// Validates raw instrumentation output and writes canonical installed JSON.
Future<int> runAndroidStorageMeasurementAdapter(
  List<String> arguments, {
  required Directory projectRoot,
  required void Function(String) writeOutput,
  required void Function(String) writeError,
}) async {
  try {
    final values = _parseCommandArguments(arguments);
    final rootPath = projectRoot.resolveSymbolicLinksSync();
    final input = _resolveRegularInput(
      rootPath,
      values['--instrumentation-output']!,
    );
    final expectation = AndroidStorageMeasurementExpectation(
      packageName: values['--package-name']!,
      versionCode: _parsePositiveInteger(values['--version-code']!),
      buildId: values['--build-id']!,
      deviceSerial: values['--device-serial']!,
      deviceModel: values['--device-model']!,
      buildFingerprint: values['--build-fingerprint']!,
      installedApkSha256: values['--installed-apk-sha256']!,
      minimumAppBytes: _parsePositiveInteger(values['--minimum-app-bytes']!),
      cleanInstallWasVerified: switch (values['--clean-install-verified']) {
        'true' => true,
        _ => throw const _AdapterCommandFailure(
          'release_footprint.android.clean_install_not_verified',
        ),
      },
    );
    final document = parseAndroidStorageMeasurement(
      await input.readAsString(),
      expectation: expectation,
    );
    final output = _resolveOutput(rootPath, values['--output']!);
    await output.parent.create(recursive: true);
    final temporary = File('${output.path}.tmp');
    final temporaryType = FileSystemEntity.typeSync(
      temporary.path,
      followLinks: false,
    );
    if (temporaryType != FileSystemEntityType.notFound &&
        temporaryType != FileSystemEntityType.file) {
      throw const _AdapterCommandFailure(
        'release_footprint.android.output_not_regular',
      );
    }
    await temporary.writeAsString(
      '${jsonEncode(document.toCanonicalJson())}\n',
      flush: true,
    );
    await temporary.rename(output.path);
    writeOutput('release_footprint.android_measurement_ready');
    return 0;
  } on AndroidStorageMeasurementFailure catch (failure) {
    writeError(failure.code);
    return 65;
  } on _AdapterCommandFailure catch (failure) {
    writeError(failure.code);
    return 64;
  } on FileSystemException {
    writeError('release_footprint.android.io_failed');
    return 74;
  }
}

Map<String, String> _parseCommandArguments(List<String> arguments) {
  const requiredFlags = <String>{
    '--instrumentation-output',
    '--package-name',
    '--version-code',
    '--build-id',
    '--device-serial',
    '--device-model',
    '--build-fingerprint',
    '--installed-apk-sha256',
    '--minimum-app-bytes',
    '--clean-install-verified',
    '--output',
  };
  if (arguments.length != requiredFlags.length * 2) {
    throw const _AdapterCommandFailure(
      'release_footprint.android.usage',
    );
  }
  final values = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    final flag = arguments[index];
    final value = arguments[index + 1];
    if (!requiredFlags.contains(flag) ||
        value.isEmpty ||
        values.containsKey(flag)) {
      throw const _AdapterCommandFailure(
        'release_footprint.android.usage',
      );
    }
    values[flag] = value;
  }
  if (values.keys.toSet().length != requiredFlags.length) {
    throw const _AdapterCommandFailure(
      'release_footprint.android.usage',
    );
  }
  return values;
}

int _parsePositiveInteger(String value) {
  final parsed = int.tryParse(value);
  if (parsed == null || parsed <= 0 || parsed > _maxSignedInt64) {
    throw const _AdapterCommandFailure(
      'release_footprint.android.invalid_version_code',
    );
  }
  return parsed;
}

File _resolveRegularInput(String rootPath, String inputPath) {
  final absolute = path.normalize(
    path.isAbsolute(inputPath) ? inputPath : path.join(rootPath, inputPath),
  );
  if (FileSystemEntity.typeSync(absolute, followLinks: false) !=
      FileSystemEntityType.file) {
    throw const _AdapterCommandFailure(
      'release_footprint.android.input_not_regular',
    );
  }
  final resolved = File(absolute).resolveSymbolicLinksSync();
  if (!path.isWithin(rootPath, resolved)) {
    throw const _AdapterCommandFailure(
      'release_footprint.android.path_outside_project',
    );
  }
  return File(resolved);
}

File _resolveOutput(String rootPath, String outputPath) {
  final absolute = path.normalize(
    path.isAbsolute(outputPath) ? outputPath : path.join(rootPath, outputPath),
  );
  if (!path.isWithin(rootPath, absolute)) {
    throw const _AdapterCommandFailure(
      'release_footprint.android.path_outside_project',
    );
  }
  final type = FileSystemEntity.typeSync(absolute, followLinks: false);
  if (type == FileSystemEntityType.link ||
      (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file)) {
    throw const _AdapterCommandFailure(
      'release_footprint.android.output_not_regular',
    );
  }
  return File(absolute);
}

final class _AdapterCommandFailure implements Exception {
  const _AdapterCommandFailure(this.code);

  final String code;
}

String _readString(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is! String) {
    throw const AndroidStorageMeasurementFailure(
      AndroidStorageMeasurementFailureReason.malformedPayload,
    );
  }
  return value;
}

int _readInteger(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is! int) {
    throw const AndroidStorageMeasurementFailure(
      AndroidStorageMeasurementFailureReason.malformedPayload,
    );
  }
  return value;
}

bool _readBoolean(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is! bool) {
    throw const AndroidStorageMeasurementFailure(
      AndroidStorageMeasurementFailureReason.malformedPayload,
    );
  }
  return value;
}

int _readByteCount(Map<String, Object?> payload, String key) {
  final value = _readInteger(payload, key);
  if (value < 0 || value > _maxSignedInt64) {
    throw const AndroidStorageMeasurementFailure(
      AndroidStorageMeasurementFailureReason.invalidByteCount,
    );
  }
  return value;
}

Future<void> main(List<String> arguments) async {
  exitCode = await runAndroidStorageMeasurementAdapter(
    arguments,
    projectRoot: Directory.current,
    writeOutput: stdout.writeln,
    writeError: stderr.writeln,
  );
}
