import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

/// Stable restore-import failure that does not include user content.
final class RestoreImportFailure implements Failure {
  /// Creates a privacy-safe restore failure.
  const RestoreImportFailure(this.code);

  @override
  final String code;
}

/// Outcome for one meeting found in a verified backup database.
@immutable
final class RestoredMeetingResult {
  /// Creates an immutable per-meeting result.
  const RestoredMeetingResult({
    required this.sourceMeetingId,
    required this.meetingId,
    required this.imported,
    required this.wasConflictingCopy,
  });

  /// Meeting identity in the backup snapshot.
  final String sourceMeetingId;

  /// Meeting identity in the live database after restore.
  final String meetingId;

  /// Whether this invocation inserted the meeting.
  final bool imported;

  /// Whether a content conflict required a new identity and title marker.
  final bool wasConflictingCopy;
}

/// Complete deterministic database-merge result.
@immutable
final class RestoreImportReceipt {
  /// Creates an immutable receipt.
  RestoreImportReceipt(List<RestoredMeetingResult> meetings)
    : meetings = List<RestoredMeetingResult>.unmodifiable(meetings);

  /// Results ordered by source meeting identity.
  final List<RestoredMeetingResult> meetings;

  /// Number of meetings inserted by this invocation.
  int get importedCount => meetings.where((meeting) => meeting.imported).length;

  /// Number of content-identical meetings skipped by this invocation.
  int get skippedCount => meetings.length - importedCount;
}

/// File-publication instruction emitted immediately before database insert.
@immutable
final class RestoreMeetingTransfer {
  /// Creates an immutable transfer instruction.
  const RestoreMeetingTransfer({
    required this.sourceMeetingId,
    required this.targetMeetingId,
    required this.contentFingerprint,
    required this.hasAuthoritativeAudio,
  });

  /// Meeting identity in verified restore staging.
  final String sourceMeetingId;

  /// Final live meeting identity selected by conflict handling.
  final String targetMeetingId;

  /// Semantic audio fingerprint verified before import.
  final String contentFingerprint;

  /// Whether the aggregate references authoritative segment files.
  final bool hasAuthoritativeAudio;
}

/// Imports a fully verified and migrated backup snapshot without overwrites.
///
/// Archive parsing and checksum verification happen before this boundary. This
/// importer compares complete meeting-owned database aggregates, includes the
/// verified audio fingerprint supplied by the caller, and performs all live
/// database writes in one transaction.
final class DriftRestoreImporter {
  /// Creates an importer over the live database.
  const DriftRestoreImporter({
    required this.liveDatabase,
    required this.restoredCopyTitle,
    this.uuid = const Uuid(),
  });

  /// Live database that receives verified records.
  final AppDatabase liveDatabase;

  /// Localized title transformation for a conflicting restored copy.
  final String Function(String originalTitle) restoredCopyTitle;

  /// Deterministic UUID-v5 implementation.
  final Uuid uuid;

