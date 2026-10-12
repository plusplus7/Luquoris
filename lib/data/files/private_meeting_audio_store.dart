import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/files/meeting_audio_store.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Deletes one validated meeting-owned native recording directory.
final class PrivateMeetingAudioStore implements MeetingAudioStore {
  /// Creates a lazy private-file store.
  const PrivateMeetingAudioStore(this._resolveBaseDirectory);

  final Future<Directory> Function() _resolveBaseDirectory;

  @override
  Future<Result<void, MeetingAudioStoreFailure>> deleteAuthoritativeAudio(
    String meetingId,
    List<AppRelativePath> relativePaths,
  ) async {
    try {
      final baseDirectory = await _resolveBaseDirectory();
      final storageKey = sha256.convert(utf8.encode(meetingId)).toString();
      final recordingPrefix = 'recordings/$storageKey/';
      if (relativePaths.any(
        (relativePath) =>
            !relativePath.value.startsWith(recordingPrefix) ||
            !_segmentPath.hasMatch(relativePath.value),
      )) {
        return const Err(
          MeetingAudioStoreUnavailable('audio_delete_scope_invalid'),
        );
      }
      final recordingDirectory = Directory(
        path.join(baseDirectory.path, 'recordings', storageKey),
      );
      if (recordingDirectory.existsSync()) {
        recordingDirectory.deleteSync(recursive: true);
      }
      final eventDirectory = path.join(
        baseDirectory.path,
        'recording-events',
      );
      for (final suffix in _eventSuffixes) {
        final eventFile = File(path.join(eventDirectory, '$storageKey$suffix'));
        if (eventFile.existsSync()) eventFile.deleteSync();
      }
      return const Ok<void, MeetingAudioStoreFailure>(null);
    } on FileSystemException catch (error, stackTrace) {
      return Err<void, MeetingAudioStoreFailure>(
        MeetingAudioStoreUnavailable(
          'audio_delete_failed',
          sourceErrorType: error.runtimeType,
          stackFingerprint: diagnosticStackFingerprint(stackTrace),
        ),
      );
    } on MissingPlatformDirectoryException catch (error, stackTrace) {
      return Err<void, MeetingAudioStoreFailure>(
        MeetingAudioStoreUnavailable(
          'audio_storage_unavailable',
          sourceErrorType: error.runtimeType,
          stackFingerprint: diagnosticStackFingerprint(stackTrace),
        ),
      );
    }
  }

  static final _segmentPath = RegExp(
    r'^recordings/[a-f0-9]{64}/segment-[0-9]{5,}\.adts$',
  );
  static const _eventSuffixes = <String>[
    '.bookmarks',
    '.interruptions',
    '.storage-failure',
  ];
}
