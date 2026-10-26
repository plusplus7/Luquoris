import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/misc.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/services/meeting_processing_selection_repository.dart';

import 'fakes/fake_meeting_processing_selection_repository.dart';

/// Supplies the installed production profile and a local choice store, not audio.
List<Override> recordingProcessingOverrides() => [
  transcriptionModelManifestProvider.overrideWithValue(
    (BundledModelManifest.tryParse(
              jsonDecode(
                File(
                  'models/manifests/whisper-base-q5_1.json',
                ).readAsStringSync(),
              ),
            )
            as Ok<BundledModelManifest, InvalidModelManifest>)
        .value,
  ),
  meetingProcessingSelectionRepositoryProvider.overrideWithValue(
    FakeMeetingProcessingSelectionRepository(),
  ),
];
