import 'dart:io';

import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';

/// Expected failure while deleting application-private authoritative audio.
sealed class MeetingAudioStoreFailure implements Failure {
  const MeetingAudioStoreFailure(
    this.code, {
    required this.sourceErrorType,
    required this.stackFingerprint,
  });

  @override
  final String code;

  /// Runtime type only; exception messages are never propagated.
  final Type sourceErrorType;

  /// Privacy-safe hash of the originating stack trace.
  final String stackFingerprint;
}

/// Application-private audio could not be removed completely.
final class MeetingAudioStoreUnavailable extends MeetingAudioStoreFailure {
  /// Creates a structured failure, primarily for deterministic test fakes.
  const MeetingAudioStoreUnavailable(
    super.code, {
    super.sourceErrorType = FileSystemException,
    super.stackFingerprint = 'not-captured',
  });
}

/// Filesystem boundary used before permanent meeting metadata deletion.
// This interface is injectable so repository deletion remains deterministic.
// ignore: one_member_abstracts
abstract interface class MeetingAudioStore {
  /// Deletes every supplied authoritative relative path or reports failure.
  Future<Result<void, MeetingAudioStoreFailure>> deleteAuthoritativeAudio(
    List<AppRelativePath> relativePaths,
  );
}
