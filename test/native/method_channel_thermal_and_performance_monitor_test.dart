import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/native/method_channel_thermal_and_performance_monitor.dart';
import 'package:loquiris/services/service_contracts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.loquiris/performance_metrics');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('decodes exact versioned snapshot', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'readSnapshot');
      expect(call.arguments, <String, Object?>{'v': 1});
      return _validResponse();
    });

    final result = await const MethodChannelThermalAndPerformanceMonitor(
      channel: channel,
    ).current();

    final snapshot =
        (result as Ok<DevicePerformanceSnapshot, PerformanceFailure>).value;
    expect(snapshot.observedAtMonotonic, const Duration(milliseconds: 11));
    expect(snapshot.processCpuTime, const Duration(milliseconds: 12));
    expect(snapshot.processPssBytes, 13);
    expect(snapshot.thermalState, ThermalState.warm);
    expect(snapshot.remainingDeviceEnergyNanowattHours, isNull);
    expect(snapshot.isCharging, isTrue);
  });

  test(
    'rejects wrong version missing keys wrong types negative overflow and unknown thermal names',
    () async {
      final invalidResponses = <Object?>[
        {..._validResponse(), 'v': 2},
        <String, Object?>{'v': 1, 'ok': true},
        _validResponse(snapshotChanges: {'processPssBytes': '13'}),
        _validResponse(snapshotChanges: {'processCpuTimeMs': -1}),
        _validResponse(
          snapshotChanges: {'observedAtMonotonicMs': 9223372036854776},
        ),
        _validResponse(snapshotChanges: {'thermalState': 'scorching'}),
        {..._validResponse(), 'extra': true},
      ];

      for (final response in invalidResponses) {
        messenger.setMockMethodCallHandler(channel, (_) async => response);

        final result = await const MethodChannelThermalAndPerformanceMonitor(
          channel: channel,
        ).current();

        expect(_failureCode(result), 'performance_metrics_channel_invalid');
      }
    },
  );

  test(
    'maps timeout missing plugin and platform failure to channel unavailable',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) => Completer<Object?>().future,
      );
      final timeout = await const MethodChannelThermalAndPerformanceMonitor(
        channel: channel,
        timeout: Duration(milliseconds: 1),
      ).current();
      expect(
        _failureCode(timeout),
        'performance_metrics_channel_unavailable',
      );

      messenger.setMockMethodCallHandler(channel, null);
      final missingPlugin =
          await const MethodChannelThermalAndPerformanceMonitor(
            channel: channel,
          ).current();
      expect(
        _failureCode(missingPlugin),
        'performance_metrics_channel_unavailable',
      );

      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'native-private-code'),
      );
      final platform = await const MethodChannelThermalAndPerformanceMonitor(
        channel: channel,
      ).current();
      expect(
        _failureCode(platform),
        'performance_metrics_channel_unavailable',
      );
    },
  );

  test('never exposes platform exception text', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(
        code: 'secret-code',
        message: 'secret message',
        details: 'secret details',
      ),
    );

    final result = await const MethodChannelThermalAndPerformanceMonitor(
      channel: channel,
    ).current();
    final failure =
        (result as Err<DevicePerformanceSnapshot, PerformanceFailure>).failure;

    expect(failure.code, 'performance_metrics_channel_unavailable');
    expect(failure.code, isNot(contains('secret')));
  });
}

Map<String, Object?> _validResponse({
  Map<String, Object?> snapshotChanges = const {},
}) {
  return <String, Object?>{
    'v': 1,
    'ok': true,
    'snapshot': <String, Object?>{
      'observedAtMonotonicMs': 11,
      'processCpuTimeMs': 12,
      'processPssBytes': 13,
      'thermalState': 'warm',
      'remainingDeviceEnergyNanowattHours': null,
      'isCharging': true,
      ...snapshotChanges,
    },
  };
}

String _failureCode(
  Result<DevicePerformanceSnapshot, PerformanceFailure> result,
) => switch (result) {
  Ok() => fail('expected failure'),
  Err(:final failure) => failure.code,
};
