package com.loquiris.transcription

import android.content.Context
import java.util.concurrent.Executor
import java.util.concurrent.atomic.AtomicBoolean

fun interface TranscriptionChannelWorker {
    fun transcribe(
        request: TranscriptionChannelRequest,
        cancellation: TranscriptionCancellation,
        onProgress: (Double) -> Unit,
    ): PostSessionTranscriptionResult
}

class TranscriptionChannelController(
    private val worker: TranscriptionChannelWorker,
    private val inferenceExecutor: Executor,
    private val replyExecutor: Executor,
    private val eventEmitter: (Map<String, Any?>) -> Unit,
    private val registry: TranscriptionRunRegistry = TranscriptionRunRegistry(),
) : AutoCloseable {
    constructor(
        context: Context,
        inferenceExecutor: Executor,
        replyExecutor: Executor,
        eventEmitter: (Map<String, Any?>) -> Unit,
    ) : this(
        worker = productionWorker(context.applicationContext),
        inferenceExecutor = inferenceExecutor,
        replyExecutor = replyExecutor,
        eventEmitter = eventEmitter,
    )

    val activeRunCount: Int
        get() = registry.activeCount

    fun handle(
        method: String,
        arguments: Any?,
        reply: (Map<String, Any?>) -> Unit,
    ) {
        when (method) {
            "transcribe" -> transcribe(arguments, reply)
            "cancel" -> cancel(arguments, reply)
            else -> postReply(reply, TranscriptionChannelContract.failure("transcription_channel_method_unknown"))
        }
    }

    private fun transcribe(
        arguments: Any?,
        reply: (Map<String, Any?>) -> Unit,
    ) {
        val request =
            when (val parsed = TranscriptionChannelContract.parseTranscribe(arguments)) {
                is TranscriptionChannelParseResult.Ready -> parsed.request
                is TranscriptionChannelParseResult.Failure -> {
                    postReply(reply, TranscriptionChannelContract.failure(parsed.code))
                    return
                }
            }
        if (request.modelId != TranscriptionChannelContract.supportedModelId ||
            request.parameterVersion != TranscriptionChannelContract.supportedParameterVersion
        ) {
            postReply(
                reply,
                TranscriptionChannelContract.failure("transcription_request_invalid", request.runId),
            )
            return
        }
        val cancellation = TranscriptionCancellation()
        when (registry.register(request.runId, cancellation)) {
            TranscriptionRunRegistration.closed -> {
                postReply(
                    reply,
                    TranscriptionChannelContract.failure("transcription_channel_closed", request.runId),
                )
                return
            }
            TranscriptionRunRegistration.duplicate -> {
                postReply(
                    reply,
                    TranscriptionChannelContract.failure("transcription_request_invalid", request.runId),
                )
                return
            }
            TranscriptionRunRegistration.registered -> Unit
        }
        val terminalSent = AtomicBoolean(false)
        val terminalReply: (Map<String, Any?>) -> Unit = { response ->
            if (terminalSent.compareAndSet(false, true)) postReply(reply, response)
        }
        try {
            inferenceExecutor.execute {
                var lastProgress = 0.0
                val result =
                    try {
                        worker.transcribe(request, cancellation) { rawProgress ->
                            if (!rawProgress.isFinite()) return@transcribe
                            val progress = rawProgress.coerceIn(0.0, 1.0)
                            if (progress < lastProgress) return@transcribe
                            lastProgress = progress
                            postEvent(TranscriptionChannelContract.progress(request.runId, progress))
                        }
                    } catch (_: Exception) {
                        PostSessionTranscriptionResult.Failure("transcription_native_failed")
                    }
                registry.finish(request.runId)
                terminalReply(terminalResponse(request.runId, result))
            }
        } catch (_: RuntimeException) {
            registry.finish(request.runId)
            terminalReply(
                TranscriptionChannelContract.failure(
                    "transcription_channel_unavailable",
                    request.runId,
                ),
            )
        }
    }

    private fun cancel(
        arguments: Any?,
        reply: (Map<String, Any?>) -> Unit,
    ) {
        when (val parsed = TranscriptionChannelContract.parseCancel(arguments)) {
            is TranscriptionRunIdParseResult.Failure ->
                postReply(reply, TranscriptionChannelContract.failure(parsed.code))
            is TranscriptionRunIdParseResult.Ready -> {
                registry.cancel(parsed.runId)
                postReply(reply, TranscriptionChannelContract.cancelled(parsed.runId))
            }
        }
    }

    private fun terminalResponse(
        runId: String,
        result: PostSessionTranscriptionResult,
    ): Map<String, Any?> =
        when (result) {
            is PostSessionTranscriptionResult.Completed ->
                TranscriptionChannelContract.completed(runId, result)
            PostSessionTranscriptionResult.Cancelled ->
                TranscriptionChannelContract.failure("transcription_cancelled", runId)
            is PostSessionTranscriptionResult.Failure ->
                TranscriptionChannelContract.failure(
                    TranscriptionChannelContract.safeWorkerFailureCode(result.code),
                    runId,
                )
        }

    private fun postEvent(event: Map<String, Any?>) {
        replyExecutor.execute { eventEmitter(event) }
    }

    private fun postReply(
        reply: (Map<String, Any?>) -> Unit,
        response: Map<String, Any?>,
    ) {
        replyExecutor.execute { reply(response) }
    }

    override fun close() {
        registry.close()
    }
}

private fun productionWorker(context: Context): TranscriptionChannelWorker {
    val engine =
        WhisperPostSessionEngine(
            audioProvider = AuthoritativeAudioResolver(context),
            modelProvider = WhisperModelStore(context),
            decoder = AndroidAacPcmDecoder(),
            native = JniWhisperNativeApi,
        )
    return TranscriptionChannelWorker { request, cancellation, onProgress ->
        engine.transcribe(
            meetingId = request.meetingId,
            cancellation = cancellation,
            onProgress = onProgress,
        )
    }
}
