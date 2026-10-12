import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loquiris/features/recording/presentation/new_recording_controller.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/l10n/app_localizations.dart';
import 'package:loquiris/l10n/meeting_formatting.dart';
import 'package:loquiris/routing/routes.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:loquiris/theme/components/loquiris_adaptive_page.dart';
import 'package:loquiris/theme/loquiris_tokens.dart';

/// Local recording setup with remembered processing choices.
final class NewRecordingScreen extends ConsumerWidget {
  /// Creates the new-recording setup screen.
  const NewRecordingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(newRecordingControllerProvider, (previous, next) {
      final meetingId = next.value?.startedMeetingId;
      if (meetingId != null &&
          meetingId != previous?.value?.startedMeetingId &&
          context.mounted) {
        context.go(AppRoutes.activeRecording(meetingId));
      }
    });
    final snapshot = ref.watch(newRecordingControllerProvider);
    final content = switch (snapshot) {
      AsyncData(:final value) => _NewRecordingForm(
        state: value,
        onSelectTranscriptionMode: (mode) => ref
            .read(newRecordingControllerProvider.notifier)
            .selectTranscriptionMode(mode),
        onSelectLanguageMode: (mode) => ref
            .read(newRecordingControllerProvider.notifier)
            .selectLanguageMode(mode),
        onSelectExpectedSpeakerCount: (count) => ref
            .read(newRecordingControllerProvider.notifier)
            .selectExpectedSpeakerCount(count),
        onStart: () => ref
            .read(newRecordingControllerProvider.notifier)
            .start(
              title: localizedMeetingDefaultTitle(
                context,
                ref.read(clockProvider).now().toLocal(),
              ),
            ),
      ),
      AsyncError() => _NewRecordingLoadFailure(
        onRetry: () => ref.invalidate(newRecordingControllerProvider),
      ),
      _ => const _NewRecordingLoading(),
    };
    return LoquirisAdaptivePage(
      key: const ValueKey<String>('new-recording'),
      child: content,
    );
  }
}

final class _NewRecordingForm extends StatelessWidget {
  const _NewRecordingForm({
    required this.state,
    required this.onSelectTranscriptionMode,
    required this.onSelectLanguageMode,
    required this.onSelectExpectedSpeakerCount,
    required this.onStart,
  });

  final NewRecordingState state;
  final ValueChanged<MeetingTranscriptionMode> onSelectTranscriptionMode;
  final ValueChanged<MeetingLanguageMode> onSelectLanguageMode;
  final ValueChanged<int?> onSelectExpectedSpeakerCount;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = LoquirisSpacing.of(context);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.newRecordingTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: spacing.related),
              Text(l10n.newRecordingIntro),
              SizedBox(height: spacing.section),
              _SectionLabel(l10n.transcriptionModeLabel),
              SizedBox(height: spacing.related),
              _ModeChoice(
                key: const Key('new-recording-mode-near-real-time'),
                label: l10n.nearRealTimeMode,
                description: l10n.nearRealTimeModeDescription,
                selected:
                    state.transcriptionMode ==
                    MeetingTranscriptionMode.nearRealTime,
                onSelected: () => onSelectTranscriptionMode(
                  MeetingTranscriptionMode.nearRealTime,
                ),
              ),
              SizedBox(height: spacing.related),
              _ModeChoice(
                key: const Key('new-recording-mode-post-session'),
                label: l10n.postSessionMode,
                description: l10n.postSessionModeDescription,
                selected:
                    state.transcriptionMode ==
                    MeetingTranscriptionMode.postSession,
                onSelected: () => onSelectTranscriptionMode(
                  MeetingTranscriptionMode.postSession,
                ),
              ),
              SizedBox(height: spacing.section),
              _SectionLabel(l10n.languageModeLabel),
              SizedBox(height: spacing.related),
              Wrap(
                spacing: spacing.related,
                runSpacing: spacing.related,
                children: [
                  _ChoiceChip(
                    key: const Key('new-recording-language-chinese'),
                    label: l10n.languageChinese,
                    selected: state.languageMode == MeetingLanguageMode.chinese,
                    onSelected: () =>
                        onSelectLanguageMode(MeetingLanguageMode.chinese),
                  ),
                  _ChoiceChip(
                    key: const Key('new-recording-language-english'),
                    label: l10n.languageEnglish,
                    selected: state.languageMode == MeetingLanguageMode.english,
                    onSelected: () =>
                        onSelectLanguageMode(MeetingLanguageMode.english),
                  ),
                  _ChoiceChip(
                    key: const Key('new-recording-language-mixed'),
                    label: l10n.languageMixed,
                    selected: state.languageMode == MeetingLanguageMode.mixed,
                    onSelected: () =>
                        onSelectLanguageMode(MeetingLanguageMode.mixed),
                  ),
                ],
              ),
              SizedBox(height: spacing.section),
              _SectionLabel(l10n.speakerCountLabel),
              SizedBox(height: spacing.related),
              Wrap(
                spacing: spacing.related,
                runSpacing: spacing.related,
                children: [
                  _ChoiceChip(
                    key: const Key('new-recording-speakers-auto'),
                    label: l10n.speakerCountAutomatic,
                    selected: state.expectedSpeakerCount == null,
                    onSelected: () => onSelectExpectedSpeakerCount(null),
                  ),
                  for (var count = 2; count <= 6; count += 1)
                    _ChoiceChip(
                      key: Key('new-recording-speakers-$count'),
                      label: l10n.speakerCountOption(count),
                      selected: state.expectedSpeakerCount == count,
                      onSelected: () => onSelectExpectedSpeakerCount(count),
                    ),
                ],
              ),
              SizedBox(height: spacing.section),
              _OfflineNote(l10n.newRecordingOfflineNote),
              if (state.status == NewRecordingStatus.submitting) ...[
                SizedBox(height: spacing.related),
                Semantics(
                  liveRegion: true,
                  child: Row(
                    children: [
                      const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: spacing.related),
                      Flexible(child: Text(l10n.recordingPreflightProgress)),
                    ],
                  ),
                ),
              ],
              if (state.status == NewRecordingStatus.failed) ...[
                SizedBox(height: spacing.related),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _failureMessage(l10n, state.failure),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              SizedBox(height: spacing.section),
              SizedBox(
                width: double.infinity,
                child: Semantics(
                  button: true,
                  enabled: state.canStart,
                  label: l10n.startRecordingNowAction,
                  onTap: state.canStart ? onStart : null,
                  excludeSemantics: true,
                  child: FilledButton.icon(
                    key: const Key('new-recording-start'),
                    onPressed: state.canStart ? onStart : null,
                    icon: const ExcludeSemantics(
                      child: Icon(Icons.mic_rounded),
                    ),
                    label: Text(l10n.startRecordingNowAction),
                  ),
                ),
              ),
              SizedBox(height: spacing.page),
            ],
          ),
        ),
      ],
    );
  }
}

