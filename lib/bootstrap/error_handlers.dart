import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';

/// Returns the original error hidden by Riverpod's provider wrapper.
Object unwrapProviderException(Object error) {
  return switch (error) {
    ProviderException(:final exception) => unwrapProviderException(exception),
    _ => error,
  };
}

/// Installs the application's two top-level error containment handlers.
void installErrorHandlers(DiagnosticLogSink sink) {
  FlutterError.onError = (details) {
    try {
      final error = unwrapProviderException(details.exception);
      sink.record(
        DiagnosticEvent(
          code: DiagnosticCode.unhandledFrameworkError,
          errorType: error.runtimeType,
        ),
      );
      FlutterError.presentError(details);
      // A handler must catch all objects to prevent recursive failure.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      // Never let an error handler throw or recursively report its own failure.
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    try {
      final unwrapped = unwrapProviderException(error);
      sink.record(
        DiagnosticEvent(
          code: DiagnosticCode.unhandledAsyncError,
          errorType: unwrapped.runtimeType,
        ),
      );
      if (kDebugMode) {
        debugPrint('Unhandled asynchronous ${unwrapped.runtimeType}');
      }
      // A handler must catch all objects to prevent recursive failure.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      // Never let an error handler throw or recursively report its own failure.
    }
    return true;
  };
}
