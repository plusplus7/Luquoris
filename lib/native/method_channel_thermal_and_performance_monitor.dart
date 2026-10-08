import 'dart:async';

import 'package:flutter/services.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Strict Dart owner of the Android performance-metrics wire contract.
final class MethodChannelThermalAndPerformanceMonitor
    implements ThermalAndPerformanceMonitor {
  /// Creates the production monitor or an injected test adapter.
  const MethodChannelThermalAndPerformanceMonitor({
    MethodChannel? channel,
    this.timeout = const Duration(seconds: 2),
  }) : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.loquiris/performance_metrics_v1';
  static const _contractVersion = 1;
  static const _maximumSigned64 = 9223372036854775807;
  static const int _maximumDurationMilliseconds =
      _maximumSigned64 ~/ Duration.microsecondsPerMillisecond;

  final MethodChannel _channel;

  /// Maximum wait for the platform snapshot.
  final Duration timeout;

  @override
  Future<Result<DevicePerformanceSnapshot, PerformanceFailure>>
  current() async {
    try {
      final response = await _channel
          .invokeMethod<Object?>(
            'readSnapshot',
            <String, Object?>{'v': _contractVersion},
          )
          .timeout(timeout);
      if (response is! Map<Object?, Object?> ||
          response['v'] is! int ||
          response['v'] != _contractVersion ||
          response['ok'] is! bool) {
        return _invalid();
      }
      if (response['ok'] == false) {
        if (!_hasExactKeys(response, const {'v', 'ok', 'failure'})) {
          return _invalid();
        }
        final failure = response['failure'];
        if (failure is! Map<Object?, Object?> ||
            !_hasExactKeys(failure, const {'code'}) ||
            failure['code'] is! String ||
            !_nativeFailureCodes.contains(failure['code'])) {
          return _invalid();
        }
        return Err(PerformanceUnavailable(failure['code']! as String));
      }
      if (!_hasExactKeys(response, const {'v', 'ok', 'snapshot'})) {
        return _invalid();
      }
      final snapshot = response['snapshot'];
      if (snapshot is! Map<Object?, Object?> ||
          !_hasExactKeys(snapshot, const {
            'observedAtMonotonicMs',
            'processCpuTimeMs',
            'processPssBytes',
            'thermalState',
            'remainingDeviceEnergyNanowattHours',
            'isCharging',
          })) {
        return _invalid();
      }
      final observedAtMonotonicMs = snapshot['observedAtMonotonicMs'];
      final processCpuTimeMs = snapshot['processCpuTimeMs'];
      final processPssBytes = snapshot['processPssBytes'];
      final thermalState = _decodeThermalState(snapshot['thermalState']);
      final remainingEnergy = snapshot['remainingDeviceEnergyNanowattHours'];
      final isCharging = snapshot['isCharging'];
      if (!_validDurationMilliseconds(observedAtMonotonicMs) ||
          !_validDurationMilliseconds(processCpuTimeMs) ||
          !_validSigned64(processPssBytes) ||
          thermalState == null ||
          (remainingEnergy != null && !_validSigned64(remainingEnergy)) ||
          isCharging is! bool) {
        return _invalid();
      }
      return Ok(
        DevicePerformanceSnapshot(
          observedAtMonotonic: Duration(
            milliseconds: observedAtMonotonicMs! as int,
          ),
          processCpuTime: Duration(milliseconds: processCpuTimeMs! as int),
          processPssBytes: processPssBytes! as int,
          thermalState: thermalState,
          remainingDeviceEnergyNanowattHours: remainingEnergy as int?,
          isCharging: isCharging,
        ),
      );
    } on TimeoutException {
      return _unavailable();
    } on MissingPluginException {
      return _unavailable();
    } on PlatformException {
      return _unavailable();
    } on FormatException {
      return _invalid();
    } catch (error) {
      if (error is RangeError) return _invalid();
      rethrow;
    }
  }

  static const _nativeFailureCodes = <String>{
    'performance_metrics_method_unsupported',
    'performance_metrics_request_invalid',
    'performance_metrics_read_failed',
    'performance_metrics_channel_invalid',
  };

  bool _hasExactKeys(Map<Object?, Object?> value, Set<String> keys) =>
      value.length == keys.length && value.keys.every(keys.contains);

  bool _validDurationMilliseconds(Object? value) =>
      value is int && value >= 0 && value <= _maximumDurationMilliseconds;

  bool _validSigned64(Object? value) =>
      value is int && value >= 0 && value <= _maximumSigned64;

  ThermalState? _decodeThermalState(Object? value) => switch (value) {
    'nominal' => ThermalState.nominal,
    'warm' => ThermalState.warm,
    'hot' => ThermalState.hot,
    'critical' => ThermalState.critical,
    'unknown' => ThermalState.unknown,
    _ => null,
  };

  Result<DevicePerformanceSnapshot, PerformanceFailure> _invalid() => const Err(
    PerformanceUnavailable('performance_metrics_channel_invalid'),
  );

  Result<DevicePerformanceSnapshot, PerformanceFailure> _unavailable() =>
      const Err(
        PerformanceUnavailable('performance_metrics_channel_unavailable'),
      );
}
