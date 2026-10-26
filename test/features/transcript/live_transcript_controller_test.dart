import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loquiris/core/result.dart';
import 'package:loquiris/features/models_performance/domain/model_manifest.dart';
import 'package:loquiris/features/sessions/domain/session_entities.dart';
import 'package:loquiris/features/transcript/application/live_transcript_session_starter.dart';
import 'package:loquiris/features/transcript/application/streaming_live_transcript_adapter.dart';
import 'package:loquiris/features/transcript/application/transcription_coordinator.dart';
import 'package:loquiris/features/transcript/presentation/live_transcript_controller.dart';
import 'package:loquiris/services/meeting_processing_selection_repository.dart';
import 'package:loquiris/services/service_contracts.dart';
import 'package:loquiris/services/service_providers.dart';
import 'package:loquiris/services/streaming_transcription_engine.dart';

import '../../support/fake_streaming_transcription_engine.dart';
import '../../support/fakes/fake_meeting_processing_selection_repository.dart';
import '../../support/fakes/fake_services.dart';

void main() {
  test('explicit cancellation wins over a pending startup finish', () async {
    final opening =
        Completer<Result<LiveTranscriptionSession?, TranscriptionFailure>>();
    var finishes = 0;
    var cancellations = 0;
    final harness = _Harness(starter: (_) => opening.future);
    addTearDown(harness.dispose);
    final starting = harness.start();
    final finishing = harness.controller.finish();
    await harness.controller.stop();
    opening.complete(
      Ok(
        LiveTranscriptionSession(
          meetingId: _Harness.meetingId,
          runId: 'cancelled-start',
          events: const Stream<TranscriptionEvent>.empty(),
          finish: () async {
            finishes++;
            return const Ok(null);
          },
          release: () async {
            cancellations++;
            return const Ok(null);
          },
        ),
      ),
    );
    await starting;
    await finishing;
    expect(finishes, 0);
    expect(cancellations, 1);
    expect(harness.state.status, LiveTranscriptStatus.stopped);
  });

  test(
    'pending startup finish cannot finish a replacement generation',
    () async {
      final opening =
          Completer<Result<LiveTranscriptionSession?, TranscriptionFailure>>();
      var starts = 0;
      var finishes = 0;
      final cancelled = <String>[];
      LiveTranscriptionSession session(String run) => LiveTranscriptionSession(
        meetingId: _Harness.meetingId,
        runId: run,
        events: const Stream<TranscriptionEvent>.empty(),
        finish: () async {
          finishes++;
          return const Ok(null);
        },
        release: () async {
          cancelled.add(run);
          return const Ok(null);
        },
      );
      final harness = _Harness(
        starter: (_) async {
          starts++;
          return starts == 1 ? opening.future : Ok(session('replacement'));
        },
      );
      addTearDown(harness.dispose);
      final finishing = harness.controller.finish();
      harness.container.invalidate(
        liveTranscriptControllerProvider(_Harness.meetingId),
      );
      await harness.start();
      opening.complete(Ok(session('old')));
      await finishing;
      await pumpEventQueue();
      expect(finishes, 0);
      expect(cancelled, ['old']);
      expect(harness.state.runId, 'replacement');
      await harness.controller.stop();
      expect(cancelled, ['old', 'replacement']);
    },
  );

  test(
    'normal finish during startup survives route exit and drains buffered final',
    () async {
      final opening =
          Completer<Result<LiveTranscriptionSession?, TranscriptionFailure>>();
      final ack = Completer<Result<void, TranscriptionFailure>>();
      final source = StreamController<TranscriptionEvent>();
      var finishes = 0;
      var cancellations = 0;
      final harness = _Harness(starter: (_) => opening.future);
      addTearDown(harness.dispose);
      addTearDown(() {
        if (!ack.isCompleted) ack.complete(const Ok(null));
        unawaited(source.close());
      });
      final starting = harness.start();
      final finishing = harness.controller.finish();
      harness.subscription.close();
      await pumpEventQueue();
      source.add(
        _draft(
          'late-stop',
          'u1',
          'Buffered endpoint',
          stability: TranscriptStability.stable,
        ),
      );
      opening.complete(
        Ok(
          LiveTranscriptionSession(
            meetingId: _Harness.meetingId,
            runId: 'late-stop',
            events: source.stream,
            finish: () async {
              finishes++;
              final result = await ack.future;
              unawaited(source.close());
              return result;
            },
            release: () async {
              cancellations++;
              return const Ok(null);
            },
          ),
        ),
      );
      await starting;
      await pumpEventQueue();
      expect(finishes, 1);
      expect(cancellations, 0);
      expect(harness.state.chunks.single.rawText, 'Buffered endpoint');
      ack.complete(const Ok(null));
      await finishing;
      await pumpEventQueue();
      expect(cancellations, 0);
    },
  );

  test(
    'normal finish drains the last final without treating STOP as cancellation',
    () async {
      final source = StreamController<TranscriptionEvent>();
      final ack = Completer<Result<void, TranscriptionFailure>>();
      var cancellations = 0;
      final harness = _Harness(
        starter: (meetingId) async => Ok(
          LiveTranscriptionSession(
            meetingId: meetingId,
            runId: 'finishing',
            events: source.stream,
            finish: () async {
              source.add(
                _draft(
                  'finishing',
                  'u1',
                  'Last endpoint final',
                  stability: TranscriptStability.stable,
                ),
              );
              final result = await ack.future;
              unawaited(source.close());
              return result;
            },
            release: () async {
              cancellations++;
              return const Ok(null);
            },
          ),
        ),
      );
      addTearDown(harness.dispose);
      await harness.start();
      final finishing = harness.controller.finish();
      await pumpEventQueue();
      expect(harness.state.chunks.single.rawText, 'Last endpoint final');
      expect(harness.state.status, LiveTranscriptStatus.running);
      expect(cancellations, 0);
      ack.complete(const Ok(null));
      await finishing;
      expect(harness.state.status, LiveTranscriptStatus.stopped);
      expect(harness.state.chunks.single.stability, TranscriptStability.stable);
    },
  );

  test(
    'dispose releases native ownership even when view detachment fails',
    () async {
      var releases = 0;
      final source = StreamController<TranscriptionEvent>(
        onCancel: () => throw StateError('synthetic detachment failure'),
      );
      final harness = _Harness(
        starter: (meetingId) async => Ok(
          LiveTranscriptionSession(
            meetingId: meetingId,
            runId: 'detach-error',
            events: source.stream,
            release: () async {
              releases++;
              return const Ok(null);
            },
          ),
        ),
      );
      await harness.start();
      await harness.dispose();
      await pumpEventQueue();
      expect(releases, 1);
      await source.close();
    },
  );

  test(
    'rebuild rejects a stale startup without replacing the current owner',
    () async {
      final first =
          Completer<Result<LiveTranscriptionSession?, TranscriptionFailure>>();
      final source = StreamController<TranscriptionEvent>.broadcast();
      final released = <String>[];
      LiveTranscriptionSession session(String run) => LiveTranscriptionSession(
        meetingId: _Harness.meetingId,
        runId: run,
        events: source.stream,
        release: () async {
          released.add(run);
          return const Ok(null);
        },
      );
      var starts = 0;
      final harness = _Harness(
        starter: (_) async {
          starts++;
          return starts == 1 ? first.future : Ok(session('new'));
        },
      );
      addTearDown(harness.dispose);
      addTearDown(source.close);
      await pumpEventQueue();
      harness.container.invalidate(
        liveTranscriptControllerProvider(_Harness.meetingId),
      );
      await harness.start();
      first.complete(Ok(session('old')));
      await pumpEventQueue();
      source.add(_draft('new', 'u', 'current text'));
      await pumpEventQueue();
      expect(released, contains('old'));
      expect(harness.state.runId, 'new');
      expect(harness.state.chunks.single.rawText, 'current text');
      await harness.controller.stop();
      expect(released, ['old', 'new']);
    },
  );

  test(
    'stop during startup closes the late session rather than reviving live UI',
    () async {
      final harness = _Harness(gateStart: true);
      addTearDown(harness.dispose);
      final starting = harness.start();
      await pumpEventQueue();
      final runId = harness.engine.draftRequests.single.runId;
      await harness.controller.stop();
      harness.engine.releaseStart();
      await starting;
      await pumpEventQueue();
      expect(harness.state.status, LiveTranscriptStatus.stopped);
      expect(harness.engine.stopDraftRequests, [runId]);
    },
  );

  test(
    'streaming text received before build settles is not lost by the UI',
    () async {
      final engine = _UiStreamingEngine();
      final adapter = StreamingLiveTranscriptAdapter(engine);
      const owner = StreamingOwner(
        meetingId: _Harness.meetingId,
        runId: 'stream-ui',
        epoch: 1,
      );
      final harness = _Harness(
        starter: (meetingId) async {
          final result = await adapter.open(
            const StreamingStartRequest(
              owner: owner,
              modelId: 'probe',
              bundleSha256:
                  '0000000000000000000000000000000000000000000000000000000000000000',
              parameterVersion: 1,
            ),
          );
          engine.native.deliver(
            StreamingUtterance(
              owner: owner,
              sequence: 0,
              utteranceId: 'first',
              start: Duration.zero,
              end: const Duration(seconds: 1),
              rawText: 'first captured words',
              status: StreamingUtteranceStatus.provisional,
            ),
          );
          return result;
        },
      );
      addTearDown(harness.dispose);
      await harness.start();
      await pumpEventQueue();
      expect(harness.state.chunks.single.rawText, 'first captured words');
      expect(harness.engine.draftRequests, isEmpty);
      await harness.controller.stop();
    },
  );

  test(
    'unconfirmed release stays degraded and can retry instead of claiming stopped',
    () async {
      var releases = 0;
      final harness = _Harness(
        starter: (meetingId) async => Ok(
          LiveTranscriptionSession(
            meetingId: meetingId,
            runId: 'uncertain',
            events: const Stream<TranscriptionEvent>.empty(),
            release: () async {
              releases++;
              return releases == 1
                  ? const Err(TranscriptionUnavailable('native_ack_missing'))
                  : const Ok(null);
            },
          ),
        ),
      );
      addTearDown(harness.dispose);
      await harness.start();
      await harness.controller.stop();
      expect(harness.state.status, LiveTranscriptStatus.degraded);
      expect(harness.state.incomplete, isTrue);
      expect(
        harness.state.degradationReason,
        'transcription_live_cleanup_unconfirmed',
      );
      await harness.controller.stop();
      expect(releases, 2);
      expect(harness.state.status, LiveTranscriptStatus.stopped);
      expect(harness.state.degradationReason, isNull);
    },
  );

  test(
    'explicit live source reaches the existing UI without opening the legacy engine',
    () async {
      final source = StreamController<TranscriptionEvent>();
      var releases = 0;
      final harness = _Harness(
        mode: MeetingTranscriptionMode.postSession,
        starter: (meetingId) async => Ok(
          LiveTranscriptionSession(
            meetingId: meetingId,
            runId: 'explicit-stream',
            events: source.stream,
            release: () async {
              releases++;
              return const Ok(null);
            },
          ),
        ),
      );
      addTearDown(harness.dispose);
      addTearDown(() {
        unawaited(source.close());
      });
      final state = await harness.start();
      expect(state.status, LiveTranscriptStatus.running);
      expect(state.runId, 'explicit-stream');
      source.add(_draft('explicit-stream', 'utterance', 'streaming text'));
      await pumpEventQueue();
      expect(harness.state.chunks.single.rawText, 'streaming text');
      expect(harness.engine.draftRequests, isEmpty);
      await harness.controller.stop();
      expect(releases, 1);
    },
  );

  test(
    'replaces unstable text and promotes the same segment to stable',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final state = await harness.start();

      harness.engine
        ..emit(_draft(state.runId!, 'segment-1', 'hel'))
        ..emit(_draft(state.runId!, 'segment-1', 'hello'))
        ..emit(
          _draft(
            state.runId!,
            'segment-1',
            'Hello.',
            stability: TranscriptStability.stable,
          ),
        );
      await pumpEventQueue();

      final updated = harness.state;
      expect(updated.chunks, hasLength(1));
      expect(updated.chunks.single.displayText, 'Hello.');
      expect(updated.chunks.single.stability, TranscriptStability.stable);
    },
  );

  test(
    'ignores foreign runs and keeps chunks in monotonic media order',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final state = await harness.start();

      harness.engine
        ..emit(_draft('foreign-run', 'foreign', 'not ours'))
        ..emit(
          _draft(
            state.runId!,
            'segment-2',
            'second',
            start: const Duration(seconds: 2),
            end: const Duration(seconds: 3),
          ),
        )
        ..emit(_draft(state.runId!, 'segment-1', 'first'));
      await pumpEventQueue();

      expect(
        harness.state.chunks.map((chunk) => chunk.segmentId),
        <String>['segment-1', 'segment-2'],
      );
    },
  );

  test(
    'reports backlog and explicit incomplete post-session fallback',
    () async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      final state = await harness.start();

      harness.engine
        ..emit(
          _draft(
            state.runId!,
            'segment-1',
            'delayed',
            backlog: const Duration(seconds: 4),
          ),
        )
        ..emit(
          TranscriptionDraftDegraded(
            runId: state.runId!,
            reason: 'transcription_live_backlog',
            backlog: const Duration(seconds: 7),
            incomplete: true,
          ),
        );
      await pumpEventQueue();

      expect(harness.state.backlog, const Duration(seconds: 7));
      expect(harness.state.isBacklogged, isTrue);
      expect(harness.state.incomplete, isTrue);
      expect(harness.state.fallbackArmed, isTrue);
      expect(
        harness.state.degradationReason,
        'transcription_live_backlog',
      );
    },
  );

  test(
    'surfaces thermal and model failures without disarming fallback',
    () async {
      final thermal = _Harness();
      addTearDown(thermal.dispose);
      final thermalState = await thermal.start();
      thermal.engine.emit(
        TranscriptionDraftDegraded(
          runId: thermalState.runId!,
          reason: 'transcription_live_thermal',
          backlog: Duration.zero,
          incomplete: true,
        ),
      );
      await pumpEventQueue();

      expect(thermal.state.status, LiveTranscriptStatus.degraded);
      expect(thermal.state.fallbackArmed, isTrue);

      final model = _Harness(
        startResult: const Err(
          TranscriptionUnavailable('transcription_model_load_failed'),
        ),
      );
      addTearDown(model.dispose);
      final modelState = await model.start();

      expect(modelState.status, LiveTranscriptStatus.degraded);
      expect(modelState.degradationReason, 'transcription_model_load_failed');
      expect(modelState.fallbackArmed, isTrue);
    },
  );

  test('stop releases the run and ignores every late event', () async {
    final harness = _Harness();
    addTearDown(harness.dispose);
    final started = await harness.start();
    harness.engine.emit(_draft(started.runId!, 'segment-1', 'before stop'));
    await pumpEventQueue();

    await harness.controller.stop();
    harness.engine.emit(_draft(started.runId!, 'segment-2', 'too late'));
    await pumpEventQueue();

    expect(harness.engine.stopDraftRequests, <String>[started.runId!]);
    expect(harness.state.status, LiveTranscriptStatus.stopped);
    expect(
      harness.state.chunks.map((chunk) => chunk.segmentId),
      <String>['segment-1'],
    );
  });

  test('post-session meetings never open the live engine', () async {
    final harness = _Harness(mode: MeetingTranscriptionMode.postSession);
    addTearDown(harness.dispose);

    final state = await harness.start();

    expect(state.status, LiveTranscriptStatus.inactive);
    expect(state.fallbackArmed, isTrue);
    expect(harness.engine.draftRequests, isEmpty);
  });

  test(
    'owner disposal during start releases the late native session',
    () async {
      final harness = _Harness(gateStart: true);
      final starting = harness.start();
      await pumpEventQueue();
      expect(harness.engine.draftRequests, hasLength(1));
      final runId = harness.engine.draftRequests.single.runId;

      harness.subscription.close();
      harness.container.dispose();
      harness.engine.releaseStart();
      await starting.catchError((_) => _inactiveState());
      await pumpEventQueue();

      expect(harness.engine.stopDraftRequests, <String>[runId]);
      await harness.engine.dispose();
      await harness.jobs.dispose();
    },
  );
}

