import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:meta/meta.dart';

/// Complete journal-authorized input identity; no native file paths cross the seam.
final class RefinementAudioInventory extends ValueObject {
  /// Creates an immutable validated native observation.
  RefinementAudioInventory({
    required this.sha256,
    required this.totalSamples,
    required List<RefinementAudioSegmentInventory> segments,
  }) : segments = List.unmodifiable(segments);

  /// Lowercase SHA-256 of the canonical complete inventory.
  final String sha256;

  /// Total 16 kHz mono samples across every original segment.
  final int totalSamples;

  /// Number of ordered, nonempty original segments.
  int get segmentCount => segments.length;

  /// Exact ordered native geometry, bytes, and local opaque reference binding.
  final List<RefinementAudioSegmentInventory> segments;

  @override
  List<Object?> get equalityValues => [sha256, totalSamples, ...segments];
}

/// Content and geometry for one complete original segment, without a file path.
final class RefinementAudioSegmentInventory extends ValueObject {
  /// Creates one immutable validated native segment observation.
  const RefinementAudioSegmentInventory({
    required this.index,
    required this.startSample,
    required this.committedSamples,
    required this.committedBytes,
    required this.sha256,
    required this.referenceSha256,
  });

  /// Zero-based contiguous native manifest position.
  final int index;

  /// Inclusive pause-free 16 kHz sample offset.
  final int startSample;

  /// Complete committed samples; a positive multiple of 1024.
  final int committedSamples;

  /// Exact committed ADTS byte length.
  final int committedBytes;

  /// SHA-256 of the same data that passed journal validation.
  final String sha256;

  /// SHA-256 of UTF-8 app-relative reference, checked locally without disclosing it.
  final String referenceSha256;

  @override
  List<Object?> get equalityValues => [
    index,
    startSample,
    committedSamples,
    committedBytes,
    sha256,
    referenceSha256,
  ];
}

/// Content-free failure to establish complete refinement input.
sealed class RefinementAudioFailure implements Failure {
  const RefinementAudioFailure(this.code);

  @override
  final String code;
}

/// Inspection could not authorize a complete input inventory.
final class RefinementAudioUnavailable extends RefinementAudioFailure {
  /// Creates a permanent or retryable input/platform rejection.
  const RefinementAudioUnavailable(super.code);
}

/// Higher-priority capture prevents optional audio work right now.
final class RefinementAudioDeferred extends RefinementAudioFailure {
  /// Creates a resumable resource-priority outcome.
  const RefinementAudioDeferred(super.code);
}

/// The inventory owner cancelled its optional work.
final class RefinementAudioCancelled extends RefinementAudioFailure {
  /// Creates a cancellation without claiming that audio is missing or corrupt.
  const RefinementAudioCancelled() : super('refinement_audio_cancelled');
}

/// Injectable read-only boundary to all journal-validated authoritative audio.
// Native I/O needs a replaceable implementation, not an extra artificial method.
// ignore: one_member_abstracts
abstract interface class RefinementAudioInventoryService {
  /// Inspects only complete original audio and optionally rechecks its identity.
  @useResult
  Future<Result<RefinementAudioInventory, RefinementAudioFailure>> inspect(
    String meetingId, {
    String? expectedSha256,
  });
}

/// Bootstrap must install the one platform implementation before scheduling.
final refinementAudioInventoryServiceProvider =
    Provider<RefinementAudioInventoryService>(
      (ref) => throw UnimplementedError(
        'Refinement audio inspection is not installed',
      ),
    );
