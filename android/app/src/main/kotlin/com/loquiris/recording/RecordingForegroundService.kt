package com.loquiris.recording

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import com.loquiris.BuildConfig
import com.loquiris.MainActivity
import com.loquiris.R
import java.io.File
import java.util.UUID

sealed interface RecordingForegroundServiceStartResult {
    data class RequestAccepted(
        val notificationVisibilityReduced: Boolean,
    ) : RecordingForegroundServiceStartResult

    data class Failed(
        val code: String,
        val availableBytes: Long? = null,
        val requiredBytes: Long? = null,
    ) : RecordingForegroundServiceStartResult
}

class RecordingForegroundService : Service() {
    private lateinit var wakeLockLease: WakeLockLease
    private lateinit var stateInitialization: RecordingStateMachineInitialization
    private val ownership = RecordingServiceOwnership()
    private val progressHandler = Handler(Looper.getMainLooper())
    private val finalizationWorker = RecordingFinalizationWorker()
    private val liveInference = RecordingLiveInferenceLifecycle()
    private var stopFinalizationInFlight = false
    @Volatile private var serviceDestroyed = false
    private var runtime: RecordingSessionRuntime? = null
    private var capturePipeline: RecordingCapturePipeline? = null
    private var activeMachine: PersistedRecordingStateMachine? = null
    private var activeSessionId: String? = null
    private var interruptionPolicy = RecordingInterruptionPolicy()
    private var interruptionMonitor: AndroidRecordingInterruptionMonitor? = null
    private var storageFailureJournal: RecordingStorageFailureJournal? = null
    private var storageWarningActive = false
    private var thermalStatusListener: PowerManager.OnThermalStatusChangedListener? = null
    private val commandReceipts by lazy { RecordingCommandReceiptStore(this) }
    private val rejectedCommandReceipts = RecordingRejectedCommandDispatcher()
    private val progressTick =
        object : Runnable {
            override fun run() {
                val sessionRuntime = runtime ?: return
                val pipelineSnapshot = capturePipeline?.snapshot() ?: return
                activeSessionId?.let { sessionId ->
                    RecordingLiveInputHealthRegistry.publish(sessionId, pipelineSnapshot.inputHealth)
                }
                val pipelineState = pipelineSnapshot.state
                val storage =
                    RecordingStoragePolicy.active(
                        AndroidRecordingStorageSpace.availableBytes(this@RecordingForegroundService),
                    )
                when (
                    RecordingStorageServicePolicy.action(
                        pipelineFailed = RecordingCaptureFailurePolicy.requiresRecovery(pipelineState),
                        storage = storage,
                    )
                ) {
                    RecordingStorageServiceAction.recoverWithStorageReason -> {
                        persistActiveStorageFailure(storage as RecordingActiveStorageDecision.Critical)
                        handleCaptureFailure()
                        return
                    }
                    RecordingStorageServiceAction.recoverCaptureFailure -> {
                        handleCaptureFailure()
                        return
                    }
                    RecordingStorageServiceAction.safeFinalize -> {
                        handleCriticalStorage(storage as RecordingActiveStorageDecision.Critical)
                        return
                    }
                    RecordingStorageServiceAction.showWarning -> storageWarningActive = true
                    RecordingStorageServiceAction.continueRecording -> storageWarningActive = false
                }
                interruptionMonitor?.pollAudioMode()
                sessionRuntime.publishProgress()
                refreshNotification()
                progressHandler.postDelayed(this, PROGRESS_INTERVAL_MILLIS)
            }
        }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        wakeLockLease = WakeLockLease(AndroidWakeLockController(this))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val listener =
                PowerManager.OnThermalStatusChangedListener { status ->
                    if (status >= PowerManager.THERMAL_STATUS_SEVERE) {
                        activeSessionId?.let(liveInference::severeThermal)
                    }
                }
            thermalStatusListener = listener
            getSystemService(PowerManager::class.java)?.addThermalStatusListener(listener)
        }
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        return when (intent?.action) {
            ACTION_START -> handleStart(intent, startId, continuation = false)
            ACTION_CONTINUE -> handleStart(intent, startId, continuation = true)
            ACTION_PAUSE -> handlePause(intent, startId)
            ACTION_RESUME -> handleResume(intent, startId)
            ACTION_STOP -> handleStop(intent, startId)
            ACTION_CONFIRM_RESUME -> handleConfirmResume(intent, startId)
            ACTION_BOOKMARK -> handleBookmark(intent, startId)
            else -> rejectStart(startId)
        }
    }

    private fun handleStart(
        intent: Intent,
        startId: Int,
        continuation: Boolean,
    ): Int {
        val commandId = intent.getStringExtra(EXTRA_COMMAND_ID)
        val sessionId = intent.getStringExtra(EXTRA_SESSION_ID)
        if (commandId.isNullOrBlank()) return rejectStart(startId)
        if (sessionId.isNullOrBlank()) return rejectCommand(commandId, "recording_session_invalid", startId)
        if (!hasRecordAudioPermission()) return rejectCommand(commandId, "recording_permission_denied", startId)
        if (ownership.owns(sessionId)) {
            activeMachine?.snapshot()?.let { commandReceipts.succeeded(commandId, it) }
            return START_NOT_STICKY
        }
        if (!ownership.shouldStopAfterRejectedStart()) return rejectCommand(commandId, "recording_session_conflict", startId)

        // Satisfy Android's foreground-start deadline before any state load,
        // recovery commit or start commit can wait on storage. This notification
        // is transient and does not claim or overwrite the persisted recording.
        val promoted = RecordingForegroundPromotion.beforePreparation(
            ForegroundPromoter {
                startForeground(
                    NOTIFICATION_ID,
                    buildNotification(
                        sessionId,
                        NativeRecordingSnapshot(sessionId, NativeRecordingState.preparing, 0, 0, 0),
                    ),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
                )
            },
        ) {
            stateInitialization = PersistedRecordingStateMachine.create(
                SharedPreferencesRecordingStateStore(this),
            )
        }
        if (!promoted) return rejectCommand(commandId, "recording_foreground_promotion_failed", startId)

        val authoritativeStorage =
            RecordingStoragePolicy.preflight(AndroidRecordingStorageSpace.availableBytes(this))
        if (authoritativeStorage is RecordingStoragePreflightDecision.Denied) {
            RecordingStorageFailureJournal(
                AppPrivateRecordingStorageFailureSink(this, sessionId),
            ).persist(
                RecordingStorageFailureEvent(
                    sessionId = sessionId,
                    code = authoritativeStorage.code,
                    availableBytes = authoritativeStorage.availableBytes,
                    requiredBytes = authoritativeStorage.requiredBytes,
                    mediaElapsedMilliseconds = 0L,
                    wallClockEpochMilliseconds = System.currentTimeMillis().coerceAtLeast(0L),
                ),
            )
            commandReceipts.failed(
                commandId,
                authoritativeStorage.code,
                authoritativeStorage.availableBytes,
                authoritativeStorage.requiredBytes,
            )
            return rejectStart(startId)
        }

        val machine =
            (stateInitialization as? RecordingStateMachineInitialization.Success)?.machine
                ?: return rejectCommand(commandId, "recording_state_initialization_failed", startId)
        val recoveryEvidence =
            if (continuation) recoveryEvidence(sessionId) ?: return rejectCommand(
                commandId,
                "recording_continuation_evidence_unavailable",
                startId,
            ) else null
        val startResult =
            if (recoveryEvidence == null) {
                machine.start(sessionId)
            } else {
                machine.continueRecovered(
                    sessionId = sessionId,
                    elapsedMilliseconds = recoveryEvidence.first,
                    bytesWritten = recoveryEvidence.second,
                )
            }
        if (startResult is RecordingCommandResult.Failure) {
            return rejectCommand(commandId, startResult.code, startId)
        }
        val snapshot = (startResult as RecordingCommandResult.Success).snapshot
        RecordingProcessLiveness.claim(sessionId)
        if (!RecordingServiceStartPolicy.canOwnForeground(snapshot.state)) {
            RecordingProcessLiveness.release(sessionId)
            return rejectCommand(commandId, "recording_foreground_state_invalid", startId)
        }

        if (!wakeLockLease.acquire()) {
            commandReceipts.failed(commandId, "recording_wake_lock_failed")
            return failUnownedStart(machine, sessionId, startId)
        }
        val pipeline = createCapturePipeline(sessionId, continuation)
        if (pipeline == null) {
            wakeLockLease.release()
            commandReceipts.failed(commandId, "recording_capture_pipeline_failed")
            return failUnownedStart(machine, sessionId, startId)
        }
        if (!ownership.claim(sessionId)) {
            pipeline.close()
            wakeLockLease.release()
            commandReceipts.failed(commandId, "recording_session_conflict")
            return failUnownedStart(machine, sessionId, startId)
        }
        activeMachine = machine
        RecordingLiveInputHealthRegistry.clear(sessionId)
        activeSessionId = sessionId
        storageWarningActive = false
        stopFinalizationInFlight = false
        storageFailureJournal =
            RecordingStorageFailureJournal(
                AppPrivateRecordingStorageFailureSink(this, sessionId),
            )
        interruptionPolicy = RecordingInterruptionPolicy()
        runtime =
            RecordingSessionRuntime(
                machine = machine,
                timer =
                    MonotonicRecordingTimer(
                        initialElapsedMilliseconds = snapshot.elapsedMilliseconds,
                        elapsedRealtimeMillis = SystemClock::elapsedRealtime,
                    ),
                bytesWritten = { pipeline.snapshot().bytesWritten },
                bookmarkJournal =
                    RecordingBookmarkJournal(
                        AppPrivateRecordingBookmarkSink(this, sessionId),
                    ),
                wallClockEpochMillis = System::currentTimeMillis,
                interruptionJournal =
                    RecordingInterruptionJournal(
                        AppPrivateRecordingInterruptionSink(this, sessionId),
                    ),
            )
        capturePipeline = pipeline
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            (getSystemService(PowerManager::class.java)?.currentThermalStatus ?: 0) >=
            PowerManager.THERMAL_STATUS_SEVERE
        ) {
            liveInference.severeThermal(sessionId)
        }
        liveInference.attach(sessionId, pipeline)
        interruptionMonitor =
            AndroidRecordingInterruptionMonitor(this, progressHandler, ::handleInterruptionSignal)
        if (interruptionMonitor?.start() != true) {
            commandReceipts.failed(commandId, "recording_audio_focus_failed")
            return failOwnedCaptureStart(machine, pipeline, sessionId, startId, captureStarted = false)
        }
        if (pipeline.start() is RecordingCaptureCommandResult.Failure) {
            commandReceipts.failed(commandId, "recording_capture_start_failed")
            return failOwnedCaptureStart(machine, pipeline, sessionId, startId, captureStarted = false)
        }
        if (
            runtime?.captureStarted(pipeline.captureBoundaryElapsedRealtimeMillis()) is
                RecordingCommandResult.Failure
        ) {
            commandReceipts.failed(commandId, "recording_state_persist_failed")
            return failOwnedCaptureStart(machine, pipeline, sessionId, startId, captureStarted = true)
        }
        progressHandler.removeCallbacks(progressTick)
        progressHandler.postDelayed(progressTick, PROGRESS_INTERVAL_MILLIS)
        refreshNotification()
        commandReceipts.succeeded(commandId, machine.snapshot())
        return START_NOT_STICKY
    }

    private fun handlePause(
        intent: Intent,
        startId: Int,
    ): Int {
        val commandId = intent.getStringExtra(EXTRA_COMMAND_ID)
        val result = handleOwnedAction(intent, startId) { sessionRuntime ->
            val state = activeMachine?.snapshot()?.state ?: return@handleOwnedAction
            if (!RecordingInterruptionCommandPolicy.canApplyUserPause(state)) {
                refreshNotification()
                return@handleOwnedAction
            }
            val pipeline = capturePipeline ?: return@handleOwnedAction
            if (pipeline.pause() !is RecordingCaptureCommandResult.Success) {
                handleCaptureFailure()
                return@handleOwnedAction
            }
            if (
                sessionRuntime.pause(pipeline.captureBoundaryElapsedRealtimeMillis()) is
                    RecordingCommandResult.Failure
            ) {
                handleCaptureFailure()
                return@handleOwnedAction
            }
            refreshNotification()
        }
        if (commandId != null) completeOwnedCommand(commandId)
        return result
    }

    private fun handleResume(
        intent: Intent,
        startId: Int,
    ): Int {
        val commandId = intent.getStringExtra(EXTRA_COMMAND_ID)
        val result = handleOwnedAction(intent, startId) { sessionRuntime ->
            if (!reacquireFocusIfRequired() || !interruptionPolicy.canUserResume()) {
                refreshNotification()
                return@handleOwnedAction
            }
            val pipeline = capturePipeline ?: return@handleOwnedAction
            if (pipeline.resume() !is RecordingCaptureCommandResult.Success) {
                handleCaptureFailure()
                return@handleOwnedAction
            }
            if (
                sessionRuntime.resume(pipeline.captureBoundaryElapsedRealtimeMillis()) is
                    RecordingCommandResult.Failure
            ) {
                pipeline.pause()
            } else {
                interruptionPolicy.resetAfterManualResume()
            }
            refreshNotification()
        }
        if (commandId != null) completeOwnedCommand(commandId)
        return result
    }

    private fun handleStop(
        intent: Intent,
        startId: Int,
    ): Int {
        val commandId = intent.getStringExtra(EXTRA_COMMAND_ID) ?: return rejectStart(startId)
        val sessionId = intent.getStringExtra(EXTRA_SESSION_ID)
        val sessionRuntime = runtime
        val pipeline = capturePipeline
        val machine = activeMachine
        if (
            sessionId.isNullOrBlank() ||
            !ownership.owns(sessionId) ||
            sessionRuntime == null ||
            pipeline == null ||
            machine == null
        ) {
            commandReceipts.failed(commandId, "recording_session_missing")
            return rejectStart(startId)
        }
        if (stopFinalizationInFlight) {
            commandReceipts.failed(commandId, "recording_command_in_progress")
            return START_NOT_STICKY
        }

        progressHandler.removeCallbacks(progressTick)
        closeInterruptionMonitor()
        liveInference.recordingStopping(sessionId)
        if (machine.stop() is RecordingCommandResult.Failure) {
            commandReceipts.failed(commandId, "recording_stop_transition_failed")
            handleCaptureFailure()
            return START_NOT_STICKY
        }
        stopFinalizationInFlight = true
        refreshNotification()
        val accepted =
            finalizationWorker.submit {
                val capturePaused = pipeline.pause() is RecordingCaptureCommandResult.Success
                val stateStopping =
                    capturePaused &&
                        sessionRuntime.stop(
                            pipeline.captureBoundaryElapsedRealtimeMillis() ?: SystemClock.elapsedRealtime(),
                        ) is RecordingCommandResult.Success
                val audioFinalized = capturePaused && pipeline.finish() is RecordingCaptureCommandResult.Success
                val finalProgressPersisted =
                    stateStopping &&
                        audioFinalized &&
                        sessionRuntime.publishProgress() is RecordingCommandResult.Success
                if (finalProgressPersisted) {
                    RecordingM4aArtifactStatusStore(
                        AppPrivateRecordingStorage.sessionDirectory(this, sessionId),
                    ).publish(RecordingM4aArtifactStatus(RecordingM4aArtifactState.building))
                }
                val stateFinalized =
                    finalProgressPersisted && machine.markFinalized() is RecordingCommandResult.Success
                if (!stateFinalized) {
                    liveInference.recordingEnded(sessionId)
                    runCatching { pipeline.close() }
                    runCatching { machine.markRecoverable() }
                }
                if (stateFinalized) {
                    liveInference.recordingFinalized(sessionId)
                    commandReceipts.succeeded(commandId, machine.snapshot())
                    RecordingM4aRebuilder().rebuild(
                        AppPrivateRecordingStorage.sessionDirectory(this, sessionId),
                    )
                }
                progressHandler.post {
                    if (!stateFinalized) {
                        commandReceipts.failed(commandId, "recording_finalization_failed")
                    }
                    capturePipeline = null
                    runtime = null
                    activeMachine = null
                    RecordingLiveInputHealthRegistry.clear(sessionId)
                    activeSessionId = null
                    RecordingProcessLiveness.release(sessionId)
                    storageFailureJournal = null
                    storageWarningActive = false
                    stopFinalizationInFlight = false
                    ownership.release(sessionId)
                    wakeLockLease.release()
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelfResult(startId)
                    if (serviceDestroyed) finalizationWorker.close()
                }
            }
        if (!accepted) {
            stopFinalizationInFlight = false
            commandReceipts.failed(commandId, "recording_finalization_worker_unavailable")
            handleCaptureFailure()
        }
        return START_NOT_STICKY
    }

    private fun handleConfirmResume(
        intent: Intent,
        startId: Int,
    ): Int =
        handleOwnedAction(intent, startId) {
            val machine = activeMachine ?: return@handleOwnedAction
            if (!reacquireFocusIfRequired()) {
                refreshNotification()
                return@handleOwnedAction
            }
            applyInterruptionDecision(
                interruptionPolicy.onSignal(
                    RecordingInterruptionSignal.confirmationGranted,
                    machine.snapshot().state,
                ),
            )
        }

    private fun handleBookmark(
        intent: Intent,
        startId: Int,
    ): Int =
        handleOwnedAction(intent, startId) { sessionRuntime ->
            sessionRuntime.bookmark()
            refreshNotification()
        }

    private fun handleOwnedAction(
        intent: Intent,
        startId: Int,
        action: (RecordingSessionRuntime) -> Unit,
    ): Int {
        val sessionId = intent.getStringExtra(EXTRA_SESSION_ID)
        val sessionRuntime = runtime
        if (
            sessionId.isNullOrBlank() ||
            !ownership.owns(sessionId) ||
            sessionRuntime == null ||
            stopFinalizationInFlight
        ) {
            return rejectStart(startId)
        }
        action(sessionRuntime)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        progressHandler.removeCallbacks(progressTick)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            thermalStatusListener?.let { listener ->
                getSystemService(PowerManager::class.java)?.removeThermalStatusListener(listener)
            }
        }
        thermalStatusListener = null
        serviceDestroyed = true
        rejectedCommandReceipts.close()
        if (!stopFinalizationInFlight && activeSessionId != null) {
            scheduleRecoverableCleanup(stopService = false)
        } else if (!stopFinalizationInFlight) {
            finalizationWorker.close()
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun rejectStart(startId: Int): Int {
        if (ownership.shouldStopAfterRejectedStart()) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelfResult(startId)
        }
        return START_NOT_STICKY
    }

    private fun rejectCommand(commandId: String, code: String, startId: Int): Int {
        // stopSelfResult can leave a newer start queued. Never let receipt I/O
        // delay that start's promotion; active ownership still prevents stopping.
        return rejectedCommandReceipts.reject(
            stopRejectedStart = { rejectStart(startId) },
            persistReceipt = { commandReceipts.failed(commandId, code) },
        )
    }

    private fun completeOwnedCommand(commandId: String) {
        val snapshot = activeMachine?.snapshot()
        if (snapshot == null) {
            commandReceipts.failed(commandId, "recording_command_failed")
        } else {
            commandReceipts.succeeded(commandId, snapshot)
        }
    }

    private fun failUnownedStart(
        machine: PersistedRecordingStateMachine,
        sessionId: String,
        startId: Int,
    ): Int {
        machine.stop()
        machine.markFinalized()
        RecordingProcessLiveness.release(sessionId)
        stopForeground(STOP_FOREGROUND_REMOVE)
        return rejectStart(startId)
    }

    private fun failOwnedCaptureStart(
        machine: PersistedRecordingStateMachine,
        pipeline: RecordingCapturePipeline,
        sessionId: String,
        startId: Int,
        captureStarted: Boolean,
    ): Int {
        liveInference.recordingEnded(sessionId)
        val finalized =
            if (captureStarted) {
                pipeline.finish() is RecordingCaptureCommandResult.Success
            } else {
                pipeline.close()
                true
            }
        capturePipeline = null
        closeInterruptionMonitor()
        runtime?.publishProgress()
        machine.stop()
        if (finalized) machine.markFinalized()
        if (!finalized) machine.markRecoverable()
        runtime = null
        activeMachine = null
        RecordingLiveInputHealthRegistry.clear(sessionId)
        activeSessionId = null
        RecordingProcessLiveness.release(sessionId)
        storageFailureJournal = null
        storageWarningActive = false
        ownership.release(sessionId)
        wakeLockLease.release()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelfResult(startId)
        return START_NOT_STICKY
    }

    private fun handleCaptureFailure() {
        progressHandler.removeCallbacks(progressTick)
        scheduleRecoverableCleanup(stopService = true)
    }

    private fun scheduleRecoverableCleanup(stopService: Boolean) {
        if (stopFinalizationInFlight) return
        val sessionId = activeSessionId ?: return
        liveInference.recordingEnded(sessionId)
        val pipeline = capturePipeline
        val sessionRuntime = runtime
        val machine = activeMachine
        closeInterruptionMonitor()
        stopFinalizationInFlight = true
        val accepted =
            finalizationWorker.submit {
                runCatching { pipeline?.close() }
                runCatching { sessionRuntime?.publishProgress() }
                runCatching { machine?.markRecoverable() }
                progressHandler.post {
                    capturePipeline = null
                    runtime = null
                    activeMachine = null
                    RecordingLiveInputHealthRegistry.clear(sessionId)
                    activeSessionId = null
                    RecordingProcessLiveness.release(sessionId)
                    storageFailureJournal = null
                    storageWarningActive = false
                    stopFinalizationInFlight = false
                    ownership.release(sessionId)
                    wakeLockLease.release()
                    if (stopService) {
                        stopForeground(STOP_FOREGROUND_REMOVE)
                        stopSelf()
                    }
                    if (serviceDestroyed) finalizationWorker.close()
                }
            }
        if (!accepted) {
            runCatching { machine?.markRecoverable() }
            stopFinalizationInFlight = false
            RecordingProcessLiveness.release(sessionId)
            ownership.release(sessionId)
            wakeLockLease.release()
        }
    }

    private fun handleCriticalStorage(decision: RecordingActiveStorageDecision.Critical) {
        if (stopFinalizationInFlight) return
        progressHandler.removeCallbacks(progressTick)
        val sessionId = activeSessionId ?: return
        val pipeline = capturePipeline ?: return
        val sessionRuntime = runtime ?: return
        val machine = activeMachine ?: return
        closeInterruptionMonitor()
        liveInference.recordingEnded(sessionId)
        if (machine.stop() is RecordingCommandResult.Failure) {
            handleCaptureFailure()
            return
        }
        stopFinalizationInFlight = true
        refreshNotification()
        val accepted =
            finalizationWorker.submit {
                val pipelinePaused = pipeline.pause() is RecordingCaptureCommandResult.Success
                val runtimeStopped =
                    pipelinePaused &&
                        sessionRuntime.stop(
                            pipeline.captureBoundaryElapsedRealtimeMillis() ?: SystemClock.elapsedRealtime(),
                        ) is RecordingCommandResult.Success
                val reasonPersisted = runtimeStopped && persistActiveStorageFailure(decision)
                val audioFinalized = pipelinePaused && pipeline.finish() is RecordingCaptureCommandResult.Success
                if (reasonPersisted && audioFinalized) {
                    RecordingM4aArtifactStatusStore(
                        AppPrivateRecordingStorage.sessionDirectory(this, sessionId),
                    ).publish(
                        RecordingM4aArtifactStatus(
                            state = RecordingM4aArtifactState.failed,
                            failureCode = "recording_m4a_deferred_low_storage",
                        ),
                    )
                }
                val stateFinalized =
                    reasonPersisted &&
                        audioFinalized &&
                        sessionRuntime.publishProgress() is RecordingCommandResult.Success &&
                        machine.markFinalized() is RecordingCommandResult.Success
                if (!stateFinalized) {
                    runCatching { pipeline.close() }
                    runCatching { machine.markRecoverable() }
                }
                progressHandler.post {
                    capturePipeline = null
                    runtime = null
                    activeMachine = null
                    RecordingLiveInputHealthRegistry.clear(sessionId)
                    activeSessionId = null
                    RecordingProcessLiveness.release(sessionId)
                    storageFailureJournal = null
                    storageWarningActive = false
                    stopFinalizationInFlight = false
                    ownership.release(sessionId)
                    wakeLockLease.release()
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                    if (serviceDestroyed) finalizationWorker.close()
                }
            }
        if (!accepted) {
            stopFinalizationInFlight = false
            handleCaptureFailure()
        }
    }

    private fun persistActiveStorageFailure(decision: RecordingActiveStorageDecision.Critical): Boolean {
        val sessionId = activeSessionId ?: return false
        val progress = runtime?.snapshot() ?: return false
        return storageFailureJournal?.persist(
            RecordingStorageFailureEvent(
                sessionId = sessionId,
                code = decision.code,
                availableBytes = decision.availableBytes,
                requiredBytes = decision.requiredBytes,
                mediaElapsedMilliseconds = progress.elapsedMilliseconds,
                wallClockEpochMilliseconds = System.currentTimeMillis().coerceAtLeast(0L),
            ),
        ) == true
    }

    private fun createCapturePipeline(
        sessionId: String,
        continuation: Boolean,
    ): RecordingCapturePipeline? {
        val source =
            when (
                val created =
                    AndroidAudioRecordSource.create(this) { silenced ->
                        handleInterruptionSignal(
                            if (silenced) {
                                RecordingInterruptionSignal.microphoneSilenced
                            } else {
                                RecordingInterruptionSignal.microphoneAvailable
                            },
                        )
                    }
            ) {
                is PcmCaptureSourceCreateResult.Success -> created.source
                is PcmCaptureSourceCreateResult.Failure -> return null
            }
        val encoder =
            when (
                val created =
                    AndroidAacSegmentEncoder.create(
                        directory = AppPrivateRecordingStorage.sessionDirectory(this, sessionId),
                        sessionId = sessionId,
                        continuation = continuation,
                    )
            ) {
                is RecordingEncoderCreateResult.Success -> created.encoder
                is RecordingEncoderCreateResult.Failure -> {
                    source.release()
                    return null
                }
            }
        return RecordingCapturePipeline(
            source = source,
            encoder = AndroidCanonicalPcmEncoder(encoder),
            inferenceQueueCapacity =
                RecordingInferenceQueuePolicy.capacityFrames(
                    isDebugBuild = BuildConfig.DEBUG,
                    streamingNativeSpike = BuildConfig.LOQUIRIS_STREAMING_NATIVE_SPIKE,
                ),
            elapsedRealtimeNanos = SystemClock::elapsedRealtimeNanos,
        )
    }

    private fun recoveryEvidence(sessionId: String): Pair<Long, Long>? {
        val evidence =
            RecordingStartupReconciler(
                File(filesDir, "recordings"),
            ).scan().sessions.singleOrNull { it.meetingId == sessionId } ?: return null
        val endSample = evidence.segments.maxOfOrNull { it.startSample + it.committedSamples } ?: 0L
        val elapsedMilliseconds = endSample * 1_000L / evidence.sampleRateHz
        val bytesWritten = evidence.segments.sumOf { it.committedBytes }
        return elapsedMilliseconds to bytesWritten
    }

    private fun handleInterruptionSignal(signal: RecordingInterruptionSignal) {
        val machine = activeMachine ?: return
        applyInterruptionDecision(interruptionPolicy.onSignal(signal, machine.snapshot().state))
    }

    private fun applyInterruptionDecision(decision: RecordingInterruptionDecision) {
        val pipeline = capturePipeline ?: return
        val sessionRuntime = runtime ?: return
        if (decision.shouldPause) {
            if (pipeline.pause(decision.inferenceBoundary() ?: PcmCaptureBoundary.DISCONTINUITY) !is RecordingCaptureCommandResult.Success) {
                handleCaptureFailure()
                return
            }
            if (
                sessionRuntime.pauseForInterruption(pipeline.captureBoundaryElapsedRealtimeMillis()) is
                    RecordingCommandResult.Failure
            ) {
                for (marker in decision.markers) {
                    sessionRuntime.recordInterruption(marker.source, marker.phase)
                }
                handleCaptureFailure()
                return
            }
        }
        for (marker in decision.markers) {
            if (!sessionRuntime.recordInterruption(marker.source, marker.phase)) {
                handleCaptureFailure()
                return
            }
        }
        if (decision.shouldResume) {
            if (pipeline.resume() !is RecordingCaptureCommandResult.Success) {
                handleCaptureFailure()
                return
            }
            if (
                sessionRuntime.resumeFromInterruption(pipeline.captureBoundaryElapsedRealtimeMillis()) is
                    RecordingCommandResult.Failure
            ) {
                handleCaptureFailure()
                return
            }
        }
        refreshNotification()
    }

    private fun closeInterruptionMonitor() {
        val monitor = interruptionMonitor
        interruptionMonitor = null
        runCatching { monitor?.close() }
    }

    private fun reacquireFocusIfRequired(): Boolean {
        if (!interruptionPolicy.focusReacquisitionRequired()) return true
        val monitor = interruptionMonitor ?: return false
        if (!monitor.reacquireFocus()) return false
        val machine = activeMachine ?: return false
        applyInterruptionDecision(
            interruptionPolicy.onSignal(
                RecordingInterruptionSignal.focusGained,
                machine.snapshot().state,
            ),
        )
        return activeMachine != null && !interruptionPolicy.focusReacquisitionRequired()
    }

    private fun RecordingCapturePipeline.captureBoundaryElapsedRealtimeMillis(): Long? =
        captureBoundaryElapsedRealtimeNanos()?.div(NANOS_PER_MILLISECOND)

    private fun hasRecordAudioPermission(): Boolean =
        checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    private fun createNotificationChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        val channel =
            NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                getString(R.string.recording_notification_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = getString(R.string.recording_notification_channel_description)
                setSound(null, null)
                enableVibration(false)
            }
        manager.createNotificationChannel(channel)
    }

    private fun refreshNotification() {
        val sessionId = activeSessionId ?: return
        val snapshot = activeMachine?.snapshot() ?: return
        getSystemService(NotificationManager::class.java).notify(
            NOTIFICATION_ID,
            buildNotification(sessionId, snapshot),
        )
    }

    private fun buildNotification(
        sessionId: String,
        snapshot: NativeRecordingSnapshot,
    ): Notification {
        val openApp =
            PendingIntent.getActivity(
                this,
                0,
                Intent(this, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse(RecordingActiveSessionRoute.uri(sessionId))
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        val builder =
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(getString(R.string.recording_notification_title))
            .setContentText(notificationText(snapshot))
            .setContentIntent(openApp)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
        when (snapshot.state) {
            NativeRecordingState.recording -> {
                builder.addAction(
                    android.R.drawable.ic_media_pause,
                    getString(R.string.recording_notification_pause),
                    serviceAction(ACTION_PAUSE, sessionId, REQUEST_PAUSE),
                )
                builder.addAction(
                    android.R.drawable.ic_menu_add,
                    getString(R.string.recording_notification_bookmark),
                    serviceAction(ACTION_BOOKMARK, sessionId, REQUEST_BOOKMARK),
                )
            }
            NativeRecordingState.pausedByUser,
            NativeRecordingState.pausedByInterruption,
            -> {
                if (
                    RecordingInterruptionNotificationPolicy.showResumeAction(
                        snapshot.state,
                        interruptionPolicy.confirmationRequired(),
                    )
                ) {
                    builder.addAction(
                        android.R.drawable.ic_media_play,
                        getString(R.string.recording_notification_resume),
                        serviceAction(ACTION_RESUME, sessionId, REQUEST_RESUME),
                    )
                }
                builder.addAction(
                    android.R.drawable.ic_menu_add,
                    getString(R.string.recording_notification_bookmark),
                    serviceAction(ACTION_BOOKMARK, sessionId, REQUEST_BOOKMARK),
                )
            }
            else -> Unit
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder.build()
    }

    private fun notificationText(snapshot: NativeRecordingSnapshot): String {
        val stateLabel =
            when (snapshot.state) {
                NativeRecordingState.preparing -> getString(R.string.recording_notification_preparing)
                NativeRecordingState.pausedByUser,
                NativeRecordingState.pausedByInterruption,
                ->
                    if (interruptionPolicy.confirmationRequired()) {
                        getString(R.string.recording_notification_confirmation_required)
                    } else {
                        getString(R.string.recording_notification_paused)
                    }
                else -> getString(R.string.recording_notification_active)
            }
        val visibleState =
            if (storageWarningActive) {
                getString(R.string.recording_notification_low_storage, stateLabel)
            } else {
                stateLabel
            }
        return getString(
            R.string.recording_notification_progress,
            visibleState,
            RecordingNotificationFormatter.duration(snapshot.elapsedMilliseconds),
            RecordingNotificationFormatter.bytes(snapshot.bytesWritten),
        )
    }

    private fun serviceAction(
        action: String,
        sessionId: String,
        requestCode: Int,
    ): PendingIntent =
        PendingIntent.getService(
            this,
            requestCode,
            Intent(this, RecordingForegroundService::class.java)
                .setAction(action)
                .setData(Uri.parse(RecordingNotificationActionIdentity.uri(action, sessionId)))
                .putExtra(EXTRA_SESSION_ID, sessionId),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    companion object {
        private const val ACTION_START = "com.loquiris.recording.START"
        private const val ACTION_CONTINUE = "com.loquiris.recording.CONTINUE"
        private const val ACTION_PAUSE = "com.loquiris.recording.PAUSE"
        private const val ACTION_RESUME = "com.loquiris.recording.RESUME"
        private const val ACTION_STOP = "com.loquiris.recording.STOP"
        private const val ACTION_CONFIRM_RESUME = "com.loquiris.recording.CONFIRM_RESUME"
        private const val ACTION_BOOKMARK = "com.loquiris.recording.BOOKMARK"
        private const val EXTRA_SESSION_ID = "sessionId"
        private const val EXTRA_COMMAND_ID = "commandId"
        private const val NOTIFICATION_CHANNEL_ID = "loquiris_recording"
        private const val NOTIFICATION_ID = 2104
        private const val REQUEST_PAUSE = 2105
        private const val REQUEST_RESUME = 2106
        private const val REQUEST_BOOKMARK = 2107
        private const val PROGRESS_INTERVAL_MILLIS = 1_000L
        private const val NANOS_PER_MILLISECOND = 1_000_000L

        fun start(
            context: Context,
            sessionId: String,
            commandId: String = UUID.randomUUID().toString(),
            availableBytes: (Context) -> Long? = AndroidRecordingStorageSpace::availableBytes,
        ): RecordingForegroundServiceStartResult {
            if (sessionId.isBlank()) {
                return RecordingForegroundServiceStartResult.Failed("recording_session_invalid")
            }
            val notificationPermissionRequired = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
            val decision =
                RecordingServiceStartPolicy.evaluate(
                    hasRecordAudioPermission =
                        context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                            PackageManager.PERMISSION_GRANTED,
                    notificationPermissionRequired = notificationPermissionRequired,
                    hasNotificationPermission =
                        !notificationPermissionRequired ||
                            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                            PackageManager.PERMISSION_GRANTED,
                )
            if (decision is RecordingServiceStartDecision.Denied) {
                return RecordingForegroundServiceStartResult.Failed(decision.code)
            }
            val storageDecision = RecordingStoragePolicy.preflight(availableBytes(context))
            if (storageDecision is RecordingStoragePreflightDecision.Denied) {
                return RecordingForegroundServiceStartResult.Failed(
                    code = storageDecision.code,
                    availableBytes = storageDecision.availableBytes,
                    requiredBytes = storageDecision.requiredBytes,
                )
            }

            return try {
                context.startForegroundService(
                    Intent(context, RecordingForegroundService::class.java)
                        .setAction(ACTION_START)
                        .putExtra(EXTRA_SESSION_ID, sessionId)
                        .putExtra(EXTRA_COMMAND_ID, commandId),
                )
                RecordingForegroundServiceStartResult.RequestAccepted(
                    notificationVisibilityReduced =
                        (decision as RecordingServiceStartDecision.Allowed).notificationVisibilityReduced,
                )
            } catch (_: RuntimeException) {
                RecordingForegroundServiceStartResult.Failed("recording_service_start_failed")
            }
        }

        fun continueRecovered(
            context: Context,
            sessionId: String,
            commandId: String = UUID.randomUUID().toString(),
            availableBytes: (Context) -> Long? = AndroidRecordingStorageSpace::availableBytes,
        ): RecordingForegroundServiceStartResult =
            requestStart(context, sessionId, commandId, ACTION_CONTINUE, availableBytes)

        private fun requestStart(
            context: Context,
            sessionId: String,
            commandId: String,
            action: String,
            availableBytes: (Context) -> Long?,
        ): RecordingForegroundServiceStartResult {
            if (sessionId.isBlank()) {
                return RecordingForegroundServiceStartResult.Failed("recording_session_invalid")
            }
            val notificationPermissionRequired = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
            val decision =
                RecordingServiceStartPolicy.evaluate(
                    hasRecordAudioPermission =
                        context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                            PackageManager.PERMISSION_GRANTED,
                    notificationPermissionRequired = notificationPermissionRequired,
                    hasNotificationPermission =
                        !notificationPermissionRequired ||
                            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                            PackageManager.PERMISSION_GRANTED,
                )
            if (decision is RecordingServiceStartDecision.Denied) {
                return RecordingForegroundServiceStartResult.Failed(decision.code)
            }
            val storageDecision = RecordingStoragePolicy.preflight(availableBytes(context))
            if (storageDecision is RecordingStoragePreflightDecision.Denied) {
                return RecordingForegroundServiceStartResult.Failed(
                    code = storageDecision.code,
                    availableBytes = storageDecision.availableBytes,
                    requiredBytes = storageDecision.requiredBytes,
                )
            }
            return try {
                context.startForegroundService(
                    Intent(context, RecordingForegroundService::class.java)
                        .setAction(action)
                        .putExtra(EXTRA_SESSION_ID, sessionId)
                        .putExtra(EXTRA_COMMAND_ID, commandId),
                )
                RecordingForegroundServiceStartResult.RequestAccepted(
                    notificationVisibilityReduced =
                        (decision as RecordingServiceStartDecision.Allowed).notificationVisibilityReduced,
                )
            } catch (_: RuntimeException) {
                RecordingForegroundServiceStartResult.Failed("recording_service_start_failed")
            }
        }

        fun confirmResume(
            context: Context,
            sessionId: String,
        ): Boolean {
            if (sessionId.isBlank()) return false
            return try {
                context.startService(
                    Intent(context, RecordingForegroundService::class.java)
                        .setAction(ACTION_CONFIRM_RESUME)
                        .putExtra(EXTRA_SESSION_ID, sessionId),
                )
                true
            } catch (_: RuntimeException) {
                false
            }
        }

        fun pause(
            context: Context,
            sessionId: String,
            commandId: String = UUID.randomUUID().toString(),
        ): Boolean = sendOwnedCommand(context, ACTION_PAUSE, sessionId, commandId)

        fun resume(
            context: Context,
            sessionId: String,
            commandId: String = UUID.randomUUID().toString(),
        ): Boolean = sendOwnedCommand(context, ACTION_RESUME, sessionId, commandId)

        fun stop(
            context: Context,
            sessionId: String,
            commandId: String = UUID.randomUUID().toString(),
        ): Boolean = sendOwnedCommand(context, ACTION_STOP, sessionId, commandId)

        private fun sendOwnedCommand(
            context: Context,
            action: String,
            sessionId: String,
            commandId: String,
        ): Boolean {
            if (sessionId.isBlank()) return false
            return try {
                context.startService(
                    Intent(context, RecordingForegroundService::class.java)
                        .setAction(action)
                        .putExtra(EXTRA_SESSION_ID, sessionId)
                        .putExtra(EXTRA_COMMAND_ID, commandId),
                )
                true
            } catch (_: RuntimeException) {
                false
            }
        }
    }
}

private class AndroidWakeLockController(
    context: Context,
) : WakeLockController {
    private val wakeLock =
        context
            .getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Loquiris:Recording")
            .apply { setReferenceCounted(false) }

    override val isHeld: Boolean
        get() = wakeLock.isHeld

    override fun acquire(): Boolean =
        try {
            wakeLock.acquire(WAKE_LOCK_TIMEOUT_MILLIS)
            wakeLock.isHeld
        } catch (_: RuntimeException) {
            false
        }

    override fun release() {
        try {
            wakeLock.release()
        } catch (_: RuntimeException) {
            // The lease checks isHeld first; a concurrent platform release is harmless.
        }
    }

    private companion object {
        const val WAKE_LOCK_TIMEOUT_MILLIS = 5L * 60L * 60L * 1_000L
    }
}
