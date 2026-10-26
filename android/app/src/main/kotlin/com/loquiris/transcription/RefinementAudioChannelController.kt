package com.loquiris.transcription

import java.util.concurrent.Executor
import java.util.concurrent.RejectedExecutionException

/** All validation and disk work is plain-testable and separate from Activity lifecycle. */
class RefinementAudioChannelController(
    private val executor: Executor,
    private val replyExecutor: Executor,
    private val inspect: (String, String?) -> RefinementAudioInventoryResult,
) {
    fun handle(method: String, arguments: Any?, reply: (Any?) -> Unit) {
        val request = RefinementAudioChannelContract.parse(arguments)
        if (method != "inspect" || request == null) {
            reply(RefinementAudioChannelContract.failure(request?.meetingId, "refinement_audio_request_invalid"))
            return
        }
        try {
            executor.execute {
                val response = try {
                    RefinementAudioChannelContract.response(request.meetingId, inspect(request.meetingId, request.expectedSha256))
                } catch (_: RuntimeException) {
                    RefinementAudioChannelContract.failure(request.meetingId, "refinement_audio_unavailable")
                }
                replyExecutor.execute { reply(response) }
            }
        } catch (_: RejectedExecutionException) {
            reply(RefinementAudioChannelContract.failure(request.meetingId, "refinement_audio_unavailable"))
        }
    }
}
