import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:loquiris/core/domain/value_object.dart';

/// Computes the v1 manifest identity independently of native journal hashes.
String remoteManifestDigest(Map<String, Object?> value) {
  Object? canonical(Object? item) => switch (item) {
    Map<String, Object?>() => <String, Object?>{
      for (final key in item.keys.toList()..sort()) key: canonical(item[key]),
    },
    List<Object?>() => item.map(canonical).toList(),
    _ => item,
  };
  final json = jsonEncode(canonical(value));
  final ascii = StringBuffer();
  for (final unit in json.codeUnits) {
    if (unit > 127) {
      ascii
        ..write(r'\u')
        ..write(unit.toRadixString(16).padLeft(4, '0'));
    } else {
      ascii.writeCharCode(unit);
    }
  }
  return sha256.convert(utf8.encode(ascii.toString())).toString();
}

/// One immutable server segment anchored to recorded media time.
final class RemoteTranscriptSegment extends ValueObject {
  /// Retains a validated half-open media interval and raw text.
  const RemoteTranscriptSegment(this.startMs, this.endMs, this.text);

  /// Inclusive media position in milliseconds.
  final int startMs;

  /// Exclusive media position in milliseconds.
  final int endMs;

  /// Raw machine text, independent of human corrections.
  final String text;

  @override
  List<Object?> get equalityValues => [startMs, endMs, text];
}

/// Validated remote result without dependency on installed local models.
final class RemoteTranscript extends ValueObject {
  const RemoteTranscript._(
    this.jobId,
    this.durationMs,
    this.provenance,
    this.segments,
  );

  /// Stable remote job identity.
  final String jobId;

  /// Total captured media duration in milliseconds.
  final int durationMs;

  /// Actual server model and runtime metadata.
  final Map<String, String> provenance;

  /// Ordered, disjoint model segments.
  final List<RemoteTranscriptSegment> segments;

  /// Plain text preserves individual model tokens including their spacing.
  String get text => segments.map((segment) => segment.text).join();

  /// Rejects untrusted schema, identity and timeline data before persistence.
  static RemoteTranscript? tryParse(
    Map<String, Object?> json, {
    required String meetingId,
    required String runId,
    required String manifestDigest,
  }) {
    const fields = {
      'schemaVersion',
      'jobId',
      'meetingId',
      'runId',
      'audioManifestDigest',
      'durationMs',
      'provenance',
      'segments',
    };
    if (json.keys.any((key) => !fields.contains(key)) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(manifestDigest) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(meetingId) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(runId)) {
      return null;
    }
    final duration = json['durationMs'];
    final raw = json['segments'];
    final provenance = json['provenance'];
    final jobId = json['jobId'];
    if (json['schemaVersion'] != 1 ||
        json['meetingId'] != meetingId ||
        json['runId'] != runId ||
        json['audioManifestDigest'] != manifestDigest ||
        jobId is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(jobId) ||
        duration is! int ||
        duration < 0 ||
        duration > 43200000 ||
        raw is! List<Object?> ||
        raw.length > 100000 ||
        provenance is! Map<String, Object?> ||
        provenance['modelRevision'] is! String ||
        provenance['runtime'] is! String) {
      return null;
    }
    final metadata = <String, String>{};
    for (final entry in provenance.entries) {
      if (entry.value is! String) return null;
      metadata[entry.key] = entry.value! as String;
    }
    if (metadata['modelRevision']!.isEmpty || metadata['runtime']!.isEmpty) {
      return null;
    }
    final segments = <RemoteTranscriptSegment>[];
    var previous = 0;
    for (final item in raw) {
      if (item is! Map<String, Object?>) return null;
      const segmentFields = {'startMs', 'endMs', 'text', 'language', 'speaker'};
      if (item.keys.any((key) => !segmentFields.contains(key))) return null;
      final language = item['language'];
      if (language != null && (language is! String || language.length > 32)) {
        return null;
      }
      final start = item['startMs'];
      final end = item['endMs'];
      final text = item['text'];
      if (start is! int ||
          end is! int ||
          text is! String ||
          text.isEmpty ||
          text.length > 16000 ||
          start < previous ||
          end <= start ||
          end > duration ||
          item['speaker'] != null) {
        return null;
      }
      segments.add(RemoteTranscriptSegment(start, end, text));
      previous = end;
    }
    return RemoteTranscript._(
      jobId,
      duration,
      Map.unmodifiable(metadata),
      List.unmodifiable(segments),
    );
  }

  @override
  List<Object?> get equalityValues => [
    jobId,
    durationMs,
    provenance,
    ...segments,
  ];
}
