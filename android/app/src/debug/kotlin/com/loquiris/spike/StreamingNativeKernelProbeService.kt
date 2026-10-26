package com.loquiris.spike

import android.app.Application
import android.app.Service
import android.content.Intent
import android.os.IBinder
import com.loquiris.transcription.StreamingMessengerHost

/** Opt-in file-input native spike, separate from the production service and recorder. */
class StreamingNativeKernelProbeService : Service() {
    private lateinit var host: StreamingMessengerHost
    override fun onCreate() {
        super.onCreate()
        check(Application.getProcessName() == "$packageName:streaming_native_probe")
        host = StreamingMessengerHost { digest -> createVerifiedNativeProbeKernel(filesDir, packageName, digest) }
    }
    override fun onBind(intent: Intent): IBinder = host.binder
    override fun onDestroy() {
        host.disposeRemoteHost()
        super.onDestroy()
    }
}