TranscriptionDraftUpdated _draft(
  String runId,
  String segmentId,
  String text, {
  Duration start = Duration.zero,
  Duration end = const Duration(seconds: 1),
  Duration backlog = Duration.zero,
  TranscriptStability stability = TranscriptStability.unstable,
}) => TranscriptionDraftUpdated(
  runId: runId,
  chunk: TranscriptChunk(
    segmentId: segmentId,
    start: start,
    end: end,
    rawText: text,
    displayText: text,
    stability: stability,
  ),
  backlog: backlog,
);

final class _Harness {
  _Harness({
    MeetingTranscriptionMode mode = MeetingTranscriptionMode.nearRealTime,
    Result<void, TranscriptionFailure> startResult = const Ok(null),
    bool gateStart = false,
    LiveTranscriptSessionStarter? starter,
  }) : engine = _LiveEngine(
         startResult: startResult,
         gateStart: gateStart,
       ) {
    sessions.detailResult = Ok(
      SessionDetail(
        meeting: Meeting(
          id: meetingId,
          title: 'Meeting',
          createdAtUtcMs: 1,
          mediaDuration: Duration.zero,
          lifecycle: MeetingLifecycle.recording,
          languageMode: MeetingLanguageMode.mixed,
          transcriptionMode: mode,
        ),
        segments: const <AudioSegment>[],
        events: const <SessionEvent>[],
        bookmarks: const <Bookmark>[],
        processingJobs: const [],
        recoveryDiagnostics: const <SessionRecoveryDiagnostic>[],
      ),
    );
    container = ProviderContainer.test(
      overrides: [
        clockProvider.overrideWithValue(Clock.fixed(DateTime.utc(2026))),
        sessionRepositoryProvider.overrideWithValue(sessions),
        transcriptionJobRepositoryProvider.overrideWithValue(jobs),
        meetingProcessingSelectionRepositoryProvider.overrideWithValue(
          FakeMeetingProcessingSelectionRepository(),
        ),
        transcriptionEngineProvider.overrideWithValue(engine),
        transcriptionModelManifestProvider.overrideWithValue(_manifest()),
        if (starter != null)
          liveTranscriptSessionStarterProvider.overrideWithValue(starter),
      ],
    );
    subscription = container.listen(
      liveTranscriptControllerProvider(meetingId),
      (_, _) {},
      fireImmediately: true,
    );
  }

