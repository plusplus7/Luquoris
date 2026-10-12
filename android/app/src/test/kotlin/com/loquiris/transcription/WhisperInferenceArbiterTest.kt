package com.loquiris.transcription

import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test

class WhisperInferenceArbiterTest {
    @Test
    fun `live reservation excludes post session inference until released`() {
        val arbiter = WhisperInferenceArbiter()
        val live = checkNotNull(arbiter.acquireLive { false })
        val executor = Executors.newSingleThreadExecutor()
        val entered = CountDownLatch(1)
        try {
            val post = executor.submit {
                arbiter.acquirePostSession { false }!!.use { entered.countDown() }
            }
            assertFalse(entered.await(100, TimeUnit.MILLISECONDS))
            assertNull(arbiter.acquireLive { false })
            live.close()
            assertTrue(entered.await(2, TimeUnit.SECONDS))
            post.get(2, TimeUnit.SECONDS)
        } finally {
            live.close()
            executor.shutdownNow()
        }
    }

    @Test
    fun `cancelled waiter never enters native work`() {
        val arbiter = WhisperInferenceArbiter()
        arbiter.acquireLive { false }!!.use {
            assertNull(arbiter.acquirePostSession { true })
        }
        assertNotNull(arbiter.acquirePostSession { false }.also { it?.close() })
    }
}
