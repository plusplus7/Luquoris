import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/transcript/domain/meeting_processing_selection.dart';
import 'package:loquiris/features/transcript/domain/refinement_identity.dart';

import '../../support/model_bundle_fixture.dart';

void main() {
  test('refinement identity matches independent Python UUIDv5 vectors', () {
    final identity = _identity();
    expect(identity.jobId, 'da2c6b7b-896e-5ea4-a1f8-846766bc2184');
    expect(identity.runId, 'e55ae492-66b5-58bf-817f-be3a0a2714e8');
    expect(_identity(), identity);
  });

  test(
    'meeting audio runtime and actual decoding settings each change identity',
    () {
      final original = _identity();
      final variants = [
        _identity(meetingId: 'another-meeting'),
        _identity(audioHash: 'b' * 64),
        _identity(profile: _profile(runtime: '2.0.0')),
        _identity(
          profile: _profile(
            parameters: '{"parameterVersion":1,"languageHint":"zh"}',
          ),
        ),
        _identity(
          profile: _profile(
            parameters: '{"parameterVersion":2,"languageHint":"mixed"}',
          ),
        ),
      ];
      for (final variant in variants) {
        expect(variant.jobId, isNot(original.jobId));
        expect(variant.runId, isNot(original.runId));
      }
    },
  );

  test(
    'parameter key order normalizes but frozen manifest bytes remain exact',
    () {
      expect(
        _identity(
          profile: _profile(
            parameters: '{"languageHint":"mixed","parameterVersion":1}',
          ),
        ),
        _identity(),
      );
      expect(
        _identity(profile: _profile(prettyManifest: true)),
        isNot(_identity()),
      );
    },
  );

  test('invalid ownership or inventory cannot produce a durable identity', () {
    for (final meeting in ['', ' meeting', 'meeting\n', 'x' * 513]) {
      expect(
        RefinementIdentity.tryCreate(
          meetingId: meeting,
          audioInventorySha256: 'a' * 64,
          profile: _profile(),
        ),
        isA<Err<RefinementIdentity, InvalidRefinementIdentity>>(),
      );
    }
    for (final hash in ['', 'a' * 63, 'A' * 64, 'g' * 64]) {
      expect(
        RefinementIdentity.tryCreate(
          meetingId: 'meeting',
          audioInventorySha256: hash,
          profile: _profile(),
        ),
        isA<Err<RefinementIdentity, InvalidRefinementIdentity>>(),
      );
    }
  });
}

RefinementIdentity _identity({
  String meetingId = 'meeting-中文',
  String? audioHash,
  ProcessingModelProfile? profile,
}) {
  final result = RefinementIdentity.tryCreate(
    meetingId: meetingId,
    audioInventorySha256: audioHash ?? 'a' * 64,
    profile: profile ?? _profile(),
  );
  expect(result, isA<Ok<RefinementIdentity, InvalidRefinementIdentity>>());
  return (result as Ok<RefinementIdentity, InvalidRefinementIdentity>).value;
}

ProcessingModelProfile _profile({
  String runtime = '1.0.0',
  String parameters = '{"parameterVersion":1,"languageHint":"mixed"}',
  bool prettyManifest = false,
}) {
  final bundle = modelBundleFixture();
  (bundle['runtime']! as Map<String, Object?>)['engineVersion'] = runtime;
  final parsed = ProcessingModelProfile.tryCreate(
    bundleManifestJson: prettyManifest
        ? const JsonEncoder.withIndent('  ').convert(bundle)
        : jsonEncode(bundle),
    engineVersion: runtime,
    parametersJson: parameters,
  );
  expect(parsed, isA<Ok<ProcessingModelProfile, InvalidProcessingSelection>>());
  return (parsed as Ok<ProcessingModelProfile, InvalidProcessingSelection>)
      .value;
}