  /// Merges every meeting in [sourceDatabase] into the live database.
  ///
  /// [sourceAudioFingerprints] must contain one verified fingerprint for every
  /// source meeting. [liveAudioFingerprint] returns the fingerprint currently
  /// published for a live meeting, or `null` when no authoritative audio is
  /// present. A failure leaves the live database transaction unchanged.
  Future<Result<RestoreImportReceipt, RestoreImportFailure>> import(
    AppDatabase sourceDatabase, {
    required Map<String, String> sourceAudioFingerprints,
    required Future<String?> Function(String meetingId) liveAudioFingerprint,
    Future<Result<void, RestoreImportFailure>> Function(
      RestoreMeetingTransfer transfer,
    )?
    beforeMeetingInsert,
  }) async {
    try {
      final sourceMeetings = await _rows(
        sourceDatabase,
        _meetings,
        orderBy: 'id',
      );
      final sourceIds = sourceMeetings
          .map((row) => row['id'])
          .whereType<String>()
          .toList(growable: false);
      if (sourceIds.length != sourceMeetings.length ||
          sourceIds.toSet().length != sourceIds.length ||
          sourceIds.any((id) => !sourceAudioFingerprints.containsKey(id))) {
        return const Err(RestoreImportFailure('restore_snapshot_invalid'));
      }

      final receipt = await liveDatabase.transaction(() async {
        final modelMappings = <String, String>{};
        final insertedModels = <String>{};
        final results = <RestoredMeetingResult>[];
        for (final sourceMeetingId in sourceIds..sort()) {
          final rawSource = await _loadAggregate(
            sourceDatabase,
            sourceMeetingId,
          );
          if (rawSource == null) {
            throw const _RestoreAbort('restore_snapshot_invalid');
          }
          final audioFingerprint = sourceAudioFingerprints[sourceMeetingId]!;
          if (!_sha256Pattern.hasMatch(audioFingerprint)) {
            throw const _RestoreAbort('restore_snapshot_invalid');
          }
          await _ensureModels(
            sourceDatabase: sourceDatabase,
            aggregate: rawSource,
            mappings: modelMappings,
            insertedModels: insertedModels,
          );
          final source = rawSource.remapModelIds(modelMappings);
          final sourceFingerprint = _fingerprint(source, audioFingerprint);
          final exactLocal = await _loadAggregate(
            liveDatabase,
            sourceMeetingId,
          );
          if (exactLocal != null &&
              _sameAggregate(source, exactLocal) &&
              await liveAudioFingerprint(sourceMeetingId) == audioFingerprint) {
            results.add(
              RestoredMeetingResult(
                sourceMeetingId: sourceMeetingId,
                meetingId: sourceMeetingId,
                imported: false,
                wasConflictingCopy: false,
              ),
            );
            continue;
          }

          final hasConflict =
              exactLocal != null || await _hasAnyIdentityCollision(source);
          final targetMeetingId = hasConflict
              ? await _resolveConflictingMeetingId(
                  source: source,
                  sourceFingerprint: sourceFingerprint,
                  audioFingerprint: audioFingerprint,
                  liveAudioFingerprint: liveAudioFingerprint,
                )
              : sourceMeetingId;
          final transformed = hasConflict
              ? _transformAggregate(source, targetMeetingId)
              : source;
          final existingTarget = await _loadAggregate(
            liveDatabase,
            targetMeetingId,
          );
          if (existingTarget != null &&
              (hasConflict
                  ? _sameRestoredAggregate(transformed, existingTarget)
                  : _sameAggregate(transformed, existingTarget)) &&
              await liveAudioFingerprint(targetMeetingId) == audioFingerprint) {
            results.add(
              RestoredMeetingResult(
                sourceMeetingId: sourceMeetingId,
                meetingId: targetMeetingId,
                imported: false,
                wasConflictingCopy: hasConflict,
              ),
            );
            continue;
          }
          if (existingTarget != null) {
            throw const _RestoreAbort('restore_identity_exhausted');
          }

          if (beforeMeetingInsert != null) {
            final prepared = await beforeMeetingInsert(
              RestoreMeetingTransfer(
                sourceMeetingId: sourceMeetingId,
                targetMeetingId: targetMeetingId,
                contentFingerprint: audioFingerprint,
                hasAuthoritativeAudio:
                    (source.rowsByTable[_audioSegments] ?? const []).isNotEmpty,
              ),
            );
            if (prepared case Err(:final failure)) {
              throw _RestoreAbort(failure.code);
            }
          }
          await _insertAggregate(transformed);
          results.add(
            RestoredMeetingResult(
              sourceMeetingId: sourceMeetingId,
              meetingId: targetMeetingId,
              imported: true,
              wasConflictingCopy: hasConflict,
            ),
          );
        }
        return RestoreImportReceipt(results);
      });
      return Ok(receipt);
    } on _RestoreAbort catch (failure) {
      return Err(RestoreImportFailure(failure.code));
    } on DriftWrappedException catch (_) {
      return const Err(RestoreImportFailure('restore_database_unavailable'));
    } on FormatException catch (_) {
      return const Err(RestoreImportFailure('restore_snapshot_invalid'));
    } on Object catch (_) {
      return const Err(RestoreImportFailure('restore_import_failed'));
    }
  }

