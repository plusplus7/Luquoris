package com.loquiris.performance

import java.util.ArrayDeque
import java.util.concurrent.Executor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PerformanceMetricsChannelControllerTest {
    @Test
    fun `reader runs on worker and reply runs on reply executor`() {
        val worker = QueuedExecutor()
        val replies = QueuedExecutor()
        var reads = 0
        val responses = mutableListOf<Any?>()
        val controller =
            PerformanceMetricsChannelController(
                reader = reader { reads += 1 },
                metricsExecutor = worker,
                replyExecutor = replies,
            )

        controller.handle("readSnapshot", mapOf("v" to 1), responses::add)

        assertEquals(0, reads)
        assertTrue(responses.isEmpty())
        worker.runNext()
        assertEquals(1, reads)
        assertTrue(responses.isEmpty())
        assertEquals(1, replies.size)
        replies.runNext()
        assertEquals(1, responses.size)
        assertEquals(true, (responses.single() as Map<*, *>)["ok"])
    }

    @Test
    fun `reader failure returns structured privacy safe error`() {
        val worker = QueuedExecutor()
        val replies = QueuedExecutor()
        val responses = mutableListOf<Any?>()
        val controller =
            PerformanceMetricsChannelController(
                reader = reader { error("secret platform details") },
                metricsExecutor = worker,
                replyExecutor = replies,
            )

        controller.handle("readSnapshot", mapOf("v" to 1), responses::add)
        worker.runNext()
        replies.runNext()

        assertEquals("performance_metrics_read_failed", responses.single().failureCode())
        assertFalse(responses.single().toString().contains("secret"))
    }

    @Test
    fun `one request produces exactly one reply`() {
        val worker = QueuedExecutor()
        val replies = QueuedExecutor()
        val responses = mutableListOf<Any?>()
        var reads = 0
        val controller =
            PerformanceMetricsChannelController(
                reader = reader { reads += 1 },
                metricsExecutor = worker,
                replyExecutor = replies,
            )

        controller.handle("readSnapshot", mapOf("v" to 1), responses::add)
        val work = worker.removeNext()
        work.run()
        work.run()
        assertEquals(1, reads)
        assertEquals(1, replies.size)
        val reply = replies.removeNext()
        reply.run()
        reply.run()

        assertEquals(1, responses.size)
    }

    private fun reader(onRead: () -> Unit): PerformanceMetricsReader =
        PerformanceMetricsReader(
            observedAtMonotonicMs = {
                onRead()
                1L
            },
            processCpuTimeMs = { 2L },
            processPssKilobytes = { 3L },
            thermalStatus = { 0 },
            remainingDeviceEnergyNanowattHours = { 4L },
            isCharging = { false },
        )
}

private class QueuedExecutor : Executor {
    private val tasks = ArrayDeque<Runnable>()

    val size: Int
        get() = tasks.size

    override fun execute(command: Runnable) {
        tasks.addLast(command)
    }

    fun removeNext(): Runnable = tasks.removeFirst()

    fun runNext() {
        removeNext().run()
    }
}

private fun Any?.failureCode(): Any? =
    (((this as Map<*, *>)["failure"] as Map<*, *>)["code"])
