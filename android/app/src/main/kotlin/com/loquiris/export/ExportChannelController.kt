package com.loquiris.export

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import java.io.OutputStream
import java.util.concurrent.Executor

internal fun interface ExportDestinationLauncher {
    fun launch(
        mimeType: String,
        suggestedFileName: String,
    )
}

internal interface ExportDestinations {
    fun open(destinationId: String): OutputStream?

    fun delete(destinationId: String): Boolean

    fun displayName(destinationId: String): String?
}

private class AndroidExportDestinations(
    private val activity: Activity,
) : ExportDestinations {
    override fun open(destinationId: String): OutputStream? =
        activity.contentResolver.openOutputStream(Uri.parse(destinationId), "w")

    override fun delete(destinationId: String): Boolean =
        activity.contentResolver.delete(Uri.parse(destinationId), null, null) > 0

    override fun displayName(destinationId: String): String? =
        activity.contentResolver
            .query(Uri.parse(destinationId), arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor -> cursor.firstDisplayName() }

    private fun Cursor.firstDisplayName(): String? {
        if (!moveToFirst()) return null
        val index = getColumnIndex(OpenableColumns.DISPLAY_NAME)
        return if (index >= 0) getString(index)?.takeIf(String::isNotBlank) else null
    }
}

class ExportChannelController internal constructor(
    private val exportExecutor: Executor,
    private val replyExecutor: Executor,
    private val writer: ExportPackageWriter,
    private val destinations: ExportDestinations,
    private val destinationLauncher: ExportDestinationLauncher,
) {
    constructor(
        activity: Activity,
        exportExecutor: Executor,
        replyExecutor: Executor,
    ) : this(
        exportExecutor = exportExecutor,
        replyExecutor = replyExecutor,
        writer = ExportPackageWriter(RecordingExportAudioSource(activity.applicationContext)),
        destinations = AndroidExportDestinations(activity),
        destinationLauncher =
            ExportDestinationLauncher { mimeType, suggestedFileName ->
                val intent =
                    Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = mimeType
                        putExtra(Intent.EXTRA_TITLE, suggestedFileName)
                    }
                activity.startActivityForResult(intent, ExportChannelContract.requestCode)
            },
    )

    @Volatile
    private var active: ActiveExport? = null

    fun handle(
        method: String,
        arguments: Any?,
        reply: (Any?) -> Unit,
    ) {
        when (method) {
            "save" -> handleSave(arguments, reply)
            "status" -> handleStatus(arguments, reply)
            "cancel" -> handleCancel(arguments, reply)
            else -> reply(ExportChannelContract.failure("export_method_unsupported"))
        }
    }

    private fun handleSave(
        arguments: Any?,
        reply: (Any?) -> Unit,
    ) {
        val request =
            when (val decoded = ExportChannelContract.decodeRequest(arguments)) {
                is ExportRequestDecodeResult.Success -> decoded.request
                is ExportRequestDecodeResult.Failure -> {
                    reply(ExportChannelContract.failure(decoded.code))
                    return
                }
            }
        val operation = ActiveExport(request, reply)
        synchronized(this) {
            if (active != null) {
                reply(ExportChannelContract.failure("export_busy"))
                return
            }
            active = operation
        }
        try {
            destinationLauncher.launch(request.mimeType, request.suggestedFileName)
        } catch (_: RuntimeException) {
            clear(operation)
            reply(ExportChannelContract.failure("export_destination_unavailable"))
        }
    }

    private fun handleStatus(
        arguments: Any?,
        reply: (Any?) -> Unit,
    ) {
        val operationId =
            when (val decoded = ExportChannelContract.decodeOperation(arguments)) {
                is ExportOperationDecodeResult.Success -> decoded.operationId
                is ExportOperationDecodeResult.Failure -> {
                    reply(ExportChannelContract.failure(decoded.code))
                    return
                }
            }
        val operation = active
        if (operation == null || operation.request.operationId != operationId) {
            reply(ExportChannelContract.failure("export_operation_not_found"))
            return
        }
        reply(
            ExportChannelContract.progress(
                operationId = operationId,
                phase = operation.phase,
                bytesProcessed = operation.bytesProcessed,
                totalBytes = operation.totalBytes,
                cancellable = operation.phase == ExportProgressPhase.writing,
            ),
        )
    }

    private fun handleCancel(
        arguments: Any?,
        reply: (Any?) -> Unit,
    ) {
        val operationId =
            when (val decoded = ExportChannelContract.decodeOperation(arguments)) {
                is ExportOperationDecodeResult.Success -> decoded.operationId
                is ExportOperationDecodeResult.Failure -> {
                    reply(ExportChannelContract.failure(decoded.code))
                    return
                }
            }
        val operation = active
        if (operation == null || operation.request.operationId != operationId) {
            reply(ExportChannelContract.failure("export_operation_not_found"))
            return
        }
        if (operation.phase != ExportProgressPhase.writing) {
            reply(ExportChannelContract.failure("export_cancellation_not_safe"))
            return
        }
        operation.cancellationRequested = true
        reply(ExportChannelContract.acknowledged())
    }

    fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ): Boolean {
        if (requestCode != ExportChannelContract.requestCode) return false
        val uri = data?.data
        onDestinationResult(
            uri?.toString()?.takeIf { resultCode == Activity.RESULT_OK },
        )
        return true
    }

    internal fun onDestinationResult(destinationId: String?) {
        val operation = active ?: return
        if (destinationId == null) {
            clear(operation)
            operation.reply(ExportChannelContract.failure("export_cancelled"))
            return
        }
        operation.phase = ExportProgressPhase.preparing
        exportExecutor.execute {
            val response = write(operation, destinationId)
            clear(operation)
            replyExecutor.execute { operation.reply(response) }
        }
    }

    fun close() {
        val operation = active ?: return
        if (operation.phase == ExportProgressPhase.selectingDestination) {
            clear(operation)
            operation.reply(ExportChannelContract.failure("export_activity_closed"))
        } else {
            operation.cancellationRequested = true
        }
    }

    private fun write(
        operation: ActiveExport,
        destinationId: String,
    ): Map<String, Any> {
        val request = operation.request
        val result =
            try {
                val output = destinations.open(destinationId)
                    ?: return failedDestination(destinationId, "export_destination_unavailable")
                output.use {
                    operation.phase = ExportProgressPhase.writing
                    val written = writer.write(request, it, operation)
                    operation.phase = ExportProgressPhase.finalizing
                    written
                }
            } catch (_: Exception) {
                ExportWriteResult.Failure("export_destination_write_failed")
            }
        return when (result) {
            is ExportWriteResult.Success ->
                ExportChannelContract.success(
                    fileName = displayName(destinationId) ?: request.suggestedFileName,
                    result = result,
                )
            is ExportWriteResult.Failure -> failedDestination(destinationId, result.code)
        }
    }

    private fun failedDestination(
        destinationId: String,
        originalCode: String,
    ): Map<String, Any> {
        val deleted =
            try {
                destinations.delete(destinationId)
            } catch (_: Exception) {
                false
            }
        return ExportChannelContract.failure(
            ExportCleanupPolicy.failureCode(originalCode, deleted),
        )
    }

    @Synchronized
    private fun clear(operation: ActiveExport) {
        if (active === operation) active = null
    }

    private fun displayName(destinationId: String): String? =
        try {
            destinations.displayName(destinationId)
        } catch (_: Exception) {
            null
        }

    private class ActiveExport(
        val request: LocalExportRequest,
        val reply: (Any?) -> Unit,
    ) : ExportWriteControl {
        @Volatile
        var phase = ExportProgressPhase.selectingDestination

        @Volatile
        var bytesProcessed = 0L

        @Volatile
        var totalBytes: Long? = null

        @Volatile
        var cancellationRequested = false

        override fun isCancellationRequested(): Boolean = cancellationRequested

        override fun onProgress(
            bytesProcessed: Long,
            totalBytes: Long?,
        ) {
            this.bytesProcessed = bytesProcessed
            this.totalBytes = totalBytes
        }
    }
}

internal object ExportCleanupPolicy {
    fun failureCode(
        originalCode: String,
        destinationDeleted: Boolean,
    ): String =
        if (destinationDeleted) {
            originalCode
        } else {
            "export_incomplete_output_cleanup_failed"
        }
}
