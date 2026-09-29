import 'dart:io';
import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/bootstrap/error_handlers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('file sink records only structured privacy-safe fields', () {
    final directory = Directory.systemTemp.createTempSync('loquiris-log-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    FileDiagnosticLogSink.open(
      directoryPath: directory.path,
      clock: Clock.fixed(DateTime.utc(2026, 9, 28, 12)),
    ).record(
      const DiagnosticEvent(
        code: DiagnosticCode.unhandledAsyncError,
        errorType: StateError,
      ),
    );

    final contents = File(
      '${directory.path}/loquiris-diagnostics.log',
    ).readAsStringSync();
    expect(contents, contains('unhandledAsyncError'));
    expect(contents, contains('StateError'));
    expect(contents, isNot(contains('meeting title')));
    expect(contents, isNot(contains('private transcript text')));
  });

  test('platform handler contains sink failures and omits exception text', () {
    final sink = _RecordingSink()..throwOnRecord = true;
    final previous = PlatformDispatcher.instance.onError;
    addTearDown(() => PlatformDispatcher.instance.onError = previous);
    installErrorHandlers(sink);

    final handled = PlatformDispatcher.instance.onError!(
      StateError('private transcript text'),
      StackTrace.empty,
    );

    expect(handled, isTrue);
    expect(sink.events, hasLength(1));
    expect(sink.events.single.errorType, StateError);
  });
}

final class _RecordingSink implements DiagnosticLogSink {
  final List<DiagnosticEvent> events = [];
  bool throwOnRecord = false;

  @override
  void record(DiagnosticEvent event) {
    events.add(event);
    if (throwOnRecord) {
      throw const FileSystemException('simulated local storage failure');
    }
  }
}
