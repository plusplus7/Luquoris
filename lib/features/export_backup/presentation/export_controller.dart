import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:loquiris/core/result.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

/// User-selected export format and latest local destination outcome.
@immutable
final class ExportViewState {
  /// Creates immutable export presentation state.
  const ExportViewState({
    this.selectedFormat = ExportFormat.archive,
    this.isExporting = false,
    this.isCancelling = false,
    this.operationId,
    this.progress,
    this.receipt,
    this.failureCode,
  });

  /// Format explicitly selected by the user.
  final ExportFormat selectedFormat;

  /// Whether the system destination picker or local write is active.
  final bool isExporting;

  /// Whether a cooperative cancellation request is being submitted.
  final bool isCancelling;

  /// Identity of the active durable operation.
  final String? operationId;

  /// Latest privacy-safe native progress snapshot.
  final ExportProgress? progress;

  /// Latest successful user-authorized export.
  final ExportReceipt? receipt;

  /// Stable latest failure code, including explicit picker cancellation.
  final String? failureCode;

  /// Returns state for a new selection or operation outcome.
  ExportViewState copyWith({
    ExportFormat? selectedFormat,
    bool? isExporting,
    bool? isCancelling,
    String? operationId,
    ExportProgress? progress,
    ExportReceipt? receipt,
    String? failureCode,
    bool clearOutcome = false,
    bool clearOperation = false,
  }) => ExportViewState(
    selectedFormat: selectedFormat ?? this.selectedFormat,
    isExporting: isExporting ?? this.isExporting,
    isCancelling: isCancelling ?? this.isCancelling,
    operationId: clearOperation ? null : operationId ?? this.operationId,
    progress: clearOperation ? null : progress ?? this.progress,
    receipt: clearOutcome ? null : receipt ?? this.receipt,
    failureCode: clearOutcome ? null : failureCode ?? this.failureCode,
  );
}

/// Owns one explicit meeting export choice and typed operation outcome.
final class ExportController extends Notifier<ExportViewState> {
  /// Creates a route-scoped controller for [meetingId].
  ExportController(this.meetingId);

  /// Meeting selected by the route.
  final String meetingId;

  Timer? _progressTimer;
  bool _statusInFlight = false;

  @override
  ExportViewState build() {
    ref.onDispose(() => _progressTimer?.cancel());
    final history = ref.read(exportFailureHistoryProvider);
    scheduleMicrotask(() => _restoreLatestFailure(history));
    return const ExportViewState();
  }

  Future<void> _restoreLatestFailure(ExportFailureHistoryReader history) async {
    final result = await history(meetingId);
    if (!ref.mounted || state.isExporting || state.failureCode != null) return;
    if (result case Ok(:final value?)) {
      state = state.copyWith(failureCode: value);
    }
  }

  /// Changes the representation before destination confirmation.
  void select(ExportFormat format) {
    if (state.isExporting || state.selectedFormat == format) return;
    state = state.copyWith(selectedFormat: format, clearOutcome: true);
  }

  /// Opens the system destination and writes only after user confirmation.
  Future<void> exportSelected() async {
    if (state.isExporting) return;
    final format = state.selectedFormat;
    final operationId = const Uuid().v4();
    state = state.copyWith(
      isExporting: true,
      isCancelling: false,
      operationId: operationId,
      clearOutcome: true,
    );
    _progressTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => unawaited(_refreshProgress(operationId)),
    );
    final result = await ref
        .read(exportServiceProvider)
        .export(
          ExportRequest(
            operationId: operationId,
            createdAtUtcMs: ref
                .read(clockProvider)
                .now()
                .toUtc()
                .millisecondsSinceEpoch,
            sessionId: meetingId,
            format: format,
          ),
        );
    _progressTimer?.cancel();
    _progressTimer = null;
    if (!ref.mounted) return;
    state = switch (result) {
      Ok(:final value) => state.copyWith(
        isExporting: false,
        isCancelling: false,
        receipt: value,
        clearOperation: true,
      ),
      Err(:final failure) => state.copyWith(
        isExporting: false,
        isCancelling: false,
        failureCode: failure.code,
        clearOperation: true,
      ),
    };
  }

  /// Requests safe cooperative cancellation of the active native write.
  Future<void> cancel() async {
    final operationId = state.operationId;
    if (!state.isExporting ||
        state.isCancelling ||
        operationId == null ||
        state.progress?.cancellable != true) {
      return;
    }
    state = state.copyWith(isCancelling: true);
    final result = await ref.read(exportServiceProvider).cancel(operationId);
    if (!ref.mounted || state.operationId != operationId) return;
    if (result case Err(:final failure)) {
      state = state.copyWith(
        isCancelling: false,
        failureCode: failure.code,
      );
    }
  }

  Future<void> _refreshProgress(String operationId) async {
    if (_statusInFlight ||
        !ref.mounted ||
        !state.isExporting ||
        state.operationId != operationId) {
      return;
    }
    _statusInFlight = true;
    try {
      final result = await ref.read(exportServiceProvider).status(operationId);
      if (!ref.mounted || state.operationId != operationId) return;
      if (result case Ok(:final value)) {
        state = state.copyWith(progress: value);
      }
    } finally {
      _statusInFlight = false;
    }
  }
}

/// Route-scoped state for one meeting's export surface.
final NotifierProviderFamily<ExportController, ExportViewState, String>
exportControllerProvider =
    NotifierProvider.family<ExportController, ExportViewState, String>(
      ExportController.new,
    );
