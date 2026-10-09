import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

/// Kinds of shipped inputs represented in the notice inventory.
enum NoticeComponentKind {
  /// A Dart or Flutter package selected from `pubspec.lock`.
  dartPackage,

  /// An Android artifact resolved from `releaseRuntimeClasspath`.
  androidArtifact,

  /// A pinned native source archive built into the application.
  nativeSource,

  /// A separately licensed on-device model artifact.
  model,

  /// A separately licensed benchmark media asset.
  benchmarkAsset,
}

/// Stable reasons inventory input cannot be trusted.
enum NoticeInventoryFailureReason {
  /// A required input is absent or is not a regular file.
  inputMissing,

  /// JSON or lock-file syntax cannot be decoded.
  malformedInput,

  /// Required provenance or immutable identity metadata is invalid.
  invalidMetadata,

  /// Two shipped inputs claim the same component identity.
  duplicateComponent,

  /// An input could not be read.
  ioFailure,
}

/// Privacy-safe failure raised while collecting or validating notices.
@immutable
final class NoticeInventoryFailure implements Exception {
  /// Creates a failure with a stable [reason].
  const NoticeInventoryFailure(this.reason);

  /// Stable machine-actionable failure category.
  final NoticeInventoryFailureReason reason;

  /// Privacy-safe diagnostic code.
  String get code => 'third_party_notices.inventory.${reason.name}';

  @override
  String toString() => code;
}

/// Fixed inputs used to build one release notice inventory.
@immutable
final class NoticeInventoryRequest {
  /// Creates a request from explicit, local-only inputs.
  const NoticeInventoryRequest({
    required this.projectRoot,
    required this.pubspecLock,
    required this.dartPackageGraph,
    required this.androidReleaseInventory,
    required this.nativeSourceManifestDirectory,
    required this.modelManifestDirectory,
    required this.benchmarkManifest,
  });

  /// Uses the canonical project-relative input locations.
  factory NoticeInventoryRequest.fromProjectRoot(Directory projectRoot) =>
      NoticeInventoryRequest(
        projectRoot: projectRoot,
        pubspecLock: File(path.join(projectRoot.path, 'pubspec.lock')),
        dartPackageGraph: File(
          path.join(projectRoot.path, '.dart_tool', 'package_graph.json'),
        ),
        androidReleaseInventory: File(
          path.join(
            projectRoot.path,
            'build',
            'third_party_notices',
            'android_release_dependencies.json',
          ),
        ),
        nativeSourceManifestDirectory: Directory(
          path.join(projectRoot.path, 'third_party'),
        ),
        modelManifestDirectory: Directory(
          path.join(projectRoot.path, 'models', 'manifests'),
        ),
        benchmarkManifest: File(
          path.join(
            projectRoot.path,
            'assets',
            'benchmarks',
            'audio',
            'manifest.json',
          ),
        ),
      );

  /// Root against which committed license paths are resolved.
  final Directory projectRoot;

  /// Exact Dart dependency lock file.
  final File pubspecLock;

  /// Pub-generated graph used to exclude dev-only transitive packages.
  final File dartPackageGraph;

  /// Generated Android release-runtime inventory.
  final File androidReleaseInventory;

  /// Optional directory of committed native-source provenance manifests.
  final Directory nativeSourceManifestDirectory;

  /// Optional directory of committed model manifests.
  final Directory modelManifestDirectory;

  /// Fixed benchmark-media provenance manifest.
  final File benchmarkManifest;
}

/// One immutable shipped input requiring release review.
@immutable
final class NoticeComponent {
  /// Creates one canonical inventory component.
  const NoticeComponent({
    required this.kind,
    required this.name,
    required this.version,
    required this.source,
    required this.artifactSha256,
    required this.licenseId,
    required this.licenseSnapshotPath,
    required this.licenseTextSha256,
  });

  /// Input category.
  final NoticeComponentKind kind;

  /// Stable package, coordinate, model, or media identifier.
  final String name;

  /// Exact locked version or immutable manifest revision.
  final String version;

  /// Local provenance source without discovered license guesses.
  final String source;

  /// SHA-256 of shipped bytes when the upstream lock provides one.
  final String? artifactSha256;

  /// License identifier asserted by a model or media manifest, if present.
  final String? licenseId;

  /// Existing manifest-owned license snapshot, if present.
  final String? licenseSnapshotPath;

  /// SHA-256 of the manifest-owned license snapshot, if present.
  final String? licenseTextSha256;

  /// Exact approval lookup key.
  String get key => '${kind.name}:$name@$version';

