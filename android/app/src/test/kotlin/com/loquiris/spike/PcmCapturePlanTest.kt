package com.loquiris.spike

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class PcmCapturePlanTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `one second of mono 16 bit 16 kHz PCM is 32000 bytes`() {
        val plan = PcmCapturePlan.create(minBufferBytes = 3_100)

        assertEquals(32_000L, plan.targetBytes(durationMillis = 1_000))
        assertEquals(3_200, plan.bufferBytes)
    }

    @Test
    fun `capture buffer is frame aligned and never below platform minimum`() {
        val plan = PcmCapturePlan.create(minBufferBytes = 3_201)

        assertEquals(3_840, plan.bufferBytes)
        assertEquals(0, plan.bufferBytes % plan.bytesPerTwentyMilliseconds)
    }

    @Test
    fun `capture duration must be positive and bounded for the spike`() {
        val plan = PcmCapturePlan.create(minBufferBytes = 3_200)

        assertThrows(IllegalArgumentException::class.java) {
            plan.targetBytes(durationMillis = 0)
        }
        assertThrows(IllegalArgumentException::class.java) {
            plan.targetBytes(durationMillis = 60_001)
        }
    }

    @Test
    fun `unsupported recorder construction returns a stable typed failure`() {
        val spike =
            AudioRecordSpike(
                permissionGranted = { true },
                minimumBufferBytes = { 3_200 },
                recorderFactory = { throw UnsupportedOperationException("unsupported") },
                elapsedRealtimeNanos = { 0L },
            )

        val result = spike.capture(temporaryFolder.newFile(), durationMillis = 1_000)

        assertEquals(
            AudioRecordSpikeResult.Failure("pcm_configuration_unsupported"),
            result,
        )
    }
}