  Future<String> _resolveConflictingMeetingId({
    required _MeetingAggregate source,
    required String sourceFingerprint,
    required String audioFingerprint,
    required Future<String?> Function(String meetingId) liveAudioFingerprint,
  }) async {
    for (var attempt = 0; attempt < _maximumIdentityAttempts; attempt += 1) {
      final targetId = uuid.v5(
        Namespace.url.value,
        'loquiris:restore:meeting:${source.meetingId}:$sourceFingerprint:$attempt',
      );
      final expected = _transformAggregate(source, targetId);
      final existing = await _loadAggregate(liveDatabase, targetId);
      if (existing == null ||
          (_sameRestoredAggregate(expected, existing) &&
              await liveAudioFingerprint(targetId) == audioFingerprint)) {
        return targetId;
      }
    }
    throw const _RestoreAbort('restore_identity_exhausted');
  }

  Future<bool> _hasAnyIdentityCollision(_MeetingAggregate aggregate) async {
    for (final entry in aggregate.rowsByTable.entries) {
      for (final row in entry.value) {
        final id = row['id'];
        if (id is! String) {
          throw const _RestoreAbort('restore_snapshot_invalid');
        }
        final existing = await liveDatabase
            .customSelect(
              'SELECT 1 FROM ${entry.key} WHERE id = ? LIMIT 1',
              variables: <Variable<Object>>[Variable<String>(id)],
            )
            .getSingleOrNull();
        if (existing != null) return true;
      }
    }
    return false;
  }

  Future<void> _ensureModels({
    required AppDatabase sourceDatabase,
    required _MeetingAggregate aggregate,
    required Map<String, String> mappings,
    required Set<String> insertedModels,
  }) async {
    final referenced = aggregate.referencedModelIds.toList()..sort();
    for (final sourceModelId in referenced) {
      if (mappings.containsKey(sourceModelId)) continue;
      final source = await _loadModel(sourceDatabase, sourceModelId);
      if (source == null) {
        throw const _RestoreAbort('restore_model_missing');
      }
      final sameId = await _loadModel(liveDatabase, sourceModelId);
      if (sameId != null && _sameModel(source, sameId)) {
        mappings[sourceModelId] = sourceModelId;
        continue;
      }
      final sameDigest = await liveDatabase
          .customSelect(
            'SELECT id FROM model_manifests WHERE sha256 = ? LIMIT 1',
            variables: <Variable<Object>>[
              Variable<String>(source.manifest['sha256']! as String),
            ],
          )
          .getSingleOrNull();
      if (sameDigest != null) {
        final candidateId = sameDigest.data['id'];
        if (candidateId is! String) {
          throw const _RestoreAbort('restore_model_provenance_conflict');
        }
        final candidate = await _loadModel(liveDatabase, candidateId);
        if (candidate == null || !_sameModelSemantic(source, candidate)) {
          throw const _RestoreAbort('restore_model_provenance_conflict');
        }
        mappings[sourceModelId] = candidateId;
        continue;
      }
      final hasIdentityCollision = await _modelHasIdentityCollision(source);
      final targetId = sameId == null && !hasIdentityCollision
          ? sourceModelId
          : _modelConflictId(source);
      final expected = source.withId(
        targetId,
        remapChildren: targetId != sourceModelId,
      );
      final target = await _loadModel(liveDatabase, targetId);
      if (target != null && !_sameModel(expected, target)) {
        throw const _RestoreAbort('restore_model_provenance_conflict');
      }
      if (target == null && insertedModels.add(targetId)) {
        await _insertRows(_modelManifests, <Map<String, Object?>>[
          expected.manifest,
        ]);
        await _insertRows(_modelCapabilityEntries, expected.capabilities);
        await _insertRows(_modelModeEntries, expected.modes);
      }
      mappings[sourceModelId] = targetId;
    }
  }

  String _modelConflictId(_ModelAggregate source) => uuid.v5(
    Namespace.url.value,
    'loquiris:restore:model:${source.sourceId}:${_canonicalHash(source.canonical)}',
  );

  Future<bool> _modelHasIdentityCollision(_ModelAggregate source) async {
    for (final entry in <MapEntry<String, List<Map<String, Object?>>>>[
      MapEntry(_modelManifests, <Map<String, Object?>>[source.manifest]),
      MapEntry(_modelCapabilityEntries, source.capabilities),
      MapEntry(_modelModeEntries, source.modes),
    ]) {
      for (final row in entry.value) {
        final id = row['id'];
        if (id is! String) {
          throw const _RestoreAbort('restore_snapshot_invalid');
        }
        final found = await liveDatabase
            .customSelect(
              'SELECT 1 FROM ${entry.key} WHERE id = ? LIMIT 1',
              variables: <Variable<Object>>[Variable<String>(id)],
            )
            .getSingleOrNull();
        if (found != null) return true;
      }
    }
    return false;
  }

