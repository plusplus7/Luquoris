package com.loquiris.recording

import java.util.concurrent.Executor

class RecordingChannelMethodDispatcher(
    private val handle: (String, Any?) -> Map<String, Any?>,
    private val recoveryExecutor: Executor,
    private val replyExecutor: Executor,
) {
    fun dispatch(
        method: String,
        arguments: Any?,
        reply: (Map<String, Any?>) -> Unit,
    ) {
        if (method !in BACKGROUND_METHODS) {
            reply(handle(method, arguments))
            return
        }
        recoveryExecutor.execute {
            val response = handle(method, arguments)
            replyExecutor.execute { reply(response) }
        }
    }

    private companion object {
        val BACKGROUND_METHODS = setOf("recoveryInventory", "saveRecovery")
    }
}
