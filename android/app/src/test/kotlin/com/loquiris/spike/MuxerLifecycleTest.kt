package com.loquiris.spike

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class MuxerLifecycleTest {
    @Test
    fun `durable atomic replacement syncs parent directory after move`() {
        val events = mutableListOf<String>()

        durableAtomicReplace(
            writeAndSyncTemporary = { events += "temporary-synced" },
            atomicReplace = { events += "atomically-replaced" },
            syncParentDirectory = { events += "directory-synced" },
        )

        assertEquals(
            listOf("temporary-synced", "atomically-replaced", "directory-synced"),
            events,
        )
    }

    @Test
    fun `primary failure survives stop and release failures`() {
        val primary = IllegalStateException("write failed")
        var releaseAttempted = false

        val result =
            finishMuxerLifecycle(
                primaryFailure = primary,
                stop = { throw IllegalArgumentException("stop failed") },
                release = {
                    releaseAttempted = true
                    throw UnsupportedOperationException("release failed")
                },
            )

        assertSame(primary, result)
        assertTrue(releaseAttempted)
        assertEquals(listOf("stop failed", "release failed"), result?.suppressed?.map(Throwable::message))
    }

    @Test
    fun `cleanup failure is returned when no primary failure exists`() {
        val result =
            finishMuxerLifecycle(
                primaryFailure = null,
                stop = { throw IllegalArgumentException("stop failed") },
                release = {},
            )

        assertEquals("stop failed", result?.message)
    }
}
