package com.loquiris.spike

import android.app.Application
import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.os.Process
import com.loquiris.recording.PcmCaptureFrame
import com.loquiris.transcription.StreamingMessengerHost
import com.loquiris.transcription.StreamingRemoteKernel
import com.loquiris.transcription.StreamingRemoteModelUnavailable
import com.loquiris.transcription.StreamingRemoteResult

/** Synthetic IPC/death fixture, debug source set only; never a model implementation. */
class StreamingProcessProbeService : Service() {
    private lateinit var host: StreamingMessengerHost
    override fun onCreate() {
        super.onCreate()
        check(Application.getProcessName() == "$packageName:streaming_probe")
        host = StreamingMessengerHost { digest ->
            if (digest != "0".repeat(64)) throw StreamingRemoteModelUnavailable()
            object : StreamingRemoteKernel {
                override fun finishUtterance() = StreamingRemoteResult.Text("fixture:final", true)
                override fun decode(frame: PcmCaptureFrame): StreamingRemoteResult.Text {
                    if (frame.copyBytes()[0] == 7.toByte()) Process.killProcess(Process.myPid())
                    return StreamingRemoteResult.Text("fixture:${frame.sequence}", false)
                }
                override fun close() = Unit
            }
        }
    }
    override fun onBind(intent: Intent): IBinder = host.binder
    override fun onDestroy() {
        host.disposeRemoteHost()
        super.onDestroy()
    }
}
