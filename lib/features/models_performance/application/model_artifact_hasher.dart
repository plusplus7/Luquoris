import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Immutable digest and byte count produced by artifact verification.
final class ModelArtifactHash {
  /// Creates one completed hash result.
  const ModelArtifactHash({required this.sha256, required this.bytes});

  /// Lowercase hexadecimal SHA-256 digest.
  final String sha256;

  /// Exact number of bytes consumed from the artifact stream.
  final int bytes;
}

/// Hashes a bounded byte stream away from latency-sensitive callers.
// This interface keeps the isolate implementation replaceable in tests.
// ignore: one_member_abstracts
abstract interface class ModelArtifactHasher {
  /// Consumes [chunks] with backpressure and returns its SHA-256 result.
  Future<ModelArtifactHash> hash(Stream<List<int>> chunks);
}

/// SHA-256 worker that transfers and acknowledges one bounded chunk at a time.
final class IsolateModelArtifactHasher implements ModelArtifactHasher {
  /// Creates the background-isolate hasher.
  const IsolateModelArtifactHasher();

  @override
  Future<ModelArtifactHash> hash(Stream<List<int>> chunks) async {
    final responses = ReceivePort();
    final isolate = await Isolate.spawn(
      _runModelHashWorker,
      responses.sendPort,
      debugName: 'loquiris-model-hasher',
    );
    final iterator = StreamIterator<Object?>(responses);
    try {
      if (!await iterator.moveNext() || iterator.current is! SendPort) {
        throw StateError('model_hash_worker_unavailable');
      }
      final worker = iterator.current! as SendPort;
      await for (final chunk in chunks) {
        final bytes = Uint8List.fromList(chunk);
        worker.send(TransferableTypedData.fromList(<Uint8List>[bytes]));
        if (!await iterator.moveNext() || iterator.current != bytes.length) {
          throw StateError('model_hash_worker_invalid_ack');
        }
      }
      worker.send(null);
      if (!await iterator.moveNext()) {
        throw StateError('model_hash_worker_no_result');
      }
      final result = iterator.current;
      if (result is! List<Object?> ||
          result.length != 2 ||
          result[0] is! String ||
          result[1] is! int) {
        throw StateError('model_hash_worker_invalid_result');
      }
      return ModelArtifactHash(
        sha256: result[0]! as String,
        bytes: result[1]! as int,
      );
    } finally {
      await iterator.cancel();
      responses.close();
      isolate.kill(priority: Isolate.immediate);
    }
  }
}

void _runModelHashWorker(SendPort caller) {
  final commands = ReceivePort();
  final digestSink = _DigestSink();
  final input = sha256.startChunkedConversion(digestSink);
  var observedBytes = 0;
  caller.send(commands.sendPort);
  commands.listen((message) {
    if (message == null) {
      input.close();
      caller.send(<Object?>[digestSink.value.toString(), observedBytes]);
      commands.close();
      return;
    }
    final bytes = (message as TransferableTypedData)
        .materialize()
        .asUint8List();
    input.add(bytes);
    observedBytes += bytes.length;
    caller.send(bytes.length);
  });
}

final class _DigestSink implements Sink<Digest> {
  Digest? _value;

  Digest get value => _value ?? (throw StateError('model_hash_incomplete'));

  @override
  void add(Digest data) {
    _value = data;
  }

  @override
  void close() {}
}
