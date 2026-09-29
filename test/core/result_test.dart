import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';

void main() {
  group('Result', () {
    test('fold reads the success value', () {
      const result = Ok<int, _TestFailure>(21);

      final folded = result.fold(
        (value) => value * 2,
        (failure) => failure.code.length,
      );

      expect(folded, 42);
    });

    test('fold reads the structured failure', () {
      const result = Err<int, _TestFailure>(_UnavailableFailure('microphone'));

      final folded = result.fold(
        (value) => '$value',
        (failure) => '${failure.code}:${failure.component}',
      );

      expect(folded, 'test.unavailable:microphone');
    });

    test('map transforms success and preserves failure identity', () {
      const failure = _UnavailableFailure('storage');
      const success = Ok<int, _TestFailure>(7);
      const failed = Err<int, _TestFailure>(failure);

      expect(success.map((value) => '$value'), isA<Ok<String, _TestFailure>>());
      expect(
        (failed.map((value) => '$value') as Err<String, _TestFailure>).failure,
        same(failure),
      );
    });

    test('flatMap short-circuits after a failure', () {
      const failure = _UnavailableFailure('model');
      const result = Err<int, _TestFailure>(failure);
      var called = false;

      final mapped = result.flatMap<String>((value) {
        called = true;
        return Ok('$value');
      });

      expect(called, isFalse);
      expect((mapped as Err<String, _TestFailure>).failure, same(failure));
    });
  });
}

sealed class _TestFailure implements Failure {
  const _TestFailure();

  String get component;
}

final class _UnavailableFailure extends _TestFailure {
  const _UnavailableFailure(this.component);

  @override
  final String component;

  @override
  String get code => 'test.unavailable';
}
