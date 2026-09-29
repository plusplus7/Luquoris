import 'dart:io';

import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/data/files/meeting_audio_store.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Deletes validated relative audio paths below one app-private directory.
final class PrivateMeetingAudioStore implements MeetingAudioStore {
  /// Creates a lazy private-file store.
  const PrivateMeetingAudioStore(this._resolveBaseDirectory);

  final Future<Directory> Function() _resolveBaseDirectory;

  @override
  Future<Result<void, MeetingAudioStoreFailure>> deleteAuthoritativeAudio(
    List<AppRelativePath> relativePaths,
  ) async {
    try {
      final baseDirectory = await _resolveBaseDirectory();
      for (final relativePath in relativePaths) {
        final file = File(
          path.joinAll(<String>[
            baseDirectory.path,
            ...relativePath.value.split('/'),
          ]),
        );
        if (file.existsSync()) file.deleteSync();
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
}
