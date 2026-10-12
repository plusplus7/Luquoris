package com.loquiris.recording

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.pm.PackageManager
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RecordingPermissionDenialInstrumentedTest {
    @Test
    fun deniedMicrophonePermissionReturnsTypedFailureWithoutDispatchingService() {
        val context =
            MicrophoneDeniedContext(
                InstrumentationRegistry.getInstrumentation().targetContext,
            )

        val result = RecordingForegroundService.start(context, "permission-denied-session")

        assertEquals(
            RecordingForegroundServiceStartResult.Failed("recording_permission_denied"),
            result,
        )
        assertFalse(context.serviceStartRequested)
    }
}

private class MicrophoneDeniedContext(
    base: Context,
) : ContextWrapper(base) {
    var serviceStartRequested = false
        private set

    override fun checkSelfPermission(permission: String): Int =
        if (permission == Manifest.permission.RECORD_AUDIO) {
            PackageManager.PERMISSION_DENIED
        } else {
            super.checkSelfPermission(permission)
        }

    override fun startForegroundService(service: Intent): ComponentName? {
        serviceStartRequested = true
        return service.component
    }
}
