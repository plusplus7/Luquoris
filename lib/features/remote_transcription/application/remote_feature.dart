import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Enables remote defaults only when the composition root installs the backend.
final remoteTranscriptionEnabledProvider = Provider<bool>((ref) => false);
