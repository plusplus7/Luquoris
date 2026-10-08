import 'package:meta/meta.dart';

/// Maximum permitted size of each installable release artifact (500 MiB).
const int maxReleaseArtifactBytes = 524288000;

/// Maximum permitted clean installed footprint (800 MiB).
const int maxInstalledFootprintBytes = 838860800;

/// Installable artifact formats measured by the release gate.
enum ReleaseArtifactKind { aab, apk }

/// Final outcome of applying the release-footprint policy.
enum ReleaseFootprintStatus { passed, failed, incomplete }

/// Stable reasons a release-footprint report cannot pass.
enum ReleaseFootprintViolationCode {
  requiredArtifactMissing,
  requiredArtifactDuplicated,
  artifactLabelDuplicated,
  artifactPathDuplicated,
  artifactBudgetExceeded,
  installedMeasurementMissing,
  installedMeasurementUnverified,
  installedApkMismatch,
  installedBudgetExceeded,
}

/// Exact byte and digest evidence for one release artifact.
@immutable
final class ReleaseArtifactMeasurement {
  /// Creates immutable artifact evidence.
  const ReleaseArtifactMeasurement({
    required this.kind,
    required this.label,
    required this.relativePath,
    required this.bytes,
    required this.sha256,
  });

  /// APK or AAB artifact kind.
  final ReleaseArtifactKind kind;

  /// Explicit ABI/variant label, or `release-bundle` for the AAB.
  final String label;

  /// Privacy-safe project-relative artifact path.
  final String relativePath;

  /// Exact regular-file length.
  final int bytes;

  /// Lowercase SHA-256 read from the same stable file contents.
  final String sha256;

  /// Stable machine-readable representation.
  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'kind': kind.name,
    'label': label,
    'relativePath': relativePath,
    'bytes': bytes,
    'sha256': sha256,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReleaseArtifactMeasurement &&
          kind == other.kind &&
          label == other.label &&
          relativePath == other.relativePath &&
          bytes == other.bytes &&
          sha256 == other.sha256;

  @override
  int get hashCode => Object.hash(kind, label, relativePath, bytes, sha256);
}

/// Clean-install storage evidence reported by Android for the release APK.
@immutable
final class InstalledFootprintMeasurement {
  /// Creates immutable installed-footprint evidence.
  const InstalledFootprintMeasurement({
    required this.packageName,
    required this.versionCode,
    required this.deviceSerial,
    required this.deviceModel,
    required this.buildFingerprint,
    required this.observedAtUtc,
    required this.cleanInstall,
    required this.installedApkSha256,
    required this.appBytes,
    required this.dataBytes,
    required this.cacheBytes,
  });

  /// Exact installed package identifier.
  final String packageName;

  /// Installed Android version code.
  final int versionCode;

  /// ADB serial of the measured target device.
  final String deviceSerial;

  /// Android hardware model identifier.
  final String deviceModel;

  /// Full Android build fingerprint.
  final String buildFingerprint;

  /// UTC instant emitted by the device-side measurement helper.
  final String observedAtUtc;

  /// Whether the host workflow proved there was no prior package data.
  final bool cleanInstall;

  /// SHA-256 of the exact APK installed for measurement.
  final String installedApkSha256;

  /// `StorageStats.appBytes` for the package.
  final int appBytes;

  /// `StorageStats.dataBytes` for the package.
  final int dataBytes;

  /// `StorageStats.cacheBytes`, retained as evidence but not double-counted.
  final int cacheBytes;

  /// Policy footprint: application bytes plus private data bytes.
  int get installedBytes => appBytes + dataBytes;

  /// Whether all mandatory provenance demonstrates a clean real measurement.
  bool get isVerified =>
      cleanInstall &&
      packageName.isNotEmpty &&
      versionCode > 0 &&
      deviceSerial.isNotEmpty &&
      deviceModel.isNotEmpty &&
      buildFingerprint.isNotEmpty &&
      observedAtUtc.endsWith('Z') &&
      installedApkSha256.length == 64 &&
      appBytes >= 0 &&
      dataBytes >= 0 &&
      cacheBytes >= 0;

