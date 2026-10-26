import 'package:loquiris/core/domain/value_object.dart';
import 'package:meta/meta.dart';

/// Independent purpose of a new paired transcription run.
enum TranscriptProcessingRole {
  /// Read-only capture-time evidence, including partially covered recordings.
  liveDraft,

  /// Complete pass over the finalized authoritative audio inventory.
  refinement,
}

/// Audio coverage, independent of successful inference termination.
enum TranscriptCompleteness {
  /// All authoritative input was processed without coverage warnings.
  complete,

  /// Coverage is partial, pending, or stopped before all input was processed.
  incomplete,
}

/// Full immutable provenance plus the independently tracked coverage state.
@immutable
final class TranscriptProcessingInfo extends ValueObject {
  /// Creates a command/projection; repositories validate it against its owner.
  const TranscriptProcessingInfo({
    required this.role,
    required this.completeness,
    required this.bundleManifestJson,
    this.sourceRunId,
    this.audioInventorySha256,
  });

  /// Explicit live or complete-pass purpose, never inferred from old jobs.
  final TranscriptProcessingRole role;

  /// Whether this run covers all its intended authoritative input.
  final TranscriptCompleteness completeness;

  /// Frozen v1/v2 manifest bytes, including every file's source and license.
  final String bundleManifestJson;

  /// Optional same-meeting live draft that preceded refinement.
  final String? sourceRunId;

  /// Finalized ordered audio inventory identity; required for refinement.
  final String? audioInventorySha256;

  @override
  List<Object?> get equalityValues => [
    role,
    completeness,
    bundleManifestJson,
    sourceRunId,
    audioInventorySha256,
  ];
}
