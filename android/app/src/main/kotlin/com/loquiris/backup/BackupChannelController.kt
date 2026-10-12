package com.loquiris.backup

import android.content.Context
import java.util.concurrent.Executor

class BackupChannelController internal constructor(
    private val executor: Executor,
    private val replyExecutor: Executor,
    private val publisher: BackupArchivePublisher,
    private val reader: BackupPackageReader,
    private val recordingPublisher: RestoreRecordingPublisher,
) {
    constructor(
        context: Context,
        executor: Executor,
        replyExecutor: Executor,
    ) : this(
        executor = executor,
        replyExecutor = replyExecutor,
        publisher =
            BackupArchivePublisher(
                filesRoot = context.applicationContext.filesDir,
                appVersion = context.applicationVersion(),
            ),
        reader = BackupPackageReader(context.applicationContext.filesDir),
        recordingPublisher = RestoreRecordingPublisher(context.applicationContext.filesDir),
    )

    fun handle(
        method: String,
        arguments: Any?,
        reply: (Any?) -> Unit,
    ) {
        when (method) {
            "create" -> handleCreate(arguments, reply)
            "verifyAndStageRestore" -> handleVerification(arguments, reply)
            "publishRestoreRecording" -> handleRecordingPublish(arguments, reply)
            "fingerprintRestoreRecordings" -> handleRecordingFingerprints(arguments, reply)
            "rollbackRestoreRecordings" -> handleRecordingRollback(arguments, reply)
            "finalizeRestoreRecordings" -> handleRecordingFinalize(arguments, reply)
            "discardRestoreStaging" -> handleStagingDiscard(arguments, reply)
            else -> reply(BackupChannelContract.failure("backup_method_unsupported"))
        }
    }

    private fun handleRecordingPublish(
        arguments: Any?,
        reply: (Any?) -> Unit,
    ) {
        val request = BackupChannelContract.decodeRecordingTransfer(arguments)
        if (request == null) {
            reply(BackupChannelContract.failure("restore_recording_request_invalid"))
            return
        }
        execute(reply) {
            when (val result = recordingPublisher.publish(request)) {
                is RestoreRecordingPublishResult.Success -> BackupChannelContract.recordingPublishSuccess(result)
                is RestoreRecordingPublishResult.Failure -> BackupChannelContract.failure(result.code)
            }
        }
    }

    private fun handleRecordingFingerprints(
        arguments: Any?,
        reply: (Any?) -> Unit,
    ) {
        val meetingIds = BackupChannelContract.decodeMeetingIds(arguments)
        if (meetingIds == null) {
            reply(BackupChannelContract.failure("restore_recording_request_invalid"))
            return
        }
        execute(reply) {
            val fingerprints = recordingPublisher.fingerprints(meetingIds)
            if (fingerprints == null) {
                BackupChannelContract.failure("restore_recording_request_invalid")
            } else {
                BackupChannelContract.recordingFingerprintsSuccess(fingerprints)
            }
        }
    }

    private fun handleRecordingRollback(
        arguments: Any?,
        reply: (Any?) -> Unit,
    ) {
        val publication = BackupChannelContract.decodeRestorePublication(arguments)
        if (publication == null) {
            reply(BackupChannelContract.failure("restore_recording_request_invalid"))
            return
        }
        execute(reply) {
            if (recordingPublisher.rollback(publication.first, publication.second)) {
                BackupChannelContract.emptySuccess()
            } else {
                BackupChannelContract.failure("restore_recording_rollback_failed")
            }
        }
    }

    private fun handleRecordingFinalize(
        arguments: Any?,
        reply: (Any?) -> Unit,
    ) {
        val publication = BackupChannelContract.decodeRestorePublication(arguments)
        if (publication == null) {
            reply(BackupChannelContract.failure("restore_recording_request_invalid"))
            return
        }
        execute(reply) {
            if (recordingPublisher.finalize(publication.first, publication.second)) {
                BackupChannelContract.emptySuccess()
            } else {
                BackupChannelContract.failure("restore_recording_finalize_failed")
            }
        }
    }

    private fun handleStagingDiscard(
        arguments: Any?,
        reply: (Any?) -> Unit,
    ) {
        val operationId = BackupChannelContract.decodeOperationId(arguments)
        if (operationId == null) {
            reply(BackupChannelContract.failure("restore_request_invalid"))
            return
        }
        execute(reply) {
            if (recordingPublisher.discardStaging(operationId)) {
                BackupChannelContract.emptySuccess()
            } else {
                BackupChannelContract.failure("restore_staging_cleanup_failed")
            }
        }
    }

    private fun handleCreate(
        arguments: Any?,
        reply: (Any?) -> Unit,
    ) {
        val request =
            when (val decoded = BackupChannelContract.decodeRequest(arguments)) {
                is BackupRequestDecodeResult.Success -> decoded.request
                is BackupRequestDecodeResult.Failure -> {
                    reply(BackupChannelContract.failure(decoded.code))
                    return
                }
            }
        execute(reply) {
            when (val result = publisher.create(request)) {
                is BackupArchiveResult.Success -> BackupChannelContract.success(result)
                is BackupArchiveResult.Failure -> BackupChannelContract.failure(result.code)
            }
        }
    }

    private fun handleVerification(
        arguments: Any?,
        reply: (Any?) -> Unit,
    ) {
        val request =
            when (val decoded = BackupChannelContract.decodeVerificationRequest(arguments)) {
                is BackupVerificationDecodeResult.Success -> decoded.request
                is BackupVerificationDecodeResult.Failure -> {
                    reply(BackupChannelContract.failure(decoded.code))
                    return
                }
            }
        execute(reply) {
            when (val result = reader.verifyAndStage(request)) {
                is BackupVerificationResult.Success -> BackupChannelContract.verificationSuccess(result)
                is BackupVerificationResult.Failure -> BackupChannelContract.failure(result.code)
            }
        }
    }

    private fun execute(
        reply: (Any?) -> Unit,
        operation: () -> Map<String, Any>,
    ) {
        executor.execute {
            val response = operation()
            replyExecutor.execute { reply(response) }
        }
    }
}

private fun Context.applicationVersion(): String {
    val info = packageManager.getPackageInfo(packageName, 0)
    @Suppress("DEPRECATION")
    val versionCode = info.versionCode
    return "${info.versionName ?: "unknown"}+$versionCode"
}