  Future<_MeetingAggregate?> _loadAggregate(
    AppDatabase database,
    String meetingId,
  ) async {
    final meetingRows = await _rows(
      database,
      _meetings,
      where: 'id = ?',
      variables: <Variable<Object>>[Variable<String>(meetingId)],
      orderBy: 'id',
    );
    if (meetingRows.isEmpty) return null;
    if (meetingRows.length != 1) {
      throw const _RestoreAbort('restore_snapshot_invalid');
    }
    final rows = <String, List<Map<String, Object?>>>{
      _meetings: meetingRows,
    };
    for (final table in _directMeetingTables) {
      rows[table] = await _rows(
        database,
        table,
        where: 'meeting_id = ?',
        variables: <Variable<Object>>[Variable<String>(meetingId)],
        orderBy: 'id',
      );
    }
    final transcriptSegmentIds = rows[_transcriptSegments]!
        .map((row) => row['id'])
        .whereType<String>()
        .toList(growable: false);
    rows[_languageDecisions] = await _rowsForIds(
      database,
      _languageDecisions,
      'transcript_segment_id',
      transcriptSegmentIds,
    );
    rows[_transcriptLanguageSelections] = await _rowsForIds(
      database,
      _transcriptLanguageSelections,
      'transcript_segment_id',
      transcriptSegmentIds,
    );
    return _MeetingAggregate(rows);
  }

  Future<_ModelAggregate?> _loadModel(
    AppDatabase database,
    String modelId,
  ) async {
    final manifests = await _rows(
      database,
      _modelManifests,
      where: 'id = ?',
      variables: <Variable<Object>>[Variable<String>(modelId)],
      orderBy: 'id',
    );
    if (manifests.isEmpty) return null;
    if (manifests.length != 1) {
      throw const _RestoreAbort('restore_snapshot_invalid');
    }
    return _ModelAggregate(
      manifest: manifests.single,
      capabilities: await _rows(
        database,
        _modelCapabilityEntries,
        where: 'model_id = ?',
        variables: <Variable<Object>>[Variable<String>(modelId)],
        orderBy: 'id',
      ),
      modes: await _rows(
        database,
        _modelModeEntries,
        where: 'model_id = ?',
        variables: <Variable<Object>>[Variable<String>(modelId)],
        orderBy: 'id',
      ),
    );
  }

  Future<List<Map<String, Object?>>> _rowsForIds(
    AppDatabase database,
    String table,
    String column,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const <Map<String, Object?>>[];
    final placeholders = List.filled(ids.length, '?').join(',');
    return _rows(
      database,
      table,
      where: '$column IN ($placeholders)',
      variables: ids
          .map<Variable<Object>>(Variable<String>.new)
          .toList(growable: false),
      orderBy: 'id',
    );
  }

  Future<List<Map<String, Object?>>> _rows(
    AppDatabase database,
    String table, {
    required String orderBy,
    String? where,
    List<Variable<Object>> variables = const <Variable<Object>>[],
  }) async {
    final query = StringBuffer('SELECT * FROM $table');
    if (where != null) query.write(' WHERE $where');
    query.write(' ORDER BY $orderBy');
    final result = await database
        .customSelect(
          query.toString(),
          variables: variables,
        )
        .get();
    return result
        .map((row) => Map<String, Object?>.unmodifiable(row.data))
        .toList(growable: false);
  }

  String _fingerprint(
    _MeetingAggregate aggregate,
    String audioFingerprint,
  ) => _canonicalHash(<String, Object?>{
    'database': aggregate.canonical,
    'audio': audioFingerprint,
  });

  bool _sameAggregate(_MeetingAggregate left, _MeetingAggregate right) =>
      _canonicalJson(left.canonical) == _canonicalJson(right.canonical);

  bool _sameRestoredAggregate(
    _MeetingAggregate expected,
    _MeetingAggregate existing,
  ) {
    final normalized = existing.withMeetingTitle(expected.meetingTitle);
    return _sameAggregate(expected, normalized);
  }

  bool _sameModel(_ModelAggregate left, _ModelAggregate right) =>
      _canonicalJson(left.canonical) == _canonicalJson(right.canonical);

