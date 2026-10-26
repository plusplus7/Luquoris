import 'dart:convert';

import 'package:loquiris/core/domain/value_object.dart';
import 'package:loquiris/core/failure.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';
import 'package:uuid/uuid.dart';

/// Ownership or complete-audio identity cannot safely identify durable work.
final class InvalidRefinementIdentity implements Failure {
  /// Creates a content-free identity rejection.
  const InvalidRefinementIdentity();

  @override
  String get code => 'refinement_identity_invalid';
}

/// Versioned full-pass identities independent of clocks and local catalog aliases.
final class RefinementIdentity extends ValueObject {
  const RefinementIdentity._({required this.jobId, required this.runId});

  /// Derives one immutable role-specific job/run pair from complete frozen inputs.
  ///
  /// The exact frozen manifest bytes are part of identity. Local catalog aliases,
  /// mutable completeness, source draft availability, and timestamps are not.
  static Result<RefinementIdentity, InvalidRefinementIdentity> tryCreate({
    required String meetingId,
    required String audioInventorySha256,
    required ProcessingModelProfile profile,
  }) {
    if (meetingId.isEmpty ||
        meetingId.trim() != meetingId ||
        meetingId.length > 512 ||
        !_digest.hasMatch(audioInventorySha256)) {
      return const Err(InvalidRefinementIdentity());
    }
    final inputs = <Object>[
      meetingId,
      audioInventorySha256,
      'refinement',
      profile.manifest.engineId,
      profile.engineVersion,
      profile.manifest.id,
      profile.manifest.version,
      profile.manifest.sha256,
      profile.parameterVersion,
      profile.parametersJson,
      profile.bundleManifestJson,
    ];
    return Ok(
      RefinementIdentity._(
        jobId: _derive('job', inputs),
        runId: _derive('run', inputs),
      ),
    );
  }

  /// Durable queue identity for this meeting/audio/profile tuple.
  final String jobId;

  /// Separate transcript-version identity, never the live draft's identity.
  final String runId;

  @override
  List<Object?> get equalityValues => [jobId, runId];
}

const _uuid = Uuid();
// UUIDv5(NAMESPACE_URL, "loquiris:refinement-identity:v1"). Frozen after use.
const _namespace = 'b32de874-afc4-5a06-8f31-e3c23022bbe8';
final _digest = RegExp(r'^[0-9a-f]{64}$');

String _derive(String kind, List<Object> inputs) => _uuid.v5(
  _namespace,
  jsonEncode(['loquiris.refinement.v1', kind, ...inputs]),
);
