package com.loquiris.remote

import org.junit.Assert.*
import org.junit.Test

class RemoteTransferGateTest {
    @Test fun prepareAbortsActiveNetworkAndPreventsNewRequestsUntilResume() {
        val gate=RemoteTransferGate()
        var disconnected=false
        val lease=gate.register { disconnected=true }
        gate.pause()
        assertTrue(disconnected)
        assertTrue(gate.paused)
        var lateAborted=false
        gate.register { lateAborted=true }.close()
        assertTrue(lateAborted)
        lease.close()
        gate.resume()
        assertFalse(gate.paused)
        var resumedAborted=false
        gate.register { resumedAborted=true }.close()
        assertFalse(resumedAborted)
    }
}
