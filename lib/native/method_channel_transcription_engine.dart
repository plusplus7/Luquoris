import 'dart:async';

import 'package:flutter/services.dart';
import 'package:loquiris/core/domain/app_relative_path.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Sole Dart owner of the versioned Android transcription wire contract.
final class MethodChannelTranscriptionEngine implements TranscriptionEngine {
  /// Creates the production adapter with optional test-only channel seams.
  MethodChannelTranscriptionEngine({
    MethodChannel? channel,
    Stream<Object?>? eventStream,
    this.timeout = const Duration(hours: 6),
  }) : _channel = channel ?? const MethodChannel(_channelName),
       _eventStream =
           eventStream ??
           const EventChannel(_eventChannelName).receiveBroadcastStream();

  static const String _channelName = 'com.loquiris/transcription_v1';
  static const String _eventChannelName =
      'com.loquiris/transcription_events_v1';
  static const int _version = 1;

  final MethodChannel _channel;
  final Stream<Object?> _eventStream;

  /// Maximum wall time allowed for one platform invocation.
  final Duration timeout;

  @override
  Stream<TranscriptionEvent> eventsFor(String runId) {
    var lastProgress = 0.0;
    return _eventStream
        .map(_parseProgressEvent)
        .where((event) => event != null && event.runId == runId)
        .cast<TranscriptionProgressUpdated>()
        .where((event) {
          if (event.fraction < lastProgress) return false;
          lastProgress = event.fraction;
          return true;
        })
        .handleError(
          (Object _) {},
          test: (error) =>
              error is PlatformException || error is MissingPluginException,
        );
  }

  @override
  Future<Result<TranscriptionOutput, TranscriptionFailure>> transcribe(
    TranscriptionRequest request,
  ) async {
    if (!_isValidRequest(request)) {
      return const Err(
        TranscriptionUnavailable('transcription_request_invalid'),
      );
    }
    final response = await _invoke('transcribe', <String, Object?>{
      'runId': request.runId,
      'meetingId': request.audio.sessionId,
      'segmentReferences': request.audio.segmentPaths,
      'modelId': request.modelId,
      'languageHint': request.languageHint.name,
      'parameterVersion': request.parameterVersion,
    });
    if (response case Err<Map<Object?, Object?>, TranscriptionFailure>(
      :final failure,
    )) {
      return Err(failure);
    }
    final envelope =
        (response as Ok<Map<Object?, Object?>, TranscriptionFailure>).value;
    if (envelope['runId'] != request.runId) {
      return const Err(
        TranscriptionUnavailable('transcription_channel_run_mismatch'),
      );
    }
    return _parseOutput(envelope['result']);
  }

  @override
  Future<Result<void, TranscriptionFailure>> cancel(String runId) async {
    if (!_isSafeIdentifier(runId)) {
      return const Err(
        TranscriptionUnavailable('transcription_request_invalid'),
      );
    }
    final response = await _invoke('cancel', <String, Object?>{'runId': runId});
    if (response case Err<Map<Object?, Object?>, TranscriptionFailure>(
      :final failure,
    )) {
      return Err(failure);
    }
    final envelope =
        (response as Ok<Map<Object?, Object?>, TranscriptionFailure>).value;
    if (envelope['runId'] != runId || envelope['cancelled'] != true) {
      return const Err(
        TranscriptionUnavailable('transcription_channel_invalid'),
      );
    }
    return const Ok<void, TranscriptionFailure>(null);
  }

