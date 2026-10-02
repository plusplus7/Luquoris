package com.loquiris.performance

import java.util.concurrent.Executor
import java.util.concurrent.atomic.AtomicBoolean

class PerformanceMetricsChannelController(
    private val reader: PerformanceMetricsReader,
    private val metricsExecutor: Executor,
    private val replyExecutor: Executor,
) {
    fun handle(
        method: String,
        arguments: Any?,
        reply: (Any?) -> Unit,
    ) {
        val replyScheduled = AtomicBoolean(false)
        val replyDelivered = AtomicBoolean(false)
        fun complete(response: Any?) {
            if (!replyScheduled.compareAndSet(false, true)) return
            replyExecutor.execute {
                if (replyDelivered.compareAndSet(false, true)) reply(response)
            }
        }

        when (val request = PerformanceMetricsChannelContract.decode(method, arguments)) {
            is PerformanceMetricsRequest.Rejected ->
                complete(PerformanceMetricsChannelContract.failure(request.code))
            PerformanceMetricsRequest.ReadSnapshot -> {
                val readStarted = AtomicBoolean(false)
                try {
                    metricsExecutor.execute {
                        if (!readStarted.compareAndSet(false, true)) return@execute
                        val response =
                            try {
                                PerformanceMetricsChannelContract.success(
                                    reader.readSnapshot(),
                                )
                            } catch (_: Throwable) {
                                PerformanceMetricsChannelContract.failure(
                                    "performance_metrics_read_failed",
                                )
                            }
                        complete(response)
                    }
                } catch (_: Throwable) {
                    complete(
                        PerformanceMetricsChannelContract.failure(
                            "performance_metrics_channel_invalid",
                        ),
                    )
                }
            }
        }
    }
}
