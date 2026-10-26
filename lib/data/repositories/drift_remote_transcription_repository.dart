import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/database/app_database.dart';
import 'package:loquiris/features/remote_transcription/domain/remote_endpoint.dart';
import 'package:loquiris/features/remote_transcription/domain/remote_transcript.dart';
import 'package:loquiris/services/remote_transcription_repository.dart';
import 'package:loquiris/services/remote_transcription_service.dart';

/// Durable user requests and version reads; native writes are observed by polling.
final class DriftRemoteTranscriptionRepository
    implements RemoteTranscriptionRepository {
  /// Injects identity, clock and scheduling to keep storage deterministic in tests.
  const DriftRemoteTranscriptionRepository(
    this.database, {
    required this.service,
    required this.newId,
    required this.nowUtcMs,
  });

  /// Shared application database with additive remote tables.
  final AppDatabase database;

  /// Native credentials and persistent work scheduling seam.
  final RemoteTranscriptionService service;

  /// Factory called once per explicit new run.
  final String Function() newId;

  /// UTC epoch milliseconds, never inferred from media time.
  final int Function() nowUtcMs;

  Future<Result<T, RemoteTranscriptionFailure>> _guard<T>(
    Future<T> Function() action,
  ) async {
    try {
      return Ok(await action());
    } on Object {
      return const Err(
        RemoteTranscriptionFailure('remote_storage_unavailable'),
      );
    }
  }

  @override
  Future<
    Result<(List<RemoteTask>, List<RemoteVersion>), RemoteTranscriptionFailure>
  >
  load(String meetingId) => _guard(() async {
    final tasks =
        await (database.select(database.remoteTranscriptionTasks)
              ..where(
                (r) =>
                    r.meetingId.equals(meetingId) & r.isDeleted.equals(false),
              )
              ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
            .get();
    final versions =
        await (database.select(database.remoteTranscriptVersions)
              ..where(
                (r) =>
                    r.meetingId.equals(meetingId) & r.isDeleted.equals(false),
              )
              ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
            .get();
    final valid = <RemoteVersion>[];
    for (final row in versions) {
      if (row.resultJson.length > 16 * 1024 * 1024) {
        throw const FormatException('result_limit');
      }
      final json = jsonDecode(row.resultJson) as Map<String, Object?>;
      final result = RemoteTranscript.tryParse(
        json,
        meetingId: row.sourceMeetingId ?? row.meetingId,
        runId: row.sourceRunId ?? row.id,
        manifestDigest:
            tasks.where((t) => t.id == row.id).firstOrNull?.manifestDigest ??
            json['audioManifestDigest']! as String,
      );
      if (result == null) throw const FormatException('remote_result');
      valid.add(
        RemoteVersion(
          id: row.id,
          result: result,
          resultJson: row.resultJson,
          editedText: row.editedText,
        ),
      );
    }
    return (
      tasks
          .map(
            (r) => RemoteTask(
              id: r.id,
              state: r.state,
              confirmedBytes: r.confirmedBytes,
              totalBytes: r.totalBytes,
              failureCode: r.failureCode,
              expiresAtUtcMs: r.expiresAtUtcMs,
              retentionSeconds: r.retentionSeconds,
            ),
          )
          .toList(),
      valid,
    );
  });

  @override
  Future<Result<RemoteDestination?, RemoteTranscriptionFailure>>
  latestDestination() => _guard(() async {
    final saved = await service.loadConnection();
    if (saved case Err()) {
      throw const FormatException('remote_credentials_unavailable');
    }
    if (saved case Ok(value: final connection?)) {
      return RemoteDestination(
        connection.endpoint,
        connection.credentialRef,
        'qwen-1.7b',
      );
    }

    final rows =
        await (database.select(database.remoteTranscriptionTasks)
              ..where(
                (r) =>
                    r.credentialRef.isNotValue('') & r.isDeleted.equals(false),
              )
              ..orderBy([(r) => OrderingTerm.desc(r.createdAt)])
              ..limit(1))
            .get();
    if (rows.isEmpty) return null;
    final row = rows.single;
    return RemoteDestination(row.endpoint, row.credentialRef, row.profileId);
  });

  @override
  Future<Result<String, RemoteTranscriptionFailure>> enqueue(
    String meetingId, {
    RemoteDestination? destination,
  }) => _guard(() async {
    if (destination != null && !_validDestination(destination)) {
      throw const FormatException('remote_destination');
    }
    final id = newId();
    final time = nowUtcMs();
    await database
        .into(database.remoteTranscriptionTasks)
        .insert(
          RemoteTranscriptionTasksCompanion.insert(
            id: id,
            meetingId: meetingId,
            endpoint: destination?.endpoint ?? '',
            credentialRef: destination?.credentialRef ?? '',
            profileId: destination?.profileId ?? 'qwen-1.7b',
            state: Value(destination == null ? 'waitingSetup' : 'waitingAudio'),
            createdAtUtcMs: time,
            updatedAtUtcMs: time,
            createdAt: time,
            updatedAt: time,
          ),
        );
    await service.wake();
    return id;
  });

  @override
  Future<Result<void, RemoteTranscriptionFailure>> configure(
    String meetingId,
    RemoteDestination destination,
  ) => _guard(() async {
    if (!_validDestination(destination)) {
      throw const FormatException('remote_destination');
    }
    final time = nowUtcMs();
    await (database.update(database.remoteTranscriptionTasks)..where(
          (r) => r.meetingId.equals(meetingId) & r.state.equals('waitingSetup'),
        ))
        .write(
          RemoteTranscriptionTasksCompanion(
            endpoint: Value(destination.endpoint),
            credentialRef: Value(destination.credentialRef),
            profileId: Value(destination.profileId),
            state: const Value('waitingAudio'),
            updatedAt: Value(time),
            updatedAtUtcMs: Value(time),
          ),
        );
    await service.wake();
  });

  @override
  Future<Result<void, RemoteTranscriptionFailure>> configurePending(
    RemoteDestination destination,
  ) => _guard(() async {
    if (!_validDestination(destination)) {
      throw const FormatException('remote_destination');
    }
    final time = nowUtcMs();
    await (database.update(database.remoteTranscriptionTasks)..where(
          (r) => r.state.equals('waitingSetup') & r.isDeleted.equals(false),
        ))
        .write(
          RemoteTranscriptionTasksCompanion(
            endpoint: Value(destination.endpoint),
            credentialRef: Value(destination.credentialRef),
            profileId: Value(destination.profileId),
            state: const Value('waitingAudio'),
            updatedAt: Value(time),
            updatedAtUtcMs: Value(time),
          ),
        );
    await service.wake();
  });

  @override
  Future<Result<void, RemoteTranscriptionFailure>> cancel(String runId) =>
      _guard(() async {
        final time = nowUtcMs();
        await (database.update(
          database.remoteTranscriptionTasks,
        )..where((r) => r.id.equals(runId))).write(
          RemoteTranscriptionTasksCompanion(
            state: const Value('cancelled'),
            updatedAt: Value(time),
            updatedAtUtcMs: Value(time),
          ),
        );
        await service.wake();
      });

  @override
  Future<Result<void, RemoteTranscriptionFailure>> edit(
    String runId,
    String text,
  ) => _guard(() async {
    if (text.length > 16 * 1024 * 1024) {
      throw const FormatException('edit_limit');
    }
    await (database.update(
      database.remoteTranscriptVersions,
    )..where((r) => r.id.equals(runId))).write(
      RemoteTranscriptVersionsCompanion(
        editedText: Value(text),
        updatedAt: Value(nowUtcMs()),
      ),
    );
  });
}

bool _validDestination(RemoteDestination destination) {
  return isRemoteEndpoint(destination.endpoint) &&
      destination.credentialRef.isNotEmpty &&
      const ['qwen-1.7b', 'whisper-large-v3'].contains(destination.profileId);
}
