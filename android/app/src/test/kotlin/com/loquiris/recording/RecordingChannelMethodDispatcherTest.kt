package com.loquiris.recording

import java.util.concurrent.Executor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingChannelMethodDispatcherTest {
    @Test
    fun `recovery inventory runs off the platform callback thread`() {
        val background = QueuedExecutor()
        val main = QueuedExecutor()
        val calls = mutableListOf<String>()
        val replies = mutableListOf<Map<String, Any?>>()
        val dispatcher =
            RecordingChannelMethodDispatcher(
                handle = { method, _ ->
                    calls += method
                    mapOf("method" to method)
                },
                recoveryExecutor = background,
                replyExecutor = main,
            )

        dispatcher.dispatch("recoveryInventory", null, replies::add)

        assertTrue(calls.isEmpty())
        assertTrue(replies.isEmpty())
        background.runNext()
        assertEquals(listOf("recoveryInventory"), calls)
        assertTrue(replies.isEmpty())
        main.runNext()
        assertEquals("recoveryInventory", replies.single()["method"])
    }

    @Test
    fun `ordinary recording commands remain synchronous`() {
        val background = QueuedExecutor()
        val main = QueuedExecutor()
        val replies = mutableListOf<Map<String, Any?>>()
        val dispatcher =
            RecordingChannelMethodDispatcher(
                handle = { method, _ -> mapOf("method" to method) },
                recoveryExecutor = background,
                replyExecutor = main,
            )

        dispatcher.dispatch("snapshot", null, replies::add)

        assertEquals("snapshot", replies.single()["method"])
        assertTrue(background.isEmpty)
        assertTrue(main.isEmpty)
    }

    @Test
    fun `saving recovered audio and rebuilding playback runs off the platform callback thread`() {
        val background = QueuedExecutor()
        val main = QueuedExecutor()
        val calls = mutableListOf<String>()
        val replies = mutableListOf<Map<String, Any?>>()
        val dispatcher =
            RecordingChannelMethodDispatcher(
                handle = { method, _ ->
                    calls += method
                    mapOf("method" to method)
                },
                recoveryExecutor = background,
                replyExecutor = main,
            )

        dispatcher.dispatch("saveRecovery", null, replies::add)

        assertTrue(calls.isEmpty())
        assertTrue(replies.isEmpty())
        background.runNext()
        assertEquals(listOf("saveRecovery"), calls)
        assertTrue(replies.isEmpty())
        main.runNext()
        assertEquals("saveRecovery", replies.single()["method"])
    }
}

private class QueuedExecutor : Executor {
    private val work = ArrayDeque<Runnable>()

    val isEmpty: Boolean
        get() = work.isEmpty()

    override fun execute(command: Runnable) {
        work += command
    }

    fun runNext() {
        work.removeFirst().run()
    }
}
