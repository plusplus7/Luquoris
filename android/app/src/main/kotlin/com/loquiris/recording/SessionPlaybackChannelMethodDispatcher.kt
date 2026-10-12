package com.loquiris.recording

import java.util.concurrent.Executor

class SessionPlaybackChannelMethodDispatcher(
    private val handle: (String, Any?, (Map<String, Any?>) -> Unit) -> Unit,
    private val playbackExecutor: Executor,
    private val replyExecutor: Executor,
) {
    fun dispatch(
        method: String,
        arguments: Any?,
        reply: (Map<String, Any?>) -> Unit,
    ) {
        playbackExecutor.execute {
            handle(method, arguments) { response ->
                replyExecutor.execute { reply(response) }
            }
        }
    }
}
