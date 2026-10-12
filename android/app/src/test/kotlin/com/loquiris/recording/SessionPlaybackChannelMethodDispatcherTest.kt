package com.loquiris.recording

import java.util.concurrent.Executor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SessionPlaybackChannelMethodDispatcherTest {
    @Test
    fun `playback work and reply leave the platform callback thread`() {
        val playback = QueuedPlaybackExecutor()
        val main = QueuedPlaybackExecutor()
        val handled = mutableListOf<String>()
        val replies = mutableListOf<Map<String, Any?>>()
        val dispatcher =
            SessionPlaybackChannelMethodDispatcher(
                handle = { method, _, reply ->
                    handled += method
                    reply(mapOf("method" to method))
                },
                playbackExecutor = playback,
                replyExecutor = main,
            )

        dispatcher.dispatch("load", null, replies::add)

        assertTrue(handled.isEmpty())
        assertTrue(replies.isEmpty())
        playback.runNext()
        assertEquals(listOf("load"), handled)
        assertTrue(replies.isEmpty())
        main.runNext()
        assertEquals("load", replies.single()["method"])
    }
}

private class QueuedPlaybackExecutor : Executor {
    private val work = ArrayDeque<Runnable>()

    override fun execute(command: Runnable) {
        work += command
    }

    fun runNext() {
        work.removeFirst().run()
    }
}