  /// Stable machine-readable representation.
  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'packageName': packageName,
    'versionCode': versionCode,
    'deviceSerial': deviceSerial,
    'deviceModel': deviceModel,
    'buildFingerprint': buildFingerprint,
    'observedAtUtc': observedAtUtc,
    'cleanInstall': cleanInstall,
    'installedApkSha256': installedApkSha256,
    'appBytes': appBytes,
    'dataBytes': dataBytes,
    'cacheBytes': cacheBytes,
    'installedBytes': installedBytes,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstalledFootprintMeasurement &&
          packageName == other.packageName &&
          versionCode == other.versionCode &&
          deviceSerial == other.deviceSerial &&
          deviceModel == other.deviceModel &&
          buildFingerprint == other.buildFingerprint &&
          observedAtUtc == other.observedAtUtc &&
          cleanInstall == other.cleanInstall &&
          installedApkSha256 == other.installedApkSha256 &&
          appBytes == other.appBytes &&
          dataBytes == other.dataBytes &&
          cacheBytes == other.cacheBytes;

  @override
  int get hashCode => Object.hash(
    packageName,
    versionCode,
    deviceSerial,
    deviceModel,
    buildFingerprint,
    observedAtUtc,
    cleanInstall,
    installedApkSha256,
    appBytes,
    dataBytes,
    cacheBytes,
  );
}

/// Complete release artifacts and optional clean-install evidence for a build.
@immutable
final class ReleaseFootprintReport {
  /// Creates a report and canonicalizes artifact order.
  ReleaseFootprintReport({
    required this.schemaVersion,
    required this.buildId,
    required List<ReleaseArtifactMeasurement> artifacts,
    required this.installedMeasurement,
  }) : artifacts = List<ReleaseArtifactMeasurement>.unmodifiable(
         List<ReleaseArtifactMeasurement>.of(artifacts)
           ..sort(_compareArtifacts),
       );

  /// Version of the report schema.
  final int schemaVersion;

  /// Caller-supplied stable release build identifier.
  final String buildId;

  /// Canonically ordered measured artifacts.
  final List<ReleaseArtifactMeasurement> artifacts;

  /// Target-device evidence, absent until a real clean install is measured.
  final InstalledFootprintMeasurement? installedMeasurement;

  /// Stable machine-readable representation.
  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'buildId': buildId,
    'limits': <String, Object?>{
      'releaseArtifactBytes': maxReleaseArtifactBytes,
      'installedFootprintBytes': maxInstalledFootprintBytes,
    },
    'artifacts': artifacts
        .map((artifact) => artifact.toCanonicalJson())
        .toList(growable: false),
    'installedMeasurement': installedMeasurement?.toCanonicalJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReleaseFootprintReport &&
          schemaVersion == other.schemaVersion &&
          buildId == other.buildId &&
          _listEquals(artifacts, other.artifacts) &&
          installedMeasurement == other.installedMeasurement;

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    buildId,
    Object.hashAll(artifacts),
    installedMeasurement,
  );
}

/// One stable policy violation with optional exact byte evidence.
@immutable
final class ReleaseFootprintViolation {
  /// Creates a violation.
  const ReleaseFootprintViolation({
    required this.code,
    this.subject,
    this.measuredBytes,
    this.limitBytes,
  });

  /// Machine-actionable failure category.
  final ReleaseFootprintViolationCode code;

  /// Privacy-safe artifact label when one item caused the violation.
  final String? subject;

  /// Exact observed count when relevant.
  final int? measuredBytes;

  /// Exact permitted count when relevant.
  final int? limitBytes;

  /// Stable machine-readable representation.
  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'code': code.name,
    if (subject != null) 'subject': subject,
    if (measuredBytes != null) 'measuredBytes': measuredBytes,
    if (limitBytes != null) 'limitBytes': limitBytes,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReleaseFootprintViolation &&
          code == other.code &&
          subject == other.subject &&
          measuredBytes == other.measuredBytes &&
          limitBytes == other.limitBytes;

  @override
  int get hashCode => Object.hash(code, subject, measuredBytes, limitBytes);
}

/// Typed result of evaluating one complete or partial footprint report.
@immutable
final class ReleaseFootprintDecision {
  /// Creates an immutable policy decision.
  ReleaseFootprintDecision({
    required this.status,
    required List<ReleaseFootprintViolation> violations,
  }) : violations = List<ReleaseFootprintViolation>.unmodifiable(violations);

  /// Pass, fail, or incomplete evidence status.
  final ReleaseFootprintStatus status;

  /// Canonically ordered reasons the report did not pass.
  final List<ReleaseFootprintViolation> violations;

  /// Stable machine-readable representation.
  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'status': status.name,
    'violations': violations
        .map((violation) => violation.toCanonicalJson())
        .toList(growable: false),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReleaseFootprintDecision &&
          status == other.status &&
          _listEquals(violations, other.violations);

  @override
  int get hashCode => Object.hash(status, Object.hashAll(violations));
}

