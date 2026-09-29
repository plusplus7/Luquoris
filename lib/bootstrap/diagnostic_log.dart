import 'dart:io';

import 'package:clock/clock.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Privacy-safe diagnostic categories written to local storage.
enum DiagnosticCode {
  /// An uncaught Flutter framework error reached the root handler.
  unhandledFrameworkError,

  /// An uncaught asynchronous error reached the platform dispatcher.
  unhandledAsyncError,

  /// A best-effort lifecycle flush failed.
  lifecycleFlushFailed,

  /// An expected local repository or filesystem operation failed.
  sessionRepositoryOperationFailed,

  /// An expected local analysis persistence operation failed.
  analysisRepositoryOperationFailed,
}

/// A structured diagnostic that cannot carry user content.
final class DiagnosticEvent {
  /// Creates a diagnostic event.
  const DiagnosticEvent({
    required this.code,
    required this.errorType,
    this.stackFingerprint = 'not-captured',
  });

  /// Stable machine-readable category.
  final DiagnosticCode code;

  /// Runtime error type only; the API cannot accept exception messages.
  final Type errorType;

  /// Privacy-safe fingerprint used to correlate repeated stack origins.
  final String stackFingerprint;
}

/// Local destination for privacy-safe diagnostic events.
// This interface is an injectable boundary with production and test sinks.
// ignore: one_member_abstracts
abstract interface class DiagnosticLogSink {
  /// Records [event] synchronously so it survives abrupt process termination.
  void record(DiagnosticEvent event);
}

/// App-private file-backed diagnostic sink.
final class FileDiagnosticLogSink implements DiagnosticLogSink {
  FileDiagnosticLogSink._({required this._file, required this._clock});

  /// Opens a sink below the already-resolved app-private [directoryPath].
  factory FileDiagnosticLogSink.open({
    required String directoryPath,
    Clock clock = const Clock(),
  }) {
    final directory = Directory(directoryPath)..createSync(recursive: true);
    return FileDiagnosticLogSink._(
      file: File(p.join(directory.path, 'loquiris-diagnostics.log')),
      clock: clock,
    );
  }

  final File _file;
  final Clock _clock;

  @override
  void record(DiagnosticEvent event) {
    try {
      _file.writeAsStringSync(
        '${_clock.now().toUtc().toIso8601String()} '
        '${event.code.name} ${event.errorType} ${event.stackFingerprint}\n',
        mode: FileMode.append,
        flush: true,
      );
      // The sink is the last error boundary and deliberately catches all objects.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      // A diagnostic failure cannot be allowed to recurse into error handling.
    }
  }
}

/// Hashes a stack trace without persisting paths, messages, or user content.
String diagnosticStackFingerprint(StackTrace stackTrace) {
  var hash = 0x811c9dc5;
  for (final codeUnit in stackTrace.toString().codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// A sink used only when app-private storage cannot be opened.
final class DisabledDiagnosticLogSink implements DiagnosticLogSink {
  /// Creates a disabled sink.
  const DisabledDiagnosticLogSink();

  @override
  void record(DiagnosticEvent event) {}
}

/// Opens the app-private diagnostic sink without exposing startup to IO errors.
Future<DiagnosticLogSink> openApplicationDiagnosticLog() async {
  try {
    final directory = await getApplicationSupportDirectory();
    return FileDiagnosticLogSink.open(directoryPath: directory.path);
    // No global handler exists yet, so the bootstrap fallback catches all objects.
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    // There is no installed handler yet; fail closed without aborting startup.
    return const DisabledDiagnosticLogSink();
  }
}
