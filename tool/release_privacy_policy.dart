import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

const _androidNamespace = 'http://schemas.android.com/apk/res/android';
const _toolsNamespace = 'http://schemas.android.com/tools';
const _forbiddenPermissions = {'INTERNET', 'ACCESS_NETWORK_STATE'};

/// Returns violations in a release manifest overlay.
List<String> validateReleaseManifest(String source) {
  final document = XmlDocument.parse(source);
  final permissions = document.findAllElements('uses-permission');
  final violations = <String>[];

  for (final permission in _forbiddenPermissions) {
    final qualifiedName = 'android.permission.$permission';
    final matching = permissions.where(
      (element) =>
          element.getAttribute('name', namespace: _androidNamespace) ==
          qualifiedName,
    );
    if (matching.length != 1 ||
        matching.single.getAttribute('node', namespace: _toolsNamespace) !=
            'remove') {
      violations.add(
        '$qualifiedName must have exactly one tools:node="remove" element',
      );
    }
  }
  return violations;
}

/// Returns forbidden network permissions declared by the main manifest.
List<String> validateMainManifest(String source) {
  final document = XmlDocument.parse(source);
  final violations = <String>[];
  for (final element in document.findAllElements('uses-permission')) {
    final name = element.getAttribute('name', namespace: _androidNamespace);
    if (name != null && _forbiddenPermissions.any(name.endsWith)) {
      violations.add(name);
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

Future<void> main() async {
  final violations = <String>[];
  final releaseManifest = File(
    'android/app/src/release/AndroidManifest.xml',
  ).readAsStringSync();
  final mainManifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  violations
    ..addAll(validateReleaseManifest(releaseManifest))
    ..addAll(
      validateMainManifest(mainManifest).map(
        (permission) => 'main manifest declares $permission',
      ),
    );

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