String _failureMessage(
  AppLocalizations l10n,
  NewRecordingFailure? failure,
) => switch (failure) {
  NewRecordingCaptureFailure(code: 'recording_permission_denied') =>
    l10n.recordingMicrophonePermissionDenied,
  NewRecordingCaptureFailure(
    availableBytes: final available?,
    requiredBytes: final required?,
  ) =>
    l10n.recordingStoragePreflightFailed(
      _formatStorageBytes(available),
      _formatStorageBytes(required),
    ),
  NewRecordingCaptureFailure(requiredBytes: final required?) =>
    l10n.recordingStorageRequired(_formatStorageBytes(required)),
  NewRecordingCaptureOutcomeUnknown() => l10n.recordingStartOutcomeUnknown,
  NewRecordingCleanupFailure() => l10n.recordingSetupCleanupFailed,
  _ => l10n.newRecordingStartFailed,
};

String _formatStorageBytes(int bytes) {
  const bytesPerMegabyte = 1024 * 1024;
  if (bytes < bytesPerMegabyte) return '$bytes B';
  final megabytes = bytes / bytesPerMegabyte;
  final displayed = megabytes == megabytes.roundToDouble()
      ? megabytes.toStringAsFixed(0)
      : megabytes.toStringAsFixed(1);
  return '$displayed MB';
}

final class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.titleMedium,
  );
}

final class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.label,
    required this.description,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '$label. $description',
    onTap: onSelected,
    excludeSemantics: true,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelected,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: EdgeInsetsDirectional.all(
              LoquirisSpacing.of(context).section,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                ),
                SizedBox(width: LoquirisSpacing.of(context).related),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      SizedBox(height: LoquirisSpacing.of(context).compact),
                      Text(description),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

final class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    onTap: onSelected,
    excludeSemantics: true,
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    ),
  );
}

final class _OfflineNote extends StatelessWidget {
  const _OfflineNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        Icons.lock_outline_rounded,
        semanticLabel: AppLocalizations.of(context).storagePrivacyTitle,
      ),
      SizedBox(width: LoquirisSpacing.of(context).related),
      Expanded(child: Text(message)),
    ],
  );
}

final class _NewRecordingLoading extends StatelessWidget {
  const _NewRecordingLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(),
  );
}

final class _NewRecordingLoadFailure extends StatelessWidget {
  const _NewRecordingLoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.newRecordingLoadError, textAlign: TextAlign.center),
          SizedBox(height: LoquirisSpacing.of(context).related),
          Semantics(
            button: true,
            label: l10n.retryAction,
            onTap: onRetry,
            excludeSemantics: true,
            child: FilledButton(
              onPressed: onRetry,
              child: Text(l10n.retryAction),
            ),
          ),
        ],
      ),
    );
  }
}