  bool _sameModelSemantic(_ModelAggregate left, _ModelAggregate right) =>
      _canonicalJson(left.semantic) == _canonicalJson(right.semantic);

  _MeetingAggregate _transformAggregate(
    _MeetingAggregate source,
    String targetMeetingId,
  ) {
    final sourceStorageKey = _storageKey(source.meetingId);
    final targetStorageKey = _storageKey(targetMeetingId);
    final idMappings = <String, String>{source.meetingId: targetMeetingId};
    for (final entry in source.rowsByTable.entries) {
      if (entry.key == _meetings) continue;
      for (final row in entry.value) {
        final sourceId = row['id'];
        if (sourceId is! String) {
          throw const _RestoreAbort('restore_snapshot_invalid');
        }
        idMappings[sourceId] = uuid.v5(
          Namespace.url.value,
          'loquiris:restore:row:$targetMeetingId:${entry.key}:$sourceId',
        );
      }
    }
    final transformed = <String, List<Map<String, Object?>>>{};
    for (final entry in source.rowsByTable.entries) {
      transformed[entry.key] = entry.value
          .map((row) {
            final copy = Map<String, Object?>.of(row);
            for (final column
                in _identityReferenceColumns[entry.key] ?? const <String>[]) {
              final value = copy[column];
              if (value is String && idMappings.containsKey(value)) {
                copy[column] = idMappings[value];
              }
            }
            if (entry.key == _meetings) {
              final title = copy['title'];
              if (title is! String) {
                throw const _RestoreAbort('restore_snapshot_invalid');
              }
              copy['title'] = restoredCopyTitle(title);
            }
            if (entry.key == _audioSegments) {
              final relativePath = copy['relative_path'];
              if (relativePath is! String ||
                  !relativePath.startsWith('recordings/$sourceStorageKey/')) {
                throw const _RestoreAbort('restore_audio_path_invalid');
              }
              copy['relative_path'] = relativePath.replaceFirst(
                'recordings/$sourceStorageKey/',
                'recordings/$targetStorageKey/',
              );
            }
            if (entry.key == _revisions) {
              copy['payload_json'] = _remapRevisionPayload(
                copy['payload_json'],
                idMappings,
              );
            }
            return Map<String, Object?>.unmodifiable(copy);
          })
          .toList(growable: false);
    }
    return _MeetingAggregate(transformed);
  }

  Object? _remapRevisionPayload(
    Object? encoded,
    Map<String, String> idMappings,
  ) {
    if (encoded is! String) {
      throw const _RestoreAbort('restore_snapshot_invalid');
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, Object?>) {
      throw const _RestoreAbort('restore_snapshot_invalid');
    }
    for (final key in const <String>['previousSpeakerId', 'revisedSpeakerId']) {
      final value = decoded[key];
      if (value is String && idMappings.containsKey(value)) {
        decoded[key] = idMappings[value];
      }
    }
    return jsonEncode(_sortedJson(decoded));
  }

  Future<void> _insertAggregate(_MeetingAggregate aggregate) async {
    for (final table in _meetingInsertOrder) {
      await _insertRows(table, aggregate.rowsByTable[table] ?? const []);
    }
  }

  Future<void> _insertRows(
    String table,
    List<Map<String, Object?>> rows,
  ) async {
    for (final row in rows) {
      final columns = row.keys.toList()..sort();
      if (columns.isEmpty ||
          columns.any((column) => !_identifier.hasMatch(column))) {
        throw const _RestoreAbort('restore_snapshot_invalid');
      }
      final placeholders = List.filled(columns.length, '?').join(',');
      await liveDatabase.customStatement(
        'INSERT INTO $table (${columns.join(',')}) VALUES ($placeholders)',
        columns.map((column) => row[column]).toList(growable: false),
      );
    }
  }

  String _canonicalHash(Object? value) =>
      sha256.convert(utf8.encode(_canonicalJson(value))).toString();

  String _storageKey(String meetingId) =>
      sha256.convert(utf8.encode(meetingId)).toString();

  String _canonicalJson(Object? value) => jsonEncode(_sortedJson(value));

