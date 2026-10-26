import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/services/refinement_audio_inventory_service.dart';
import 'package:loquiris/services/service_contracts.dart';

/// Rejects disagreement between durable meeting geometry and the complete native inventory.
String? refinementAudioInventoryRejection(
  SessionDetail detail,
  RefinementAudioInventory inventory,
) {
  if (detail.segments.isEmpty ||
      detail.segments.length != inventory.segmentCount ||
      inventory.totalSamples <= 0 ||
      inventory.totalSamples % 1024 != 0 ||
      inventory.totalSamples ~/ 1024 > _maximumFrames) {
    return 'refinement_audio_inventory_conflict';
  }
  var offsetFrames = 0;
  for (final (index, segment) in detail.segments.indexed) {
    final native = inventory.segments[index];
    final duration = segment.mediaDuration.inMicroseconds;
    if (segment.meetingId != detail.meeting.id ||
        segment.sequence != index ||
        segment.state != AudioSegmentState.committed ||
        segment.committedBytes <= 0 ||
        duration <= 0 ||
        duration % 64000 != 0 ||
        duration ~/ 64000 > _maximumFrames - offsetFrames ||
        segment.mediaStart.inMicroseconds != offsetFrames * 64000 ||
        native.index != index ||
        native.startSample % 1024 != 0 ||
        native.startSample ~/ 1024 != offsetFrames ||
        native.committedSamples <= 0 ||
        native.committedSamples % 1024 != 0 ||
        native.committedSamples ~/ 1024 != duration ~/ 64000 ||
        native.committedBytes != segment.committedBytes ||
        native.referenceSha256 !=
            sha256
                .convert(utf8.encode(segment.relativePath.value))
                .toString()) {
      return 'refinement_audio_inventory_incomplete';
    }
    offsetFrames += duration ~/ 64000;
  }
  if (offsetFrames != inventory.totalSamples ~/ 1024 ||
      detail.meeting.mediaDuration.inMicroseconds != offsetFrames * 64000) {
    return 'refinement_audio_inventory_conflict';
  }
  return null;
}

const int _maximumFrames = 0x7fffffffffffffff ~/ 64000;
