import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';

/// Offline live boundary; only an explicitly enabled composition root wires it.
final streamingTranscriptionEngineProvider =
    Provider<StreamingTranscriptionEngine>(
      (ref) => throw UnimplementedError(
        'StreamingTranscriptionEngine is not installed',
      ),
    );
