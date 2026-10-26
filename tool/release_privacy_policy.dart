import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

const _androidNamespace = 'http://schemas.android.com/apk/res/android';
const _toolsNamespace = 'http://schemas.android.com/tools';
const _remotePermissions = {'INTERNET', 'ACCESS_NETWORK_STATE'};
const _dataExtractionRulesReference = '@xml/data_extraction_rules';
const _backupDomains = <String>{
  'root',
  'file',
  'database',
  'sharedpref',
  'external',
  'device_root',
  'device_file',
  'device_database',
  'device_sharedpref',
};

/// Rejects overlays that disable the explicitly authorized LAN transport.
List<String> validateReleaseManifest(String source) {
  final document = XmlDocument.parse(source);
  final violations = <String>[];
  for (final permission in document.findAllElements('uses-permission')) {
    final name = permission.getAttribute('name', namespace: _androidNamespace);
    if (name != null &&
        _remotePermissions.any(name.endsWith) &&
        permission.getAttribute('node', namespace: _toolsNamespace) ==
            'remove') {
      violations.add(
        '$name must remain available for explicit remote transcription',
      );
    }
  }
  for (final application in document.findAllElements('application')) {
    if (application.getAttribute('node', namespace: _toolsNamespace) ==
        'remove') {
      violations.add('release overlay must not remove the application');
    }
    final cleartext = application.getAttribute(
      'usesCleartextTraffic',
      namespace: _androidNamespace,
    );
    if (cleartext != null && cleartext != 'true') {
      violations.add('authorized LAN HTTP must remain available');
    }
  }
  return violations;
}

/// Verifies explicit remote permissions alongside local backup isolation and LAN HTTP.
List<String> validateMainManifest(String source) {
  final document = XmlDocument.parse(source);
  final violations = <String>[];
  for (final permission in _remotePermissions) {
    final matching = document
        .findAllElements('uses-permission')
        .where(
          (element) =>
              element.getAttribute('name', namespace: _androidNamespace) ==
              'android.permission.$permission',
        );
    if (matching.length != 1) {
      violations.add('$permission must be declared exactly once');
    }
  }
  final applications = document.findAllElements('application').toList();
  if (applications.length != 1 ||
      applications.single.getAttribute(
            'usesCleartextTraffic',
            namespace: _androidNamespace,
          ) !=
          'true') {
    violations.add('application must permit authorized LAN HTTP');
  }
  violations.addAll(validateBackupManifest(source));
  return violations;
}

/// Returns backup and restore policy violations in an application manifest.
List<String> validateBackupManifest(String source) {
  final document = XmlDocument.parse(source);
  final violations = <String>[];
  final applications = document.findAllElements('application').toList();
  if (applications.length != 1) {
    violations.add('manifest must contain exactly one application element');
    return violations;
  }
  final application = applications.single;
  String? androidAttribute(String name) =>
      application.getAttribute(name, namespace: _androidNamespace);
  if (androidAttribute('allowBackup') != 'false') {
    violations.add('application must set android:allowBackup="false"');
  }
  if (androidAttribute('fullBackupContent') != 'false') {
    violations.add(
      'application must set android:fullBackupContent="false"',
    );
  }
  if (androidAttribute('dataExtractionRules') !=
      _dataExtractionRulesReference) {
    violations.add(
      'application android:dataExtractionRules must reference '
      '$_dataExtractionRulesReference',
    );
  }
  if (androidAttribute('backupAgent') != null) {
    violations.add('application must not declare android:backupAgent');
  }
  if (androidAttribute('backupInForeground') == 'true') {
    violations.add(
      'application must not enable android:backupInForeground',
    );
  }
  if (androidAttribute('restoreAnyVersion') == 'true') {
    violations.add('application must not enable android:restoreAnyVersion');
  }
  return violations;
}