  static const meetingId = 'meeting-live';
  final FakeSessionRepository sessions = FakeSessionRepository();
  final FakeTranscriptionJobRepository jobs = FakeTranscriptionJobRepository();
  final _LiveEngine engine;
  late final ProviderContainer container;
  late final ProviderSubscription<AsyncValue<LiveTranscriptState>> subscription;

  LiveTranscriptController get controller =>
      container.read(liveTranscriptControllerProvider(meetingId).notifier);

  LiveTranscriptState get state =>
      container.read(liveTranscriptControllerProvider(meetingId)).requireValue;

  Future<LiveTranscriptState> start() =>
      container.read(liveTranscriptControllerProvider(meetingId).future);

  Future<void> dispose() async {
    subscription.close();
    container.dispose();
    await engine.dispose();
    await jobs.dispose();
  }
}

final class _LiveEngine implements TranscriptionEngine {
  _LiveEngine({required this.startResult, required bool gateStart})
    : _startGate = gateStart ? Completer<void>() : null;

  final Result<void, TranscriptionFailure> startResult;
  final Completer<void>? _startGate;
  final StreamController<TranscriptionEvent> _events =
      StreamController<TranscriptionEvent>.broadcast(sync: true);
  final List<TranscriptionDraftRequest> draftRequests = [];
  final List<String> stopDraftRequests = [];

