import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled benchmark manifest retains provenance and authorization',
    () async {
      final manifest =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/benchmarks/audio/manifest.json',
                ),
              )
              as Map<String, Object?>;

      expect(manifest['schemaVersion'], 1);
      expect(manifest['id'], 'zh-en-mixed-v1');
      expect(manifest['purpose'], 'firstRunPerformanceBenchmark');
      expect(
        manifest['languageCoverage'],
        <Object?>['zh-CN', 'en', 'zh-en-code-switching'],
      );
      final source = manifest['source']! as Map<String, Object?>;
      expect(source['kind'], 'contributor-authorized-recording');
      expect(
        source['sha256'],
        '8c80e266431445df2dd040b52dac44ba8500c55cdb50509cc9286c25c7532a24',
      );
      expect(source['bytes'], 9787192);
      expect(source['segmentStartMs'], 0);
      expect(source['segmentDurationMs'], 45000);
      final rights = manifest['rights']! as Map<String, Object?>;
      expect(rights['license'], 'CC0-1.0');
      expect(rights['attestationDate'], '2026-10-01');
      expect(rights['rightsHolderAuthorized'], isTrue);
      expect(rights['allIdentifiableSpeakersConsented'], isTrue);
    },
  );

  test('bundled benchmark is the reviewed 45-second PCM waveform', () async {
    final data = await rootBundle.load(
      'assets/benchmarks/audio/zh_en_mixed_v1.wav',
    );
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    expect(bytes.length, 1440044);
    expect(
      sha256.convert(bytes).toString(),
      '83440d4ccbd82dafd1a88346ab448e1dd309e408c598d665413b910cc92c40a7',
    );
    expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
    expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE');
    expect(ascii.decode(bytes.sublist(12, 16)), 'fmt ');
    final header = ByteData.sublistView(bytes);
    expect(header.getUint16(20, Endian.little), 1);
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint16(34, Endian.little), 16);
    expect(ascii.decode(bytes.sublist(36, 40)), 'data');
    final pcmBytes = header.getUint32(40, Endian.little);
    expect(pcmBytes, 1440000);
    expect(pcmBytes ~/ 2 ~/ 16000, 45);
  });

  test('reviewed CC0 legal text is retained without drift', () async {
    final license = await File(
      'assets/benchmarks/licenses/CC0-1.0.txt',
    ).readAsBytes();

    expect(license.length, 7048);
    expect(
      sha256.convert(license).toString(),
      'a2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499',
    );
  });
}
