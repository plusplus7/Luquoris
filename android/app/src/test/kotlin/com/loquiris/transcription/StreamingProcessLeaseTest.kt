package com.loquiris.transcription

import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test

class StreamingProcessLeaseTest {
    @Test fun leaseSurvivesServiceReplacementUntilOwnerReleases() {
        val process = StreamingProcessLease()
        val oldService = requireNotNull(process.acquireProcessLease())
        // Destroying a service/binding is not a native release acknowledgement.
        assertNull("a replacement service cannot adopt a second recognizer", process.acquireProcessLease())
        oldService.close()
        val replacement = requireNotNull(process.acquireProcessLease())
        oldService.close() // Late/duplicate release cannot clear the new owner.
        assertNull(process.acquireProcessLease())
        replacement.close()
        requireNotNull(process.acquireProcessLease()).close()
    }

    @Test fun onlyOneConcurrentHostCanOwnRecognizer() {
        val process = StreamingProcessLease()
        val executor = Executors.newFixedThreadPool(8)
        val start = CountDownLatch(1)
        try {
            val attempts = (0 until 16).map {
                executor.submit<AutoCloseable?> { check(start.await(2, TimeUnit.SECONDS)); process.acquireProcessLease() }
            }
            start.countDown()
            val acquired = attempts.mapNotNull { it.get(2, TimeUnit.SECONDS) }
            try { assertEquals("one physical process admits one recognizer", 1, acquired.size) }
            finally { acquired.forEach { it.close() } }
            requireNotNull(process.acquireProcessLease()).close()
        } finally { start.countDown(); executor.shutdownNow() }
    }
}
