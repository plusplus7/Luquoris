package com.loquiris.spike

import android.app.Application
import android.app.Service
import android.content.Intent
import android.os.IBinder
import com.loquiris.transcription.StreamingMessengerHost

/** Android IPC registration fault fixture; no model is ever created. Debug only. */
class StreamingLinkFailureProbeService : Service() {
    private lateinit var host: StreamingMessengerHost
    override fun onCreate() {
        super.onCreate()
        check(Application.getProcessName() == "$packageName:streaming_link_failure")
        host = StreamingMessengerHost(registerPeerDeath = { _, _ -> throw OutOfMemoryError("synthetic registration failure") }) {
            error("registration failure must not create a kernel")
        }
    }
    override fun onBind(intent: Intent): IBinder = host.binder
    override fun onDestroy() {
        host.disposeRemoteHost()
        super.onDestroy()
    }
}
