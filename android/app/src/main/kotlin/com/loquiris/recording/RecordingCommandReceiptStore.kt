package com.loquiris.recording

import android.content.Context

enum class NativeRecordingCommandReceiptState { pending, succeeded, failed }

data class NativeRecordingCommandReceipt(
    val commandId: String,
    val state: NativeRecordingCommandReceiptState,
    val command: String? = null,
    val sessionId: String? = null,
    val createdAtEpochMilliseconds: Long = 0,
    val processId: String? = null,
    val snapshot: NativeRecordingSnapshot? = null,
    val failureCode: String? = null,
    val availableBytes: Long? = null,
    val requiredBytes: Long? = null,
)

class RecordingCommandReceiptStore(context: Context) {
    private val preferences =
        context.applicationContext.getSharedPreferences("recording-command-receipts-v1", Context.MODE_PRIVATE)

    fun pending(commandId: String, command: String, sessionId: String): Boolean =
        save(
            NativeRecordingCommandReceipt(
                commandId,
                NativeRecordingCommandReceiptState.pending,
                command = command,
                sessionId = sessionId,
                createdAtEpochMilliseconds = System.currentTimeMillis().coerceAtLeast(0),
                processId = RecordingProcessLiveness.processId,
            ),
        )

    fun succeeded(commandId: String, snapshot: NativeRecordingSnapshot): Boolean =
        save(NativeRecordingCommandReceipt(commandId, NativeRecordingCommandReceiptState.succeeded, snapshot = snapshot))

    fun failed(commandId: String, code: String, availableBytes: Long? = null, requiredBytes: Long? = null): Boolean =
        save(
            NativeRecordingCommandReceipt(
                commandId,
                NativeRecordingCommandReceiptState.failed,
                failureCode = code,
                availableBytes = availableBytes,
                requiredBytes = requiredBytes,
            ),
        )

    fun load(commandId: String): NativeRecordingCommandReceipt? {
        val prefix = "$commandId."
        val state = preferences.getString(prefix + "state", null)?.let {
            runCatching { NativeRecordingCommandReceiptState.valueOf(it) }.getOrNull()
        } ?: return null
        val snapshot =
            if (state == NativeRecordingCommandReceiptState.succeeded) {
                val stateName = preferences.getString(prefix + "snapshotState", null) ?: return null
                NativeRecordingSnapshot(
                    sessionId = preferences.getString(prefix + "sessionId", null),
                    state = runCatching { NativeRecordingState.valueOf(stateName) }.getOrNull() ?: return null,
                    elapsedMilliseconds = preferences.getLong(prefix + "elapsed", -1),
                    bytesWritten = preferences.getLong(prefix + "bytes", -1),
                    revision = preferences.getLong(prefix + "revision", -1),
                )
            } else null
        return NativeRecordingCommandReceipt(
            commandId = commandId,
            state = state,
            command = preferences.getString(prefix + "command", null),
            sessionId = preferences.getString(prefix + "commandSessionId", null),
            createdAtEpochMilliseconds = preferences.getLong(prefix + "createdAt", 0),
            processId = preferences.getString(prefix + "processId", null),
            snapshot = snapshot,
            failureCode = preferences.getString(prefix + "failureCode", null),
            availableBytes = preferences.takeIf { it.contains(prefix + "available") }?.getLong(prefix + "available", 0),
            requiredBytes = preferences.takeIf { it.contains(prefix + "required") }?.getLong(prefix + "required", 0),
        )
    }

    private fun save(receipt: NativeRecordingCommandReceipt): Boolean {
        val prefix = "${receipt.commandId}."
        val editor = preferences.edit().putString(prefix + "state", receipt.state.name)
        receipt.command?.let { editor.putString(prefix + "command", it) }
        receipt.sessionId?.let { editor.putString(prefix + "commandSessionId", it) }
        if (receipt.createdAtEpochMilliseconds > 0) {
            editor.putLong(prefix + "createdAt", receipt.createdAtEpochMilliseconds)
        }
        receipt.processId?.let { editor.putString(prefix + "processId", it) }
        receipt.snapshot?.let {
            editor
                .putString(prefix + "sessionId", it.sessionId)
                .putString(prefix + "snapshotState", it.state.name)
                .putLong(prefix + "elapsed", it.elapsedMilliseconds)
                .putLong(prefix + "bytes", it.bytesWritten)
                .putLong(prefix + "revision", it.revision)
        }
        receipt.failureCode?.let { editor.putString(prefix + "failureCode", it) }
        receipt.availableBytes?.let { editor.putLong(prefix + "available", it) }
        receipt.requiredBytes?.let { editor.putLong(prefix + "required", it) }
        return editor.commit()
    }
}
