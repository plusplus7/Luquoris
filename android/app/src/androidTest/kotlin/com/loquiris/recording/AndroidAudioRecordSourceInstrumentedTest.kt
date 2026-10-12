package com.loquiris.recording

import android.Manifest
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.GrantPermissionRule
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidAudioRecordSourceInstrumentedTest {
    @get:Rule
    val microphonePermission: GrantPermissionRule =
        GrantPermissionRule.grant(Manifest.permission.RECORD_AUDIO)

    @Test
    fun capturesProductionMono16kPcmAndStopsCleanly() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val created = AndroidAudioRecordSource.create(context)
        assertTrue("source creation failed: $created", created is PcmCaptureSourceCreateResult.Success)
        val source = (created as PcmCaptureSourceCreateResult.Success).source

        assertTrue(source.start())
        val target = ByteArray(RecordingCapturePipeline.PCM_READ_BYTES)
        val read = source.read(target)

        assertTrue("read failed: $read", read > 0)
        assertEquals(0, read % AndroidAacSegmentEncoder.PCM_BYTES_PER_SAMPLE)
        source.timestampFramePosition()?.let { assertTrue(it >= 0) }
        assertTrue(source.stop())
        source.release()
    }
}