  void emit(TranscriptionEvent event) => _events.add(event);

  @override
  Stream<TranscriptionEvent> eventsFor(String runId) => _events.stream;

  @override
  Future<Result<void, TranscriptionFailure>> startDraft(
    TranscriptionDraftRequest request,
  ) async {
    draftRequests.add(request);
    await _startGate?.future;
    return startResult;
  }

  void releaseStart() => _startGate?.complete();

  @override
  Future<Result<void, TranscriptionFailure>> stopDraft(String runId) async {
    stopDraftRequests.add(runId);
    return const Ok(null);
  }

  @override
  Future<Result<TranscriptionOutput, TranscriptionFailure>> transcribe(
    TranscriptionRequest request,
  ) async => Ok(TranscriptionOutput(chunks: []));

  @override
  Future<Result<void, TranscriptionFailure>> cancel(String runId) async =>
      const Ok(null);

  Future<void> dispose() => _events.close();
}

BundledModelManifest _manifest() =>
    (BundledModelManifest.tryParse(<String, Object?>{
              'schemaVersion': 1,
              'id': 'whisper-base-q5_1',
              'version': 'model-commit',
              'source': 'https://example.test/model.bin',
              'artifactPath': 'models/whisper-base-q5_1/model.bin',
              'sha256':
                  '0000000000000000000000000000000000000000000000000000000000000000',
              'bytes': 3,
              'runtime': <String, Object?>{
                'engineId': 'whisper_cpp',
                'modelFormat': 'ggml',
              },
              'license': <String, Object?>{
                'id': 'MIT',
                'snapshotPath': 'models/licenses/model.txt',
              },
              'capabilities': <Object?>['transcription'],
              'enabledModes': <Object?>['postSession'],
            })
            as Ok<BundledModelManifest, InvalidModelManifest>)
        .value;

LiveTranscriptState _inactiveState() => LiveTranscriptState(
  status: LiveTranscriptStatus.inactive,
  meetingId: _Harness.meetingId,
  chunks: const [],
);

final class _UiStreamingEngine implements StreamingTranscriptionEngine {
  late FakeStreamingSession native;
  @override
  Future<Result<StreamingSession, StreamingFailure>> open(
    StreamingStartRequest request,
  ) async {
    native = FakeStreamingSession(request.owner, () {});
    return Ok(native);
  }
}