  /// Returns a copy with selected identity fields replaced.
  NoticeComponent copyWith({
    String? name,
    String? version,
  }) => NoticeComponent(
    kind: kind,
    name: name ?? this.name,
    version: version ?? this.version,
    source: source,
    artifactSha256: artifactSha256,
    licenseId: licenseId,
    licenseSnapshotPath: licenseSnapshotPath,
    licenseTextSha256: licenseTextSha256,
  );

  /// Deterministic JSON representation.
  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'kind': kind.name,
    'name': name,
    'version': version,
    'source': source,
    'artifactSha256': artifactSha256,
    'licenseId': licenseId,
    'licenseSnapshotPath': licenseSnapshotPath,
    'licenseTextSha256': licenseTextSha256,
  };
}

/// Canonically ordered collection of every shipped release input.
@immutable
final class NoticeInventory {
  NoticeInventory._(List<NoticeComponent> components)
    : components = List<NoticeComponent>.unmodifiable(components);

  /// Collects inputs without network access or license inference.
  static Future<NoticeInventory> collect(NoticeInventoryRequest request) async {
    try {
      final components = <NoticeComponent>[
        ...await _collectDartPackages(
          request.pubspecLock,
          request.dartPackageGraph,
        ),
        ...await _collectAndroidArtifacts(request.androidReleaseInventory),
        ...await _collectNativeSources(request),
        ...await _collectModels(request),
        await _collectBenchmark(request),
      ]..sort(_compareComponents);
      final keys = <String>{};
      for (final component in components) {
        if (!keys.add(component.key)) {
          throw const NoticeInventoryFailure(
            NoticeInventoryFailureReason.duplicateComponent,
          );
        }
      }
      return NoticeInventory._(components);
    } on NoticeInventoryFailure {
      rethrow;
    } on FormatException {
      throw const NoticeInventoryFailure(
        NoticeInventoryFailureReason.malformedInput,
      );
    } on FileSystemException {
      throw const NoticeInventoryFailure(
        NoticeInventoryFailureReason.ioFailure,
      );
    }
  }

  /// Components ordered by kind, name, and exact version.
  final List<NoticeComponent> components;

  /// Deterministic machine-readable inventory.
  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'schemaVersion': 1,
    'components': components
        .map((component) => component.toCanonicalJson())
        .toList(growable: false),
  };
}

/// Human-reviewed approval for one exact component identity.
@immutable
final class NoticeApproval {
  const NoticeApproval({
    required this.kind,
    required this.name,
    required this.version,
    required this.artifactSha256,
    required this.licenseId,
    required this.licensePath,
    required this.licenseTextSha256,
    required this.redistribution,
    required this.approvedBy,
    required this.approvedAt,
  });

  /// Approved input category.
  final NoticeComponentKind kind;

  /// Approved stable input identifier.
  final String name;

  /// Approved exact version.
  final String version;

  /// Approved shipped artifact digest, when available.
  final String? artifactSha256;

  /// Human-reviewed license identifier.
  final String licenseId;

  /// Committed immutable license snapshot.
  final String licensePath;

  /// Digest of the exact approved license text.
  final String licenseTextSha256;

  /// Reviewed redistribution or attribution obligation.
  final String redistribution;

  /// Identity recorded by explicit human approval.
  final String approvedBy;

  /// ISO date on which the exact entry was approved.
  final String approvedAt;

  /// Exact inventory lookup key.
  String get key => '${kind.name}:$name@$version';

  /// Deterministic machine-readable approval.
  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'kind': kind.name,
    'name': name,
    'version': version,
    'artifactSha256': artifactSha256,
    'licenseId': licenseId,
    'licensePath': licensePath,
    'licenseTextSha256': licenseTextSha256,
    'redistribution': redistribution,
    'approvedBy': approvedBy,
    'approvedAt': approvedAt,
  };
}

/// Validated immutable approval catalog.
@immutable
final class NoticeApprovalCatalog {
  NoticeApprovalCatalog._(List<NoticeApproval> approvals)
    : approvals = List<NoticeApproval>.unmodifiable(approvals);

  /// Decodes and validates the versioned approval catalog.
  factory NoticeApprovalCatalog.fromJson(Map<String, Object?> json) {
    if (json.keys.toSet().difference(const <String>{
          'schemaVersion',
          'components',
        }).isNotEmpty ||
        json['schemaVersion'] != 1 ||
        json['components'] is! List<Object?>) {
      throw const NoticeInventoryFailure(
        NoticeInventoryFailureReason.invalidMetadata,
      );
    }
    final approvals = <NoticeApproval>[];
    final keys = <String>{};
    for (final value in json['components']! as List<Object?>) {
      if (value is! Map<String, Object?>) {
        throw const NoticeInventoryFailure(
          NoticeInventoryFailureReason.invalidMetadata,
        );
      }
      final approval = _parseApproval(value);
      if (!keys.add(approval.key)) {
        throw const NoticeInventoryFailure(
          NoticeInventoryFailureReason.duplicateComponent,
        );
      }
      approvals.add(approval);
    }
    approvals.sort((left, right) => left.key.compareTo(right.key));
    return NoticeApprovalCatalog._(approvals);
  }

