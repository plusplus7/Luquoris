/// Canonical, deep-linkable application locations.
abstract final class AppRoutes {
  /// Meeting library.
  static const sessions = '/sessions';

  /// New-recording setup.
  static const newRecording = '/recordings/new';

  /// Model and performance settings.
  static const modelsPerformance = '/settings/models-performance';

  /// Storage and privacy settings.
  static const storagePrivacy = '/settings/storage-privacy';

  /// Active recording and its live draft.
  static String activeRecording(String meetingId) =>
      '/recordings/${Uri.encodeComponent(meetingId)}';

  /// Saved meeting detail.
  static String session(String meetingId) =>
      '/sessions/${Uri.encodeComponent(meetingId)}';

  /// Transcript and label editor for a saved meeting.
  static String editor(String meetingId) => '${session(meetingId)}/edit';

  /// Retained transcript versions and explicit current selection.
  static String transcriptVersions(String meetingId) =>
      '${session(meetingId)}/versions';

  /// Export flow for a saved meeting.
  static String export(String meetingId) => '${session(meetingId)}/export';
}