/// Applies exact-byte release and installed-footprint limits without I/O.
ReleaseFootprintDecision evaluateReleaseFootprint(
  ReleaseFootprintReport report,
) {
  final violations = <ReleaseFootprintViolation>[];
  final aabCount = report.artifacts
      .where((artifact) => artifact.kind == ReleaseArtifactKind.aab)
      .length;
  final apkCount = report.artifacts
      .where((artifact) => artifact.kind == ReleaseArtifactKind.apk)
      .length;

  if (aabCount == 0) {
    violations.add(
      const ReleaseFootprintViolation(
        code: ReleaseFootprintViolationCode.requiredArtifactMissing,
        subject: 'aab',
      ),
    );
  } else if (aabCount > 1) {
    violations.add(
      const ReleaseFootprintViolation(
        code: ReleaseFootprintViolationCode.requiredArtifactDuplicated,
        subject: 'aab',
      ),
    );
  }
  if (apkCount == 0) {
    violations.add(
      const ReleaseFootprintViolation(
        code: ReleaseFootprintViolationCode.requiredArtifactMissing,
        subject: 'apk',
      ),
    );
  }

  _addDuplicateViolations(report.artifacts, violations);
  for (final artifact in report.artifacts) {
    if (artifact.bytes > maxReleaseArtifactBytes) {
      violations.add(
        ReleaseFootprintViolation(
          code: ReleaseFootprintViolationCode.artifactBudgetExceeded,
          subject: artifact.label,
          measuredBytes: artifact.bytes,
          limitBytes: maxReleaseArtifactBytes,
        ),
      );
    }
  }

  final installed = report.installedMeasurement;
  if (installed == null) {
    violations.add(
      const ReleaseFootprintViolation(
        code: ReleaseFootprintViolationCode.installedMeasurementMissing,
      ),
    );
  } else {
    if (!installed.isVerified) {
      violations.add(
        const ReleaseFootprintViolation(
          code: ReleaseFootprintViolationCode.installedMeasurementUnverified,
        ),
      );
    }
    final installedApkMatches = report.artifacts.any(
      (artifact) =>
          artifact.kind == ReleaseArtifactKind.apk &&
          artifact.sha256 == installed.installedApkSha256,
    );
    if (!installedApkMatches) {
      violations.add(
        const ReleaseFootprintViolation(
          code: ReleaseFootprintViolationCode.installedApkMismatch,
        ),
      );
    }
    if (installed.installedBytes > maxInstalledFootprintBytes) {
      violations.add(
        ReleaseFootprintViolation(
          code: ReleaseFootprintViolationCode.installedBudgetExceeded,
          measuredBytes: installed.installedBytes,
          limitBytes: maxInstalledFootprintBytes,
        ),
      );
    }
  }

  violations.sort(_compareViolations);
  final hasHardFailure = violations.any(
    (violation) => switch (violation.code) {
      ReleaseFootprintViolationCode.installedMeasurementMissing ||
      ReleaseFootprintViolationCode.installedMeasurementUnverified ||
      ReleaseFootprintViolationCode.requiredArtifactMissing => false,
      _ => true,
    },
  );
  return ReleaseFootprintDecision(
    status: violations.isEmpty
        ? ReleaseFootprintStatus.passed
        : hasHardFailure
        ? ReleaseFootprintStatus.failed
        : ReleaseFootprintStatus.incomplete,
    violations: violations,
  );
}

int _compareArtifacts(
  ReleaseArtifactMeasurement left,
  ReleaseArtifactMeasurement right,
) {
  final kind = left.kind.index.compareTo(right.kind.index);
  return kind != 0 ? kind : left.label.compareTo(right.label);
}

void _addDuplicateViolations(
  List<ReleaseArtifactMeasurement> artifacts,
  List<ReleaseFootprintViolation> violations,
) {
  final labels = <String>{};
  final paths = <String>{};
  for (final artifact in artifacts) {
    if (!labels.add(artifact.label)) {
      violations.add(
        ReleaseFootprintViolation(
          code: ReleaseFootprintViolationCode.artifactLabelDuplicated,
          subject: artifact.label,
        ),
      );
    }
    if (!paths.add(artifact.relativePath)) {
      violations.add(
        ReleaseFootprintViolation(
          code: ReleaseFootprintViolationCode.artifactPathDuplicated,
          subject: artifact.label,
        ),
      );
    }
  }
}

int _compareViolations(
  ReleaseFootprintViolation left,
  ReleaseFootprintViolation right,
) {
  final code = left.code.index.compareTo(right.code.index);
  return code != 0 ? code : (left.subject ?? '').compareTo(right.subject ?? '');
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