/// Returns violations in Android 12+ cloud and device-transfer exclusions.
List<String> validateDataExtractionRules(String source) {
  final document = XmlDocument.parse(source);
  final violations = <String>[];
  final roots = document.findAllElements('data-extraction-rules').toList();
  if (roots.length != 1 || document.rootElement != roots.single) {
    return <String>['rules must contain one data-extraction-rules root'];
  }

  for (final sectionName in <String>['cloud-backup', 'device-transfer']) {
    final sections = roots.single.findElements(sectionName).toList();
    if (sections.length != 1) {
      violations.add('rules must contain exactly one $sectionName section');
      continue;
    }
    final section = sections.single;
    if (section.findElements('include').isNotEmpty) {
      violations.add('$sectionName must not contain include rules');
    }
    for (final domain in _backupDomains) {
      final matching = section
          .findElements('exclude')
          .where(
            (element) =>
                element.getAttribute('domain') == domain &&
                element.getAttribute('path') == '.',
          );
      if (matching.length != 1) {
        violations.add('$sectionName must exclude $domain at path "."');
      }
    }
  }
  return violations;
}

Future<Set<String>> _resolvedDependencies() async {
  final result = await Process.run(
    Platform.resolvedExecutable,
    ['pub', 'deps', '--json'],
  );
  if (result.exitCode != 0) {
    throw StateError('dart pub deps failed');
  }
  final graph = jsonDecode(result.stdout as String) as Map<String, Object?>;
  final packages = graph['packages']! as List<Object?>;
  return packages
      .cast<Map<String, Object?>>()
      .where((package) => package['kind'] != 'root')
      .map((package) => package['name']! as String)
      .toSet();
}

Set<String> _approvedDependencies(String source) {
  return source
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toSet();
}

Future<void> main(List<String> arguments) async {
  final violations = <String>[];
  final manifestPaths = <String>[];
  final backupManifestPaths = <String>[];
  var rulesPath = 'android/app/src/main/res/xml/data_extraction_rules.xml';
  var checkDependencies = true;
  for (var index = 0; index < arguments.length; index += 1) {
    switch (arguments[index]) {
      case '--manifest':
        if (index + 1 >= arguments.length) {
          violations.add('--manifest requires a path');
          continue;
        }
        manifestPaths.add(arguments[index += 1]);
      case '--backup-manifest':
        if (index + 1 >= arguments.length) {
          violations.add('--backup-manifest requires a path');
          continue;
        }
        backupManifestPaths.add(arguments[index += 1]);
      case '--data-extraction-rules':
        if (index + 1 >= arguments.length) {
          violations.add('--data-extraction-rules requires a path');
          continue;
        }
        rulesPath = arguments[index += 1];
      case '--skip-dependencies':
        checkDependencies = false;
      default:
        violations.add('unknown argument: ${arguments[index]}');
    }
  }
  if (manifestPaths.isEmpty && backupManifestPaths.isEmpty) {
    manifestPaths.add('android/app/src/main/AndroidManifest.xml');
  }

  final releaseManifest = File(
    'android/app/src/release/AndroidManifest.xml',
  ).readAsStringSync();
  violations.addAll(validateReleaseManifest(releaseManifest));
  for (final path in manifestPaths) {
    final manifestViolations = validateMainManifest(
      File(path).readAsStringSync(),
    );
    violations.addAll(
      manifestViolations.map((violation) => '$path: $violation'),
    );
  }
  for (final path in backupManifestPaths) {
    final manifestViolations = validateBackupManifest(
      File(path).readAsStringSync(),
    );
    violations.addAll(
      manifestViolations.map((violation) => '$path: $violation'),
    );
  }
  violations.addAll(
    validateDataExtractionRules(File(rulesPath).readAsStringSync()).map(
      (violation) => '$rulesPath: $violation',
    ),
  );

  if (checkDependencies) {
    final resolved = await _resolvedDependencies();
    final approved = _approvedDependencies(
      File(
        'tool/privacy/resolved_dependency_allowlist.txt',
      ).readAsStringSync(),
    );
    final unreviewed = resolved.difference(approved).toList()..sort();
    final stale = approved.difference(resolved).toList()..sort();
    if (unreviewed.isNotEmpty) {
      violations.add(
        'unreviewed resolved dependencies: ${unreviewed.join(', ')}',
      );
    }
    if (stale.isNotEmpty) {
      violations.add('stale dependency approvals: ${stale.join(', ')}');
    }
  }

  if (violations.isNotEmpty) {
    for (final violation in violations) {
      stderr.writeln('privacy gate: $violation');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'privacy gate: structured manifest and dependency policy passed',
  );
}
