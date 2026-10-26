package com.loquiris.transcription

import android.app.Application
import android.app.Service
import android.content.Intent
import android.os.IBinder

/** Debug-only, non-exported; no recognizer is enabled until a verified catalog is wired. */
class StreamingInferenceService : Service() {
    private lateinit var host: StreamingMessengerHost
    override fun onCreate() {
        super.onCreate()
        check(Application.getProcessName() == "$packageName:streaming")
        host = StreamingMessengerHost { throw StreamingRemoteModelUnavailable() }
    }
    override fun onBind(intent: Intent): IBinder = host.binder
    override fun onDestroy() {
        host.disposeRemoteHost()
        super.onDestroy()
    }
}