  Future<Result<Map<Object?, Object?>, TranscriptionFailure>> _invoke(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      final raw = await _channel
          .invokeMethod<Object?>(method, <String, Object?>{
            'v': _version,
            ...arguments,
          })
          .timeout(timeout);
      if (raw is! Map<Object?, Object?> ||
          raw['v'] != _version ||
          raw['ok'] is! bool) {
        return const Err(
          TranscriptionUnavailable('transcription_channel_invalid'),
        );
      }
      if (raw['ok'] == true) return Ok(raw);
      final failure = raw['failure'];
      final code = failure is Map<Object?, Object?> ? failure['code'] : null;
      return Err(
        TranscriptionUnavailable(
          code is String && _safeFailureCodes.contains(code)
              ? code
              : 'transcription_channel_invalid',
        ),
      );
    } on TimeoutException {
      return const Err(
        TranscriptionUnavailable('transcription_channel_timeout'),
      );
    } on MissingPluginException {
      return const Err(
        TranscriptionUnavailable('transcription_channel_unavailable'),
      );
    } on PlatformException {
      return const Err(
        TranscriptionUnavailable('transcription_channel_unavailable'),
      );
    }
  }

  Result<TranscriptionOutput, TranscriptionFailure> _parseOutput(Object? raw) {
    if (raw is! Map<Object?, Object?>) return _invalidOutput();
    final engineVersion = raw['engineVersion'];
    final warningCode = raw['warningCode'];
    final rawChunks = raw['chunks'];
    if (engineVersion is! String ||
        engineVersion.isEmpty ||
        (warningCode != null &&
            (warningCode is! String ||
                !_safeFailureCodes.contains(warningCode))) ||
        rawChunks is! List<Object?>) {
      return _invalidOutput();
    }
    final chunks = <TranscriptChunk>[];
    var previousEnd = Duration.zero;
    for (final rawChunk in rawChunks) {
      final chunk = _parseStableChunk(rawChunk);
      if (chunk == null || chunk.start < previousEnd) return _invalidOutput();
      chunks.add(chunk);
      previousEnd = chunk.end;
    }
    return Ok(
      TranscriptionOutput(
        chunks: chunks,
        engineVersion: engineVersion,
        warningCode: warningCode as String?,
      ),
    );
  }

  TranscriptChunk? _parseStableChunk(Object? raw) {
    if (raw is! Map<Object?, Object?>) return null;
    final segmentId = raw['segmentId'];
    final start = raw['startMilliseconds'];
    final end = raw['endMilliseconds'];
    final rawText = raw['rawText'];
    final displayText = raw['displayText'];
    if (segmentId is! String ||
        segmentId.isEmpty ||
        start is! int ||
        start < 0 ||
        end is! int ||
        end < start ||
        rawText is! String ||
        displayText is! String ||
        raw['stability'] != 'stable') {
      return null;
    }
    return TranscriptChunk(
      segmentId: segmentId,
      start: Duration(milliseconds: start),
      end: Duration(milliseconds: end),
      rawText: rawText,
      displayText: displayText,
      stability: TranscriptStability.stable,
    );
  }

  TranscriptionProgressUpdated? _parseProgressEvent(Object? raw) {
    if (raw is! Map<Object?, Object?> ||
        raw['v'] != _version ||
        raw['type'] != 'progress') {
      return null;
    }
    final runId = raw['runId'];
    final fraction = raw['fraction'];
    final remaining = raw['remainingMilliseconds'];
    if (runId is! String ||
        !_isSafeIdentifier(runId) ||
        fraction is! double ||
        fraction < 0 ||
        fraction > 1 ||
        (remaining != null && (remaining is! int || remaining < 0))) {
      return null;
    }
    return TranscriptionProgressUpdated(
      runId: runId,
      fraction: fraction,
      remaining: remaining == null
          ? null
          : Duration(milliseconds: remaining as int),
    );
  }

  bool _isValidRequest(TranscriptionRequest request) =>
      _isSafeIdentifier(request.runId) &&
      _isSafeIdentifier(request.audio.sessionId) &&
      _isSafeIdentifier(request.modelId) &&
      request.parameterVersion > 0 &&
      request.audio.segmentPaths.isNotEmpty &&
      request.audio.segmentPaths.every(_isSafeRelativePath);

  bool _isSafeRelativePath(String value) =>
      AppRelativePath.tryParse(value)
          is Ok<AppRelativePath, InvalidAppRelativePath>;

  bool _isSafeIdentifier(String value) =>
      value.isNotEmpty &&
      value.length <= 128 &&
      RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value);

  Result<TranscriptionOutput, TranscriptionFailure> _invalidOutput() =>
      const Err(TranscriptionUnavailable('transcription_channel_invalid'));

  static const Set<String> _safeFailureCodes = <String>{
    'transcription_cancelled',
    'transcription_request_invalid',
    'transcription_model_directory_failed',
    'transcription_model_hash_mismatch',
    'transcription_model_load_failed',
    'transcription_model_manifest_invalid',
    'transcription_model_materialization_failed',
    'transcription_model_publish_failed',
    'transcription_native_failed',
    'transcription_native_inference_failed',
    'transcription_native_input_invalid',
    'transcription_native_invalid_handle',
    'transcription_native_out_of_memory',
    'transcription_native_unavailable',
    'transcription_audio_decode_failed',
    'transcription_audio_empty',
    'transcription_audio_format_unsupported',
    'transcription_audio_invalid',
    'transcription_audio_journal_invalid',
    'transcription_audio_journal_too_large',
    'transcription_audio_manifest_invalid',
    'transcription_audio_manifest_missing',
    'transcription_audio_meeting_invalid',
    'transcription_audio_meeting_mismatch',
    'transcription_audio_missing',
    'transcription_audio_path_invalid',
    'transcription_audio_read_failed',
    'transcription_audio_segment_corrupt',
    'transcription_audio_segment_missing',
    'transcription_audio_segment_open',
    'transcription_audio_segment_too_large',
    'transcription_audio_timeline_gap',
    'transcription_audio_track_missing',
    'transcription_audio_uncommitted_tail',
    'transcription_channel_closed',
    'transcription_channel_invalid',
    'transcription_channel_timeout',
    'transcription_channel_unavailable',
    'transcription_channel_version_unsupported',
  };
}
