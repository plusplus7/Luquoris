import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/features/remote_transcription/domain/remote_transcript.dart';

void main() {
  final fixtures = Directory('contracts/remote_transcription/v1/fixtures');
  test('shared result verifies identity and timeline before import', () {
    final upload =
        jsonDecode(File('${fixtures.path}/upload.json').readAsStringSync())
            as Map<String, Object?>;
    final result =
        jsonDecode(File('${fixtures.path}/result.json').readAsStringSync())
            as Map<String, Object?>;
    final parsed = RemoteTranscript.tryParse(
      result,
      meetingId: 'meeting-1',
      runId: 'run-1',
      manifestDigest: remoteManifestDigest(upload),
    );
    expect(parsed, isNotNull);
    expect(parsed!.segments.length, 2);
    expect(parsed.text, contains('hello'));
    expect(
      RemoteTranscript.tryParse(
        {...result, 'schemaVersion': 2},
        meetingId: 'meeting-1',
        runId: 'run-1',
        manifestDigest: remoteManifestDigest(upload),
      ),
      isNull,
    );
    expect(
      RemoteTranscript.tryParse(
        result,
        meetingId: 'other',
        runId: 'run-1',
        manifestDigest: remoteManifestDigest(upload),
      ),
      isNull,
    );
    expect(
      RemoteTranscript.tryParse(
        {...result, 'unexpected': true},
        meetingId: 'meeting-1',
        runId: 'run-1',
        manifestDigest: remoteManifestDigest(upload),
      ),
      isNull,
    );
    final bad = {
      ...result,
      'segments': [
        {'startMs': 2000, 'endMs': 1000, 'text': 'bad'},
      ],
    };
    expect(
      RemoteTranscript.tryParse(
        bad,
        meetingId: 'meeting-1',
        runId: 'run-1',
        manifestDigest: remoteManifestDigest(upload),
      ),
      isNull,
    );
  });
}