  Object? _sortedJson(Object? value) {
    if (value is Map<String, Object?>) {
      final entries = value.entries.toList()
        ..sort((left, right) => left.key.compareTo(right.key));
      return Map<String, Object?>.fromEntries(
        entries.map(
          (entry) => MapEntry<String, Object?>(
            entry.key,
            _sortedJson(entry.value),
          ),
        ),
      );
    }
    if (value is List<Object?>) {
      return value.map(_sortedJson).toList(growable: false);
    }
    return value;
  }
}

final class _MeetingAggregate {
  _MeetingAggregate(Map<String, List<Map<String, Object?>>> rowsByTable)
    : rowsByTable = Map<String, List<Map<String, Object?>>>.unmodifiable(
        rowsByTable.map(
          (table, rows) => MapEntry(
            table,
            List<Map<String, Object?>>.unmodifiable(rows),
          ),
        ),
      );

  final Map<String, List<Map<String, Object?>>> rowsByTable;

  String get meetingId {
    final rows = rowsByTable[_meetings];
    final id = rows?.singleOrNull?['id'];
    if (id is! String) throw const _RestoreAbort('restore_snapshot_invalid');
    return id;
  }

  String get meetingTitle {
    final rows = rowsByTable[_meetings];
    final title = rows?.singleOrNull?['title'];
    if (title is! String) {
      throw const _RestoreAbort('restore_snapshot_invalid');
    }
    return title;
  }

  Map<String, Object?> get canonical => Map<String, Object?>.fromEntries(
    (rowsByTable.entries.toList()
          ..sort((left, right) => left.key.compareTo(right.key)))
        .map((entry) => MapEntry(entry.key, entry.value)),
  );

  Set<String> get referencedModelIds => <String>{
    for (final table in const <String>[
      _transcriptRuns,
      _diarizationRuns,
      _processingJobs,
    ])
      for (final row in rowsByTable[table] ?? const <Map<String, Object?>>[])
        if (row['model_id'] case final String modelId) modelId,
  };

  _MeetingAggregate remapModelIds(Map<String, String> mappings) {
    final copy = <String, List<Map<String, Object?>>>{};
    for (final entry in rowsByTable.entries) {
      copy[entry.key] = entry.value
          .map((row) {
            final mutable = Map<String, Object?>.of(row);
            final modelId = mutable['model_id'];
            if (modelId is String && mappings.containsKey(modelId)) {
              mutable['model_id'] = mappings[modelId];
            }
            return Map<String, Object?>.unmodifiable(mutable);
          })
          .toList(growable: false);
    }
    return _MeetingAggregate(copy);
  }

  _MeetingAggregate withMeetingTitle(String title) {
    final copy = Map<String, List<Map<String, Object?>>>.of(rowsByTable);
    final meeting = Map<String, Object?>.of(copy[_meetings]!.single)
      ..['title'] = title;
    copy[_meetings] = <Map<String, Object?>>[
      Map<String, Object?>.unmodifiable(meeting),
    ];
    return _MeetingAggregate(copy);
  }
}

final class _ModelAggregate {
  const _ModelAggregate({
    required this.manifest,
    required this.capabilities,
    required this.modes,
  });

  final Map<String, Object?> manifest;
  final List<Map<String, Object?>> capabilities;
  final List<Map<String, Object?>> modes;

  String get sourceId {
    final id = manifest['id'];
    if (id is! String) throw const _RestoreAbort('restore_snapshot_invalid');
    return id;
  }

  Map<String, Object?> get canonical => <String, Object?>{
    'manifest': manifest,
    'capabilities': capabilities,
    'modes': modes,
  };

  Map<String, Object?> get semantic {
    final semanticManifest = Map<String, Object?>.of(manifest)
      ..remove('id')
      ..remove('created_at')
      ..remove('updated_at')
      ..remove('row_revision')
      ..remove('is_deleted')
      ..remove('deleted_at');
    return <String, Object?>{
      'manifest': semanticManifest,
      'capabilities':
          capabilities
              .map((row) => row['capability'])
              .whereType<String>()
              .toList()
            ..sort(),
      'modes': modes.map((row) => row['mode']).whereType<String>().toList()
        ..sort(),
    };
  }

