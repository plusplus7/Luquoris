package com.loquiris.recording

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WakeLockLeaseTest {
    @Test
    fun `acquire and release are idempotent`() {
        val controller = FakeWakeLockController()
        val lease = WakeLockLease(controller)

        assertTrue(lease.acquire())
        assertTrue(lease.acquire())
        assertEquals(1, controller.acquireCalls)

        lease.release()
        lease.release()

        assertEquals(1, controller.releaseCalls)
        assertFalse(controller.isHeld)
    }

    @Test
    fun `failed acquire remains retryable`() {
        val controller = FakeWakeLockController(failFirstAcquire = true)
        val lease = WakeLockLease(controller)

        assertFalse(lease.acquire())
        assertFalse(controller.isHeld)
        assertTrue(lease.acquire())
        assertEquals(2, controller.acquireCalls)
    }
}

private class FakeWakeLockController(
    private var failFirstAcquire: Boolean = false,
) : WakeLockController {
    override var isHeld = false
        private set
    var acquireCalls = 0
        private set
    var releaseCalls = 0
        private set

    override fun acquire(): Boolean {
        acquireCalls += 1
        if (failFirstAcquire) {
            failFirstAcquire = false
            return false
        }
        isHeld = true
        return true
    }

    override fun release() {
        releaseCalls += 1
        isHeld = false
    }
}