  /// Approved components in canonical key order.
  final List<NoticeApproval> approvals;

  /// Deterministic machine-readable catalog.
  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'schemaVersion': 1,
    'components': approvals
        .map((approval) => approval.toCanonicalJson())
        .toList(growable: false),
  };
}

/// Stable reasons an inventory and its approval catalog do not reconcile.
enum NoticeReviewIssueReason {
  /// A shipped component has no exact approval entry.
  missingApproval,

  /// An approval no longer matches any shipped component.
  staleApproval,

  /// The shipped artifact digest changed under an approved identity.
  artifactHashMismatch,

  /// Manifest-owned license metadata differs from the approval.
  licenseMetadataMismatch,

  /// The approved license snapshot is absent.
  licenseSnapshotMissing,

  /// The approved license text changed after review.
  licenseTextHashMismatch,
}

/// One privacy-safe notice review issue.
@immutable
final class NoticeReviewIssue {
  /// Creates a stable issue for [componentKey].
  const NoticeReviewIssue({
    required this.reason,
    required this.componentKey,
  });

  /// Mismatch category.
  final NoticeReviewIssueReason reason;

  /// Non-sensitive component identity.
  final String componentKey;

  /// Deterministic JSON representation.
  Map<String, Object?> toCanonicalJson() => <String, Object?>{
    'reason': reason.name,
    'componentKey': componentKey,
  };
}

/// Reconciliation of a complete inventory with explicit approvals.
@immutable
final class NoticeReview {
  NoticeReview._({
    required this.inventory,
    required this.approvals,
    required List<NoticeReviewIssue> issues,
  }) : issues = List<NoticeReviewIssue>.unmodifiable(issues);

  /// Evaluates approval drift and immutable license snapshots.
  static Future<NoticeReview> evaluate({
    required NoticeInventory inventory,
    required NoticeApprovalCatalog approvals,
    required Directory projectRoot,
  }) async {
    final issues = <NoticeReviewIssue>[];
    final componentsByKey = <String, NoticeComponent>{
      for (final component in inventory.components) component.key: component,
    };
    final approvalsByKey = <String, NoticeApproval>{
      for (final approval in approvals.approvals) approval.key: approval,
    };

    for (final component in inventory.components) {
      final approval = approvalsByKey[component.key];
      if (approval == null) {
        issues.add(
          NoticeReviewIssue(
            reason: NoticeReviewIssueReason.missingApproval,
            componentKey: component.key,
          ),
        );
        continue;
      }
      if (component.artifactSha256 != approval.artifactSha256) {
        issues.add(
          NoticeReviewIssue(
            reason: NoticeReviewIssueReason.artifactHashMismatch,
            componentKey: component.key,
          ),
        );
      }
      if ((component.licenseId != null &&
              component.licenseId != approval.licenseId) ||
          (component.licenseTextSha256 != null &&
              component.licenseTextSha256 != approval.licenseTextSha256)) {
        issues.add(
          NoticeReviewIssue(
            reason: NoticeReviewIssueReason.licenseMetadataMismatch,
            componentKey: component.key,
          ),
        );
      }
      final licenseFile = _safeProjectFile(
        projectRoot,
        approval.licensePath,
        requiredPrefix: 'tool/third_party_notices/licenses',
      );
      if (!_isRegularFile(licenseFile)) {
        issues.add(
          NoticeReviewIssue(
            reason: NoticeReviewIssueReason.licenseSnapshotMissing,
            componentKey: component.key,
          ),
        );
      } else {
        final digest = sha256
            .convert(await licenseFile.readAsBytes())
            .toString();
        if (digest != approval.licenseTextSha256) {
          issues.add(
            NoticeReviewIssue(
              reason: NoticeReviewIssueReason.licenseTextHashMismatch,
              componentKey: component.key,
            ),
          );
        }
      }
    }
    for (final approval in approvals.approvals) {
      if (!componentsByKey.containsKey(approval.key)) {
        issues.add(
          NoticeReviewIssue(
            reason: NoticeReviewIssueReason.staleApproval,
            componentKey: approval.key,
          ),
        );
      }
    }
    issues.sort((left, right) {
      final byKey = left.componentKey.compareTo(right.componentKey);
      return byKey != 0 ? byKey : left.reason.name.compareTo(right.reason.name);
    });
    return NoticeReview._(
      inventory: inventory,
      approvals: approvals,
      issues: issues,
    );
  }