  _ModelAggregate withId(
    String targetId, {
    required bool remapChildren,
  }) {
    final sourceId = this.sourceId;
    Map<String, Object?> rewrite(
      Map<String, Object?> row,
      String table,
    ) {
      final copy = Map<String, Object?>.of(row);
      if (copy['id'] == sourceId) copy['id'] = targetId;
      if (copy['model_id'] == sourceId) copy['model_id'] = targetId;
      if (remapChildren && table != _modelManifests) {
        final childId = row['id'];
        if (childId is! String) {
          throw const _RestoreAbort('restore_snapshot_invalid');
        }
        copy['id'] = const Uuid().v5(
          Namespace.url.value,
          'loquiris:restore:model-row:$targetId:$table:$childId',
        );
      }
      return Map<String, Object?>.unmodifiable(copy);
    }

    return _ModelAggregate(
      manifest: rewrite(manifest, _modelManifests),
      capabilities: capabilities
          .map((row) => rewrite(row, _modelCapabilityEntries))
          .toList(growable: false),
      modes: modes
          .map((row) => rewrite(row, _modelModeEntries))
          .toList(growable: false),
    );
  }
}

final class _RestoreAbort implements Exception {
  const _RestoreAbort(this.code);

  final String code;
}

const _maximumIdentityAttempts = 32;
final _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');
final _identifier = RegExp(r'^[a-z][a-z0-9_]*$');

const _meetings = 'meetings';
const _audioSegments = 'audio_segments';
const _recoveryFindings = 'recovery_findings';
const _sessionEvents = 'session_events';
const _bookmarks = 'bookmarks';
const _transcriptRuns = 'transcript_runs';
const _meetingTranscriptSelections = 'meeting_transcript_selections';
const _transcriptSegments = 'transcript_segments';
const _languageDecisions = 'language_decisions';
const _transcriptLanguageSelections = 'transcript_language_selections';
const _diarizationRuns = 'diarization_runs';
const _speakers = 'speakers';
const _speakerAssignments = 'speaker_assignments';
const _revisions = 'revisions';
const _processingJobs = 'processing_jobs';
const _modelManifests = 'model_manifests';
const _modelCapabilityEntries = 'model_capability_entries';
const _modelModeEntries = 'model_mode_entries';

const _directMeetingTables = <String>[
  _audioSegments,
  _recoveryFindings,
  _sessionEvents,
  _bookmarks,
  _transcriptRuns,
  _meetingTranscriptSelections,
  _transcriptSegments,
  _diarizationRuns,
  _speakers,
  _speakerAssignments,
  _revisions,
  _processingJobs,
];

const _meetingInsertOrder = <String>[
  _meetings,
  _audioSegments,
  _recoveryFindings,
  _sessionEvents,
  _bookmarks,
  _transcriptRuns,
  _diarizationRuns,
  _speakers,
  _speakerAssignments,
  _transcriptSegments,
  _meetingTranscriptSelections,
  _languageDecisions,
  _transcriptLanguageSelections,
  _revisions,
  _processingJobs,
];

const _identityReferenceColumns = <String, List<String>>{
  _meetings: <String>['id'],
  _audioSegments: <String>['id', 'meeting_id'],
  _recoveryFindings: <String>['id', 'meeting_id'],
  _sessionEvents: <String>['id', 'meeting_id'],
  _bookmarks: <String>['id', 'meeting_id'],
  _transcriptRuns: <String>['id', 'meeting_id'],
  _meetingTranscriptSelections: <String>[
    'id',
    'meeting_id',
    'transcript_run_id',
  ],
  _transcriptSegments: <String>[
    'id',
    'meeting_id',
    'transcript_run_id',
    'speaker_id',
    'speaker_meeting_id',
  ],
  _languageDecisions: <String>['id', 'transcript_segment_id'],
  _transcriptLanguageSelections: <String>[
    'id',
    'transcript_segment_id',
    'language_decision_id',
  ],
  _diarizationRuns: <String>['id', 'meeting_id'],
  _speakers: <String>['id', 'meeting_id', 'analysis_run_id'],
  _speakerAssignments: <String>[
    'id',
    'meeting_id',
    'analysis_run_id',
    'speaker_id',
    'speaker_analysis_run_id',
  ],
  _revisions: <String>[
    'id',
    'meeting_id',
    'transcript_segment_id',
    'speaker_assignment_id',
    'speaker_id',
  ],
  _processingJobs: <String>[
    'id',
    'meeting_id',
    'transcript_run_id',
    'diarization_run_id',
  ],
};
