package com.loquiris.recording

import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class RecordingForegroundPromotionTest {
    @Test
    fun `foreground promotion precedes state load and preparing commit`() {
        val order = mutableListOf<String>()
        val store = object : RecordingStateStore {
            override fun load(): RecordingStateLoadResult {
                order += "load"
                return RecordingStateLoadResult.Absent
            }
            override fun save(snapshot: NativeRecordingSnapshot): Boolean {
                order += "save"
                return true
            }
        }

        val promoted = RecordingForegroundPromotion.beforePreparation(
            ForegroundPromoter { order += "foreground" },
        ) {
            val initialized = PersistedRecordingStateMachine.create(store)
                as RecordingStateMachineInitialization.Success
            assertTrue(initialized.machine.start("meeting") is RecordingCommandResult.Success)
        }

        assertTrue(promoted)
        assertEquals(listOf("foreground", "load", "save"), order)
    }

    @Test
    fun `blocked state load or commit cannot delay foreground promotion`() {
        for (blockLoad in listOf(true, false)) {
            val entered = CountDownLatch(1)
            val resume = CountDownLatch(1)
            val promoted = AtomicBoolean()
            val worker = Executors.newSingleThreadExecutor()
            val store = object : RecordingStateStore {
                override fun load(): RecordingStateLoadResult {
                    if (blockLoad) {
                        entered.countDown()
                        check(resume.await(3, TimeUnit.SECONDS))
                    }
                    return RecordingStateLoadResult.Absent
                }
                override fun save(snapshot: NativeRecordingSnapshot): Boolean {
                    if (!blockLoad) {
                        entered.countDown()
                        check(resume.await(3, TimeUnit.SECONDS))
                    }
                    return true
                }
            }
            try {
                val result = worker.submit<Boolean> {
                    RecordingForegroundPromotion.beforePreparation(
                        ForegroundPromoter { promoted.set(true) },
                    ) {
                        val initialized = PersistedRecordingStateMachine.create(store)
                            as RecordingStateMachineInitialization.Success
                        check(initialized.machine.start("meeting") is RecordingCommandResult.Success)
                    }
                }
                assertTrue(entered.await(2, TimeUnit.SECONDS))
                assertTrue("Foreground must already be active while storage is blocked", promoted.get())
                assertFalse(result.isDone)
                resume.countDown()
                assertTrue(result.get(2, TimeUnit.SECONDS))
            } finally {
                resume.countDown()
                worker.shutdownNow()
            }
        }
    }

    @Test
    fun `rejected promotion never enters recording preparation`() {
        var preparations = 0
        val promoted = RecordingForegroundPromotion.beforePreparation(
            ForegroundPromoter { error("foreground rejected") },
        ) { preparations++ }

        assertFalse(promoted)
        assertEquals(0, preparations)
    }

    @Test
    fun `preparation failure remains distinct from promotion failure`() {
        val failure = IllegalStateException("storage fixture")
        var promoted = false
        try {
            RecordingForegroundPromotion.beforePreparation(
                ForegroundPromoter { promoted = true },
            ) { throw failure }
            fail("Preparation failure must not become a false promotion result")
        } catch (actual: IllegalStateException) {
            assertSame(failure, actual)
            assertTrue(promoted)
        }
    }

    @Test
    fun `platform promotion exception becomes failure`() {
        val promoted =
            RecordingForegroundPromotion.attempt(
                ForegroundPromoter { error("foreground start disallowed") },
            )

        assertFalse(promoted)
    }

    @Test
    fun `successful platform promotion is reported`() {
        var calls = 0

        val promoted = RecordingForegroundPromotion.attempt(ForegroundPromoter { calls += 1 })

        assertTrue(promoted)
        assertTrue(calls == 1)
    }
}
