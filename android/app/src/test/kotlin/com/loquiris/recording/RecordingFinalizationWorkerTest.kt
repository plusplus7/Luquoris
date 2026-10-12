package com.loquiris.recording

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingFinalizationWorkerTest {
    @Test
    fun `submission returns while finalization remains blocked off caller thread`() {
        val started = CountDownLatch(1)
        val release = CountDownLatch(1)
        val finished = CountDownLatch(1)
        val worker = RecordingFinalizationWorker()
        try {
            val accepted =
                worker.submit {
                    started.countDown()
                    release.await(2, TimeUnit.SECONDS)
                    finished.countDown()
                }

            assertTrue(accepted)
            assertTrue(started.await(1, TimeUnit.SECONDS))
            release.countDown()
            assertTrue(finished.await(1, TimeUnit.SECONDS))
        } finally {
            worker.close()
        }
    }
}
