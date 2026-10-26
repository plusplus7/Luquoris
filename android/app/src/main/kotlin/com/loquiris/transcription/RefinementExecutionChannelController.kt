package com.loquiris.transcription

import java.util.concurrent.Executor
import java.util.concurrent.RejectedExecutionException

/** One owner remains reserved through worker cleanup; cancellation never queues behind inference. */
class RefinementExecutionChannelController(
    private val contract: RefinementExecutionChannelContract,
    private val executor: Executor,
    private val replyExecutor: Executor,
    private val worker: (RefinementExecutionRequest, TranscriptionCancellation) -> RefinementExecutionResult,
) : AutoCloseable {
    private class Active(val request: RefinementChannelExecution, val cancellation: TranscriptionCancellation)
    private val lock = Any()
    private var active: Active? = null
    private var closed = false

    fun handle(method: String, arguments: Any?, reply: (Map<String, Any?>) -> Unit) {
        if (method == "cancel") {
            val owner = contract.owner(arguments)
            val token = synchronized(lock) { active?.takeIf { it.request.owner == owner }?.cancellation }
            if (owner == null || token == null) {
                reply(contract.failure(owner, "refinement_execution_owner_missing"))
            } else {
                cancel(token)
                reply(contract.success(owner))
            }
            return
        }
        val request = if (method == "transcribe") contract.parse(arguments) else null
        if (request == null) {
            reply(contract.failure(contract.owner(arguments, false), "refinement_execution_request_invalid"))
            return
        }
        val ticket = Active(request, TranscriptionCancellation())
        val rejection = synchronized(lock) {
            when {
                closed -> contract.failure(request.owner, "refinement_execution_closed")
                active != null -> contract.failure(request.owner, "refinement_worker_busy", "deferred")
                else -> { active = ticket; null }
            }
        }
        if (rejection != null) { reply(rejection); return }
        try {
            executor.execute {
                val result = try {
                    worker(request.execution, ticket.cancellation)
                } catch (_: OutOfMemoryError) {
                    RefinementExecutionResult.Failure("transcription_native_out_of_memory")
                } catch (_: LinkageError) {
                    RefinementExecutionResult.Failure("transcription_native_unavailable")
                } catch (_: Exception) {
                    RefinementExecutionResult.Failure("refinement_execution_failed")
                } finally {
                    synchronized(lock) { if (active === ticket) active = null }
                }
                val outcome = if (ticket.cancellation.isCancelled()) RefinementExecutionResult.Cancelled else result
                replyExecutor.execute { reply(contract.response(request.owner, outcome)) }
            }
        } catch (_: RejectedExecutionException) {
            synchronized(lock) { if (active === ticket) active = null }
            reply(contract.failure(request.owner, "refinement_execution_unavailable"))
        }
    }

    override fun close() {
        val token = synchronized(lock) { closed = true; active?.cancellation }
        token?.let(::cancel)
    }

    private fun cancel(token: TranscriptionCancellation) {
        try { token.cancel() } catch (_: Exception) { /* Already latched; no native details escape. */ }
        catch (_: LinkageError) { /* Capture and lifecycle teardown must remain independent. */ }
        catch (_: OutOfMemoryError) { /* Cancellation is latched even under resource pressure. */ }
    }
}
