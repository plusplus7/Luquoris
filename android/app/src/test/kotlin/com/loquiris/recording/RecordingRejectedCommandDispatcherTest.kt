package com.loquiris.recording

import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingRejectedCommandDispatcherTest {
    @Test
    fun `newer queued start promotes while rejected receipt is blocked`() {
        val dispatcher = RecordingRejectedCommandDispatcher()
        val serviceMain = Executors.newSingleThreadExecutor()
        val receiptEntered = CountDownLatch(1)
        val releaseReceipt = CountDownLatch(1)
        val receiptCompleted = CountDownLatch(1)
        val rejectionReturned = CountDownLatch(1)
        val stopped = AtomicBoolean(true)
        val promoted = AtomicBoolean()
        try {
            val rejected = serviceMain.submit<Int> {
                val result = dispatcher.reject(
                    stopRejectedStart = {
                        // stopSelfResult is false because a newer start is pending.
                        stopped.set(false)
                        2
                    },
                    persistReceipt = {
                        receiptEntered.countDown()
                        check(releaseReceipt.await(5, TimeUnit.SECONDS))
                        receiptCompleted.countDown()
                    },
                )
                rejectionReturned.countDown()
                result
            }
            assertTrue(receiptEntered.await(2, TimeUnit.SECONDS))
            val nextStart = serviceMain.submit<Boolean> {
                RecordingForegroundPromotion.beforePreparation(
                    ForegroundPromoter { promoted.set(true) },
                ) {}
            }
            assertTrue("Rejection must return without waiting for receipt storage", rejectionReturned.await(2, TimeUnit.SECONDS))
            assertEquals(2, rejected.get(2, TimeUnit.SECONDS))
            assertTrue(nextStart.get(2, TimeUnit.SECONDS))
            assertFalse(stopped.get())
            assertTrue(promoted.get())
            assertEquals(1L, receiptCompleted.count)
        } finally {
            releaseReceipt.countDown()
            dispatcher.close()
            serviceMain.shutdownNow()
        }
    }

    @Test
    fun `service destruction drains already accepted failure receipts`() {
        val dispatcher = RecordingRejectedCommandDispatcher()
        val releaseReceipt = CountDownLatch(1)
        val completed = CountDownLatch(1)
        try {
            dispatcher.reject({ 2 }) {
                check(releaseReceipt.await(5, TimeUnit.SECONDS))
                completed.countDown()
            }
            dispatcher.close()
            assertEquals(1L, completed.count)
            releaseReceipt.countDown()
            assertTrue(completed.await(2, TimeUnit.SECONDS))
        } finally {
            releaseReceipt.countDown()
            dispatcher.close()
        }
    }
}
