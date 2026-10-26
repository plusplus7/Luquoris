import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';

/// Privacy-safe platform and remote synchronization failure.
final class RemoteTranscriptionFailure implements Failure {
  /// Carries a stable code without paths or credentials.
  const RemoteTranscriptionFailure(this.code);
  @override
  final String code;
}

/// A locally saved destination descriptor; the encrypted token never leaves native storage.
final class RemoteSavedConnection {
  /// Carries only the origin and its opaque credential reference.
  const RemoteSavedConnection(this.endpoint, this.credentialRef);

  /// Configured origin, including its explicit transport scheme.
  final String endpoint;

  /// Native no-backup credential identity.
  final String credentialRef;
}

/// Native effects stay behind one injectable composition-root service.
abstract interface class RemoteTranscriptionService {
  /// Stops background writers while a closed-file migration is performed.
  Future<Result<void, RemoteTranscriptionFailure>> prepareDatabase();

  /// Releases migration exclusion and registers persistent network work.
  Future<Result<void, RemoteTranscriptionFailure>> resume(String databasePath);

  /// Encrypts a destination-bound token outside the backup database.
  Future<Result<String, RemoteTranscriptionFailure>> saveCredential(
    String endpoint,
    String token,
  );

  /// Saves the default connection independently of any meeting or task.
  Future<Result<String, RemoteTranscriptionFailure>> saveConnection(
    String endpoint,
    String token,
  );

  /// Reads a saved connection without exposing the token or creating work.
  Future<Result<RemoteSavedConnection?, RemoteTranscriptionFailure>>
  loadConnection();

  /// Refreshes the disposable OS job schedule after durable state changes.
  Future<Result<void, RemoteTranscriptionFailure>> wake();
}

/// Bootstrap installs the native service; tests can supply an isolated fake.
final remoteTranscriptionServiceProvider = Provider<RemoteTranscriptionService>(
  (ref) =>
      throw UnimplementedError('Remote transcription service is not installed'),
);