  /// Complete shipped inventory.
  final NoticeInventory inventory;

  /// Exact approval catalog evaluated against [inventory].
  final NoticeApprovalCatalog approvals;

  /// Canonically ordered approval and snapshot mismatches.
  final List<NoticeReviewIssue> issues;

  /// Whether every current input is approved and no stale approval remains.
  bool get isApproved => issues.isEmpty;

  /// Candidate report retaining approved and unreviewed inputs.
  Map<String, Object?> toCandidateJson() {
    final approvalKeys = approvals.approvals
        .map((approval) => approval.key)
        .toSet();
    return <String, Object?>{
      'schemaVersion': 1,
      'status': isApproved ? 'approved' : 'reviewRequired',
      'components': inventory.components
          .map(
            (component) => <String, Object?>{
              ...component.toCanonicalJson(),
              'approvalStatus': approvalKeys.contains(component.key)
                  ? 'present'
                  : 'missing',
            },
          )
          .toList(growable: false),
      'issues': issues
          .map((issue) => issue.toCanonicalJson())
          .toList(growable: false),
    };
  }

  /// Human-readable candidate retaining every unreviewed component and issue.
  String renderCandidateMarkdown() {
    final approvalsByKey = <String, NoticeApproval>{
      for (final approval in approvals.approvals) approval.key: approval,
    };
    final buffer = StringBuffer()
      ..writeln('# Third-Party Notice Review Candidate')
      ..writeln()
      ..writeln(
        'Status: ${isApproved ? 'approved' : 'review required'} '
        '(${inventory.components.length} components, ${issues.length} issues).',
      )
      ..writeln();
    for (final component in inventory.components) {
      final approval = approvalsByKey[component.key];
      buffer
        ..writeln(
          '## ${component.kind.name}: ${component.name} @ ${component.version}',
        )
        ..writeln()
        ..writeln('- Source: `${component.source}`')
        ..writeln(
          '- Artifact SHA-256: `${component.artifactSha256 ?? 'unavailable'}`',
        )
        ..writeln(
          '- Manifest license: `${component.licenseId ?? 'unresolved'}`',
        )
        ..writeln('- Approval: ${approval == null ? 'missing' : 'present'}')
        ..writeln();
    }
    if (issues.isNotEmpty) {
      buffer
        ..writeln('## Review blockers')
        ..writeln();
      for (final issue in issues) {
        buffer.writeln('- `${issue.reason.name}`: `${issue.componentKey}`');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// Renders the final notice from exact approved snapshots.
  ///
  /// Callers must reject [isApproved] == `false` before invoking this method.
  Future<String> renderReviewedNotices(Directory projectRoot) async {
    if (!isApproved) {
      throw StateError('review is incomplete');
    }
    final approvalsByKey = <String, NoticeApproval>{
      for (final approval in approvals.approvals) approval.key: approval,
    };
    final buffer = StringBuffer()
      ..writeln('# Third-Party Notices')
      ..writeln()
      ..writeln(
        'This file is generated from exact release inputs and explicitly '
        'approved license snapshots.',
      )
      ..writeln();
    for (final component in inventory.components) {
      final approval = approvalsByKey[component.key]!;
      final licenseFile = _safeProjectFile(
        projectRoot,
        approval.licensePath,
        requiredPrefix: 'tool/third_party_notices/licenses',
      );
      final licenseText = utf8.decode(
        await licenseFile.readAsBytes(),
        allowMalformed: false,
      );
      buffer
        ..writeln('## ${component.name} ${component.version}')
        ..writeln()
        ..writeln('- Kind: `${component.kind.name}`')
        ..writeln('- Source: `${component.source}`')
        ..writeln(
          '- Artifact SHA-256: `${component.artifactSha256 ?? 'unavailable'}`',
        )
        ..writeln('- License: `${approval.licenseId}`')
        ..writeln(
          '- Approved by: `${approval.approvedBy}` on `${approval.approvedAt}`',
        )
        ..writeln('- Redistribution: ${approval.redistribution}')
        ..writeln()
        ..writeln('### License text')
        ..writeln()
        ..write(licenseText);
      if (!licenseText.endsWith('\n')) {
        buffer.writeln();
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}

Future<List<NoticeComponent>> _collectDartPackages(
  File lockFile,
  File packageGraphFile,
) async {
  _requireRegularFile(lockFile);
  final lines = const LineSplitter().convert(await lockFile.readAsString());
  final packagesIndex = lines.indexWhere((line) => line == 'packages:');
  if (packagesIndex < 0 ||
      lines.skip(packagesIndex + 1).any((line) => line == 'packages:')) {
    throw const NoticeInventoryFailure(
      NoticeInventoryFailureReason.malformedInput,
    );
  }
  final packages = <NoticeComponent>[];
  String? name;
  String? dependency;
  String? source;
  String? version;
  String? packageSha256;
  String? sourceUrl;
  String? scalarDescription;

  void finishPackage() {
    if (name == null) {
      return;
    }
    final exactName = _requiredString(name);
    _requiredString(dependency);
    final exactSource = _requiredString(source);
    final exactVersion = _requiredString(version);
    if (!_isExactVersion(exactVersion)) {
      throw const NoticeInventoryFailure(
        NoticeInventoryFailureReason.invalidMetadata,
      );
    }
    final digest = packageSha256 == null
        ? null
        : _requiredSha256(packageSha256);
    if (exactSource == 'hosted' && digest == null) {
      throw const NoticeInventoryFailure(
        NoticeInventoryFailureReason.invalidMetadata,
      );
    }
    final provenance = switch (exactSource) {
      'hosted' => 'hosted:${_requiredString(sourceUrl)}',
      'sdk' => 'sdk:${_requiredString(scalarDescription)}',
      _ => '$exactSource:${scalarDescription ?? sourceUrl ?? exactName}',
    };
    packages.add(
      NoticeComponent(
        kind: NoticeComponentKind.dartPackage,
        name: exactName,
        version: exactVersion,
        source: provenance,
        artifactSha256: digest,
        licenseId: null,
        licenseSnapshotPath: null,
        licenseTextSha256: null,
      ),
    );
  }

  for (final line in <String>[
    ...lines.skip(packagesIndex + 1),
    '  __end__:',
  ]) {
    final header = RegExp(r'^  ([^\s][^:]*):$').firstMatch(line);
    if (header != null) {
      finishPackage();
      name = header.group(1);
      dependency = null;
      source = null;
      version = null;
      packageSha256 = null;
      sourceUrl = null;
      scalarDescription = null;
      continue;
    }
    if (name == null) {
      continue;
    }
    final field = RegExp(r'^    ([a-zA-Z]+):\s*(.*)$').firstMatch(line);
    if (field != null) {
      final value = _unquote(field.group(2)!);
      switch (field.group(1)) {
        case 'dependency':
          dependency = value;
        case 'source':
          source = value;
        case 'version':
          version = value;
        case 'description':
          if (value.isNotEmpty) {
            scalarDescription = value;
          }
      }
      continue;
    }
    final descriptionField = RegExp(
      r'^      ([a-zA-Z0-9_]+):\s*(.*)$',
    ).firstMatch(line);
    if (descriptionField != null) {
      final value = _unquote(descriptionField.group(2)!);
      switch (descriptionField.group(1)) {
        case 'sha256':
          packageSha256 = value;
        case 'url':
          sourceUrl = value;
      }
    }
  }
  final runtimeGraph = await _readDartRuntimeGraph(packageGraphFile);
  final packagesByName = <String, NoticeComponent>{
    for (final component in packages) component.name: component,
  };
  final runtimePackages = <NoticeComponent>[];
  for (final name in runtimeGraph.names) {
    final component = packagesByName[name];
    if (component == null || runtimeGraph.versions[name] != component.version) {
      throw const NoticeInventoryFailure(
        NoticeInventoryFailureReason.invalidMetadata,
      );
    }
    runtimePackages.add(component);
  }
  return runtimePackages;
}

final class _DartRuntimeGraph {
  const _DartRuntimeGraph(this.names, this.versions);

  final Set<String> names;
  final Map<String, String> versions;
}

Future<_DartRuntimeGraph> _readDartRuntimeGraph(File graphFile) async {
  final graph = await _readJsonMap(graphFile);
  final roots = graph['roots'];
  final packages = graph['packages'];
  if (roots is! List<Object?> ||
      roots.isEmpty ||
      packages is! List<Object?> ||
      roots.any((root) => root is! String)) {
    throw const NoticeInventoryFailure(
      NoticeInventoryFailureReason.invalidMetadata,
    );
  }
  final dependenciesByName = <String, List<String>>{};
  final versions = <String, String>{};
  for (final value in packages) {
    if (value is! Map<String, Object?> ||
        value['dependencies'] is! List<Object?>) {
      throw const NoticeInventoryFailure(
        NoticeInventoryFailureReason.invalidMetadata,
      );
    }
    final name = _requiredString(value['name']);
    final version = _requiredString(value['version']);
    final dependencies = value['dependencies']! as List<Object?>;
    if (dependencies.any((dependency) => dependency is! String) ||
        dependenciesByName.containsKey(name)) {
      throw const NoticeInventoryFailure(
        NoticeInventoryFailureReason.invalidMetadata,
      );
    }
    dependenciesByName[name] = dependencies.cast<String>();
    versions[name] = version;
  }
  final rootNames = roots.cast<String>();
  final pending = <String>[
    for (final root in rootNames) ...?dependenciesByName[root],
  ];
  if (pending.isEmpty &&
      rootNames.any((root) => !dependenciesByName.containsKey(root))) {
    throw const NoticeInventoryFailure(
      NoticeInventoryFailureReason.invalidMetadata,
    );
  }
  final runtimeNames = <String>{};
  while (pending.isNotEmpty) {
    final name = pending.removeLast();
    if (!runtimeNames.add(name)) {
      continue;
    }
    final dependencies = dependenciesByName[name];
    if (dependencies == null) {
      throw const NoticeInventoryFailure(
        NoticeInventoryFailureReason.invalidMetadata,
      );
    }
    pending.addAll(dependencies);
  }
  final runtimeVersions = <String, String>{
    for (final name in runtimeNames) name: _requiredString(versions[name]),
  };
  return _DartRuntimeGraph(runtimeNames, runtimeVersions);
}

Future<List<NoticeComponent>> _collectAndroidArtifacts(
  File inventoryFile,
) async {
  final json = await _readJsonMap(inventoryFile);
  if (json['schemaVersion'] != 1 ||
      json['configuration'] != 'releaseRuntimeClasspath' ||
      json['artifacts'] is! List<Object?>) {
    throw const NoticeInventoryFailure(
      NoticeInventoryFailureReason.invalidMetadata,
    );
  }
  final components = <NoticeComponent>[];
  for (final value in json['artifacts']! as List<Object?>) {
    if (value is! Map<String, Object?>) {
      throw const NoticeInventoryFailure(
        NoticeInventoryFailureReason.invalidMetadata,
      );
    }
    final group = _requiredString(value['group']);
    final name = _requiredString(value['name']);
    final version = _requiredString(value['version']);
    final extension = _requiredString(value['extension']);
    final classifier = value['classifier'];
    if (!_isExactVersion(version) ||
        (classifier != null && classifier is! String) ||
        value['bytes'] is! int ||
        (value['bytes']! as int) <= 0) {
      throw const NoticeInventoryFailure(
        NoticeInventoryFailureReason.invalidMetadata,
      );
    }
    final suffix = classifier is String && classifier.isNotEmpty
        ? ':$classifier@$extension'
        : '';
    final expectedCoordinate = '$group:$name:$version$suffix';
    if (value['coordinate'] != expectedCoordinate) {
      throw const NoticeInventoryFailure(
        NoticeInventoryFailureReason.invalidMetadata,
      );
    }
    components.add(
      NoticeComponent(
        kind: NoticeComponentKind.androidArtifact,
        name: '$group:$name${suffix.isEmpty ? '' : ':$classifier@$extension'}',
        version: version,
        source: 'releaseRuntimeClasspath',
        artifactSha256: _requiredSha256(value['sha256']),
        licenseId: null,
        licenseSnapshotPath: null,
        licenseTextSha256: null,
      ),
    );
  }
  return components;
}

Future<List<NoticeComponent>> _collectModels(
  NoticeInventoryRequest request,
) async {
  if (!request.modelManifestDirectory.existsSync()) {
    return const <NoticeComponent>[];
  }
  final manifestFiles =
      request.modelManifestDirectory
          .listSync(followLinks: false)
          .whereType<File>()
          .where((file) => path.extension(file.path) == '.json')
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));
  final components = <NoticeComponent>[];
  for (final manifestFile in manifestFiles) {
    final manifest = await _readJsonMap(manifestFile);
    final id = _requiredString(manifest['id']);
    final version = _requiredString(manifest['version']);
    final source = _requiredString(manifest['source']);
    final license = manifest['license'];
    if (manifest['schemaVersion'] != 1 ||
        !_isExactVersion(version) ||
        !source.startsWith('https://') ||
        _looksMutable(source) ||
        license is! Map<String, Object?>) {
      throw const NoticeInventoryFailure(
        NoticeInventoryFailureReason.invalidMetadata,
      );
    }
    final licenseId = _requiredString(license['id']);
    final licensePath = _requiredSafePath(
      license['snapshotPath'],
      requiredPrefix: 'models/licenses',
    );
    final licenseFile = _safeProjectFile(
      request.projectRoot,
      licensePath,
      requiredPrefix: 'models/licenses',
    );
    _requireRegularFile(licenseFile);
    components.add(
      NoticeComponent(
        kind: NoticeComponentKind.model,
        name: id,
        version: version,
        source: source,
        artifactSha256: _requiredSha256(manifest['sha256']),
        licenseId: licenseId,
        licenseSnapshotPath: licensePath,
        licenseTextSha256: sha256
            .convert(await licenseFile.readAsBytes())
            .toString(),
      ),
    );
  }
  return components;
}

Future<List<NoticeComponent>> _collectNativeSources(
  NoticeInventoryRequest request,
) async {
  if (!request.nativeSourceManifestDirectory.existsSync()) {
    return const <NoticeComponent>[];
  }
  final manifestFiles =
      request.nativeSourceManifestDirectory
          .listSync(followLinks: false)
          .whereType<File>()
          .where((file) => file.path.endsWith('.PROVENANCE.json'))
          .toList()
        ..sort((left, right) => left.path.compareTo(right.path));
  final components = <NoticeComponent>[];
  for (final manifestFile in manifestFiles) {
    final manifest = await _readJsonMap(manifestFile);
    final name = _requiredString(manifest['name']);
    final commit = _requiredString(manifest['commit']);
    final archive = manifest['archive'];
    final license = manifest['license'];
    if (manifest['schemaVersion'] != 1 ||
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(commit) ||
        archive is! Map<String, Object?> ||
        license is! Map<String, Object?>) {
      throw const NoticeInventoryFailure(
        NoticeInventoryFailureReason.invalidMetadata,
      );
    }
    final source = _requiredString(archive['url']);
    if (!source.startsWith('https://') || _looksMutable(source)) {
      throw const NoticeInventoryFailure(
        NoticeInventoryFailureReason.invalidMetadata,
      );
    }
    final licensePath = _requiredSafePath(
      license['snapshotPath'],
      requiredPrefix: 'third_party',
    );
    final licenseFile = _safeProjectFile(
      request.projectRoot,
      licensePath,
      requiredPrefix: 'third_party',
    );
    _requireRegularFile(licenseFile);
    components.add(
      NoticeComponent(
        kind: NoticeComponentKind.nativeSource,
        name: name,
        version: commit,
        source: source,
        artifactSha256: _requiredSha256(archive['sha256']),
        licenseId: _requiredString(license['id']),
        licenseSnapshotPath: licensePath,
        licenseTextSha256: sha256
            .convert(await licenseFile.readAsBytes())
            .toString(),
      ),
    );
  }
  return components;
}

Future<NoticeComponent> _collectBenchmark(
  NoticeInventoryRequest request,
) async {
  final manifest = await _readJsonMap(request.benchmarkManifest);
  final source = manifest['source'];
  final audio = manifest['audio'];
  final rights = manifest['rights'];
  final annotationVersion = manifest['annotationVersion'];
  if (manifest['schemaVersion'] != 1 ||
      annotationVersion is! int ||
      annotationVersion <= 0 ||
      source is! Map<String, Object?> ||
      audio is! Map<String, Object?> ||
      rights is! Map<String, Object?> ||
      rights['rightsHolderAuthorized'] != true ||
      rights['allIdentifiableSpeakersConsented'] != true) {
    throw const NoticeInventoryFailure(
      NoticeInventoryFailureReason.invalidMetadata,
    );
  }
  final licensePath = _requiredSafePath(
    rights['licensePath'],
    requiredPrefix: 'assets/benchmarks/licenses',
  );
  final licenseFile = _safeProjectFile(
    request.projectRoot,
    licensePath,
    requiredPrefix: 'assets/benchmarks/licenses',
  );
  _requireRegularFile(licenseFile);
  final actualLicenseHash = sha256
      .convert(await licenseFile.readAsBytes())
      .toString();
  if (actualLicenseHash != _requiredSha256(rights['licenseTextSha256'])) {
    throw const NoticeInventoryFailure(
      NoticeInventoryFailureReason.invalidMetadata,
    );
  }
  final sourceKind = _requiredString(source['kind']);
  final sourceId = _requiredString(source['sourceId']);
  return NoticeComponent(
    kind: NoticeComponentKind.benchmarkAsset,
    name: _requiredString(manifest['id']),
    version: 'annotation-$annotationVersion',
    source: '$sourceKind:$sourceId',
    artifactSha256: _requiredSha256(audio['sha256']),
    licenseId: _requiredString(rights['license']),
    licenseSnapshotPath: licensePath,
    licenseTextSha256: actualLicenseHash,
  );
}

NoticeApproval _parseApproval(Map<String, Object?> json) {
  const keys = <String>{
    'kind',
    'name',
    'version',
    'artifactSha256',
    'licenseId',
    'licensePath',
    'licenseTextSha256',
    'redistribution',
    'approvedBy',
    'approvedAt',
  };
  if (json.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(json.keys.toSet()).isNotEmpty) {
    throw const NoticeInventoryFailure(
      NoticeInventoryFailureReason.invalidMetadata,
    );
  }
  final kindName = _requiredString(json['kind']);
  final kind = NoticeComponentKind.values
      .where((candidate) => candidate.name == kindName)
      .firstOrNull;
  final version = _requiredString(json['version']);
  final approvedAt = _requiredString(json['approvedAt']);
  final parsedDate = DateTime.tryParse('${approvedAt}T00:00:00Z');
  final artifactSha = json['artifactSha256'];
  if (kind == null ||
      !_isExactVersion(version) ||
      parsedDate == null ||
      approvedAt.length != 10 ||
      (artifactSha != null && artifactSha is! String)) {
    throw const NoticeInventoryFailure(
      NoticeInventoryFailureReason.invalidMetadata,
    );
  }
  return NoticeApproval(
    kind: kind,
    name: _requiredString(json['name']),
    version: version,
    artifactSha256: artifactSha == null ? null : _requiredSha256(artifactSha),
    licenseId: _requiredString(json['licenseId']),
    licensePath: _requiredSafePath(
      json['licensePath'],
      requiredPrefix: 'tool/third_party_notices/licenses',
    ),
    licenseTextSha256: _requiredSha256(json['licenseTextSha256']),
    redistribution: _requiredString(json['redistribution']),
    approvedBy: _requiredString(json['approvedBy']),
    approvedAt: approvedAt,
  );
}

Future<Map<String, Object?>> _readJsonMap(File file) async {
  _requireRegularFile(file);
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, Object?>) {
    throw const NoticeInventoryFailure(
      NoticeInventoryFailureReason.malformedInput,
    );
  }
  return decoded;
}

void _requireRegularFile(File file) {
  if (!_isRegularFile(file)) {
    throw const NoticeInventoryFailure(
      NoticeInventoryFailureReason.inputMissing,
    );
  }
}

bool _isRegularFile(File file) =>
    FileSystemEntity.typeSync(file.path, followLinks: false) ==
    FileSystemEntityType.file;

File _safeProjectFile(
  Directory projectRoot,
  String relativePath, {
  required String requiredPrefix,
}) {
  final safe = _requiredSafePath(
    relativePath,
    requiredPrefix: requiredPrefix,
  );
  final root = path.normalize(path.absolute(projectRoot.path));
  final resolved = path.normalize(path.join(root, safe));
  if (!path.isWithin(root, resolved)) {
    throw const NoticeInventoryFailure(
      NoticeInventoryFailureReason.invalidMetadata,
    );
  }
  return File(resolved);
}

String _requiredSafePath(
  Object? value, {
  required String requiredPrefix,
}) {
  final candidate = _requiredString(value);
  final segments = candidate.split('/');
  if (path.posix.isAbsolute(candidate) ||
      candidate.contains(r'\') ||
      segments.any(
        (segment) => segment.isEmpty || segment == '.' || segment == '..',
      ) ||
      !(candidate == requiredPrefix ||
          candidate.startsWith('$requiredPrefix/'))) {
    throw const NoticeInventoryFailure(
      NoticeInventoryFailureReason.invalidMetadata,
    );
  }
  return candidate;
}

String _requiredString(Object? value) {
  if (value is! String ||
      value.trim() != value ||
      value.isEmpty ||
      value.contains('`') ||
      value.runes.any((codePoint) => codePoint < 0x20 || codePoint == 0x7f)) {
    throw const NoticeInventoryFailure(
      NoticeInventoryFailureReason.invalidMetadata,
    );
  }
  return value;
}

String _requiredSha256(Object? value) {
  final candidate = _requiredString(value);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(candidate)) {
    throw const NoticeInventoryFailure(
      NoticeInventoryFailureReason.invalidMetadata,
    );
  }
  return candidate;
}

String _unquote(String value) {
  final trimmed = value.trim();
  if (trimmed.length >= 2 &&
      ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
          (trimmed.startsWith("'") && trimmed.endsWith("'")))) {
    return trimmed.substring(1, trimmed.length - 1);
  }
  return trimmed;
}

bool _isExactVersion(String value) =>
    value.isNotEmpty &&
    !value.contains(RegExp(r'[\s*^~<>]')) &&
    value.toLowerCase() != 'latest';

bool _looksMutable(String value) {
  final lower = value.toLowerCase();
  return lower.contains('/latest/') ||
      lower.endsWith('/latest') ||
      lower.contains('ref=main') ||
      lower.contains('ref=master');
}

int _compareComponents(NoticeComponent left, NoticeComponent right) {
  final byKind = left.kind.name.compareTo(right.kind.name);
  if (byKind != 0) {
    return byKind;
  }
  final byName = left.name.compareTo(right.name);
  return byName != 0 ? byName : left.version.compareTo(right.version);
}
