import 'package:flutter/services.dart';
import 'package:loquiris/native/streaming_channel_contract.dart';

/// Injectable transport inside the native boundary; tests need no Flutter host.
abstract interface class StreamingPlatformPort {
  /// Sends primitive protocol fields; no PCM or caller-supplied file paths.
  Future<Object?> request(String method, Map<String, Object?> arguments);

  /// Installs the sole owner-scoped native event receiver.
  void onEvent(void Function(Object?) receive);

  /// Removes reception only after all native leases have released.
  void close();
}

/// Quarantines the actual platform channel while retaining a real contract seam.
final class MethodChannelStreamingPort implements StreamingPlatformPort {
  /// Creates the real streaming_v1 bridge or a contract-canary channel.
  MethodChannelStreamingPort({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel(StreamingChannelContract.channelName);

  final MethodChannel _channel;

  @override
  Future<Object?> request(String method, Map<String, Object?> arguments) =>
      _channel.invokeMethod<Object?>(method, arguments);

  @override
  void onEvent(void Function(Object?) receive) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'event') receive(call.arguments);
    });
  }

  @override
  void close() => _channel.setMethodCallHandler(null);
}
