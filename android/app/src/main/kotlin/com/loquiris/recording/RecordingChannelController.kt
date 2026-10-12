package com.loquiris.recording

import android.content.Context
import java.io.File
import java.util.UUID

class RecordingChannelController(
    context: Context,
) {
    private val applicationContext = context.applicationContext
    private val receipts = RecordingCommandReceiptStore(applicationContext)

    fun handle(
        method: String,
        arguments: Any?,
    ): Map<String, Any?> {
        val values = arguments as? Map<*, *> ?: return RecordingChannelContract.failure("recording_channel_invalid")
        if (values["v"] != RecordingChannelContract.version) {
            return RecordingChannelContract.failure("recording_channel_version_unsupported")
        }
        return try {
            when (method) {
                "snapshot" -> currentSnapshot()
                "recoveryInventory" -> recoveryInventory()
                "saveRecovery" -> saveRecovery(values["sessionId"] as? String)
                "continueRecovery" -> continueRecovery(values["sessionId"] as? String)
                "start" -> start(values["sessionId"] as? String)
                "pause" -> dispatchOwned("pause", RecordingForegroundService::pause)
                "resume" -> dispatchOwned("resume", RecordingForegroundService::resume)
                "stop" -> dispatchOwned("stop", RecordingForegroundService::stop)
                "commandStatus" -> commandStatus(values["commandId"] as? String)
                else -> RecordingChannelContract.failure("recording_channel_method_unknown")
            }
        } catch (_: RuntimeException) {
            RecordingChannelContract.failure("recording_channel_unavailable")
        }
    }

    private fun currentSnapshot(): Map<String, Any?> =
        when (
            val loaded =
                RecordingChannelSnapshotReader(
                    SharedPreferencesRecordingStateStore(applicationContext),
                ).read()
        ) {
            RecordingStateLoadResult.Absent -> RecordingChannelContract.snapshot(NativeRecordingSnapshot.Idle)
            is RecordingStateLoadResult.Loaded ->
                RecordingChannelContract.snapshot(
                    loaded.snapshot,
                    RecordingLiveInputHealthRegistry.read(loaded.snapshot.sessionId),
                )
            is RecordingStateLoadResult.Corrupt -> RecordingChannelContract.failure(loaded.code)
            is RecordingStateLoadResult.Unavailable -> RecordingChannelContract.failure(loaded.code)
        }

    private fun recoveryInventory(): Map<String, Any?> =
        try {
            RecordingChannelContract.recoveryInventory(
                RecordingStartupReconciler(
                    File(applicationContext.filesDir, "recordings"),
                ).scan(),
            )
        } catch (failure: RecordingRecoveryScanException) {
            RecordingChannelContract.failure(failure.code)
        }

    private fun start(sessionId: String?): Map<String, Any?> {
        if (sessionId.isNullOrBlank()) return RecordingChannelContract.failure("recording_session_invalid")
        val commandId = UUID.randomUUID().toString()
        if (!receipts.pending(commandId, "start", sessionId)) {
            return RecordingChannelContract.failure("recording_command_receipt_persist_failed")
        }
        return when (val result = RecordingForegroundService.start(applicationContext, sessionId, commandId)) {
            is RecordingForegroundServiceStartResult.RequestAccepted -> RecordingChannelContract.accepted(commandId)
            is RecordingForegroundServiceStartResult.Failed -> {
                receipts.failed(commandId, result.code, result.availableBytes, result.requiredBytes)
                RecordingChannelContract.failure(
                    code = result.code,
                    availableBytes = result.availableBytes,
                    requiredBytes = result.requiredBytes,
                )
            }
        }
    }

    private fun saveRecovery(sessionId: String?): Map<String, Any?> {
        if (sessionId.isNullOrBlank()) return RecordingChannelContract.failure("recording_session_invalid")
        val initialized =
            PersistedRecordingStateMachine.create(
                SharedPreferencesRecordingStateStore(applicationContext),
                isSessionLive = RecordingProcessLiveness::owns,
            )
        val machine =
            (initialized as? RecordingStateMachineInitialization.Success)?.machine
                ?: return RecordingChannelContract.failure("recording_state_initialization_failed")
        return when (val result = machine.finalizeRecovered(sessionId)) {
            is RecordingCommandResult.Success -> {
                val rebuilt =
                    RecordingM4aRebuilder().rebuild(
                        AppPrivateRecordingStorage.sessionDirectory(applicationContext, sessionId),
                    )
                RecordingChannelContract.snapshot(result.snapshot) +
                    mapOf(
                        "playback" to
                            when (rebuilt) {
                                is RecordingM4aRebuildResult.Success ->
                                    mapOf(
                                        "state" to "ready",
                                        "fileName" to rebuilt.fileName,
                                        "accessUnitCount" to rebuilt.accessUnitCount,
                                        "mediaSamples" to rebuilt.mediaSamples,
                                        "bytesWritten" to rebuilt.bytesWritten,
                                    )
                                is RecordingM4aRebuildResult.Failure ->
                                    mapOf(
                                        "state" to "failed",
                                        "code" to rebuilt.code,
                                    )
                            },
                    )
            }
            is RecordingCommandResult.Failure -> RecordingChannelContract.failure(result.code)
        }
    }

    private fun continueRecovery(sessionId: String?): Map<String, Any?> {
        if (sessionId.isNullOrBlank()) return RecordingChannelContract.failure("recording_session_invalid")
        val commandId = UUID.randomUUID().toString()
        if (!receipts.pending(commandId, "continueRecovery", sessionId)) {
            return RecordingChannelContract.failure("recording_command_receipt_persist_failed")
        }
        return when (
            val result = RecordingForegroundService.continueRecovered(applicationContext, sessionId, commandId)
        ) {
            is RecordingForegroundServiceStartResult.RequestAccepted -> RecordingChannelContract.accepted(commandId)
            is RecordingForegroundServiceStartResult.Failed -> {
                receipts.failed(commandId, result.code, result.availableBytes, result.requiredBytes)
                RecordingChannelContract.failure(result.code, result.availableBytes, result.requiredBytes)
            }
        }
    }

    private fun dispatchOwned(
        commandName: String,
        command: (Context, String, String) -> Boolean,
    ): Map<String, Any?> {
        val sessionId =
            when (val loaded = SharedPreferencesRecordingStateStore(applicationContext).load()) {
                is RecordingStateLoadResult.Loaded -> loaded.snapshot.sessionId
                RecordingStateLoadResult.Absent -> null
                is RecordingStateLoadResult.Corrupt -> return RecordingChannelContract.failure(loaded.code)
                is RecordingStateLoadResult.Unavailable -> return RecordingChannelContract.failure(loaded.code)
        }
        if (sessionId.isNullOrBlank()) return RecordingChannelContract.failure("recording_session_missing")
        val commandId = UUID.randomUUID().toString()
        if (!receipts.pending(commandId, commandName, sessionId)) {
            return RecordingChannelContract.failure("recording_command_receipt_persist_failed")
        }
        return if (command(applicationContext, sessionId, commandId)) {
            RecordingChannelContract.accepted(commandId)
        } else {
            receipts.failed(commandId, "recording_command_rejected")
            RecordingChannelContract.failure("recording_command_rejected")
        }
    }

    private fun commandStatus(commandId: String?): Map<String, Any?> {
        if (commandId.isNullOrBlank()) return RecordingChannelContract.failure("recording_command_id_invalid")
        var receipt = receipts.load(commandId) ?: return RecordingChannelContract.failure("recording_command_receipt_missing")
        val stalePending =
            receipt.state == NativeRecordingCommandReceiptState.pending &&
                !RecordingProcessLiveness.owns(receipt.sessionId) &&
                receipt.processId != RecordingProcessLiveness.processId
        if (stalePending) {
            receipts.failed(commandId, "recording_command_interrupted")
            receipt = receipts.load(commandId) ?: return RecordingChannelContract.failure("recording_command_receipt_missing")
        }
        return RecordingChannelContract.receipt(receipt)
    }

}
