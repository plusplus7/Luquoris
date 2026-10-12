package com.loquiris

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.HandlerThread
import com.loquiris.backup.BackupChannelContract
import com.loquiris.backup.BackupChannelController
import com.loquiris.export.ExportChannelContract
import com.loquiris.export.ExportChannelController
import com.loquiris.performance.PerformanceMetricsChannelContract
import com.loquiris.performance.PerformanceMetricsChannelController
import com.loquiris.performance.PerformanceMetricsReader
import com.loquiris.recording.RecordingChannelContract
import com.loquiris.recording.RecordingChannelController
import com.loquiris.recording.RecordingChannelMethodDispatcher
import com.loquiris.recording.RecordingPermissionChannelController
import com.loquiris.recording.SessionPlaybackChannelContract
import com.loquiris.recording.SessionPlaybackChannelController
import com.loquiris.recording.SessionPlaybackChannelMethodDispatcher
import com.loquiris.storage.StorageMetricsChannelContract
import com.loquiris.storage.StorageMetricsChannelController
import com.loquiris.transcription.TranscriptionChannelContract
import com.loquiris.transcription.TranscriptionChannelController
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.Executor

class MainActivity : FlutterActivity() {
    private val recoveryExecutor = Executors.newSingleThreadExecutor()
    private val exportExecutor = Executors.newSingleThreadExecutor()
    private val storageMetricsExecutor = Executors.newSingleThreadExecutor()
    private val performanceMetricsExecutor = Executors.newSingleThreadExecutor()
    private val transcriptionExecutor = Executors.newSingleThreadExecutor()
    private val playbackThread = HandlerThread("LoquirisSessionPlayback").apply { start() }
    private val playbackHandler = Handler(playbackThread.looper)
    private val playbackExecutor = Executor { command -> playbackHandler.post(command) }
    private var playbackController: SessionPlaybackChannelController? = null
    private var exportController: ExportChannelController? = null
    private var recordingPermissionController: RecordingPermissionChannelController? = null
    private var transcriptionController: TranscriptionChannelController? = null
    private var transcriptionEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val controller = RecordingChannelController(this)
        val dispatcher =
            RecordingChannelMethodDispatcher(
                handle = controller::handle,
                recoveryExecutor = recoveryExecutor,
                replyExecutor = { command -> runOnUiThread(command) },
            )
        val permissionController =
            RecordingPermissionChannelController(
                hasPermission = {
                    checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                        PackageManager.PERMISSION_GRANTED
                },
                requestPermission = {
                    requestPermissions(
                        arrayOf(Manifest.permission.RECORD_AUDIO),
                        RecordingPermissionChannelController.requestCode,
                    )
                },
            )
        recordingPermissionController = permissionController
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RecordingChannelContract.channelName,
        ).setMethodCallHandler { call, result ->
            if (call.method == RecordingPermissionChannelController.requestMethod) {
                permissionController.handle(call.method, call.arguments, result::success)
            } else {
                dispatcher.dispatch(call.method, call.arguments, result::success)
            }
        }
        val playback = SessionPlaybackChannelController(this)
        playbackController = playback
        val playbackDispatcher =
            SessionPlaybackChannelMethodDispatcher(
                handle = playback::handle,
                playbackExecutor = playbackExecutor,
                replyExecutor = { command -> runOnUiThread(command) },
            )
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SessionPlaybackChannelContract.channelName,
        ).setMethodCallHandler { call, result ->
            playbackDispatcher.dispatch(call.method, call.arguments, result::success)
        }
        val export =
            ExportChannelController(
                activity = this,
                exportExecutor = exportExecutor,
                replyExecutor = Executor { command -> runOnUiThread(command) },
            )
        exportController = export
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ExportChannelContract.channelName,
        ).setMethodCallHandler { call, result ->
            export.handle(call.method, call.arguments, result::success)
        }
        val backup =
            BackupChannelController(
                context = this,
                executor = exportExecutor,
                replyExecutor = Executor { command -> runOnUiThread(command) },
            )
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BackupChannelContract.channelName,
        ).setMethodCallHandler { call, result ->
            backup.handle(call.method, call.arguments, result::success)
        }
        val storageMetrics =
            StorageMetricsChannelController(
                context = this,
                executor = storageMetricsExecutor,
                replyExecutor = Executor { command -> runOnUiThread(command) },
            )
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            StorageMetricsChannelContract.channelName,
        ).setMethodCallHandler { call, result ->
            storageMetrics.handle(call.method, call.arguments, result::success)
        }
        val performanceMetrics =
            PerformanceMetricsChannelController(
                reader = PerformanceMetricsReader(this),
                metricsExecutor = performanceMetricsExecutor,
                replyExecutor = Executor { command -> runOnUiThread(command) },
            )
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PerformanceMetricsChannelContract.channelName,
        ).setMethodCallHandler { call, result ->
            performanceMetrics.handle(call.method, call.arguments, result::success)
        }
        val transcription =
            TranscriptionChannelController(
                context = this,
                inferenceExecutor = transcriptionExecutor,
                replyExecutor = Executor { command -> runOnUiThread(command) },
                eventEmitter = { event -> transcriptionEventSink?.success(event) },
            )
        transcriptionController = transcription
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TranscriptionChannelContract.channelName,
        ).setMethodCallHandler { call, result ->
            transcription.handle(call.method, call.arguments, result::success)
        }
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TranscriptionChannelContract.eventChannelName,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink,
                ) {
                    transcriptionEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    transcriptionEventSink = null
                    transcription.closeLiveOwner()
                }
            },
        )
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        if (exportController?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onNewIntent(intent: Intent) {
        setIntent(intent)
        super.onNewIntent(intent)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (requestCode == RecordingPermissionChannelController.requestCode) {
            val microphoneIndex = permissions.indexOf(Manifest.permission.RECORD_AUDIO)
            val granted =
                microphoneIndex >= 0 &&
                    grantResults.getOrNull(microphoneIndex) == PackageManager.PERMISSION_GRANTED
            if (recordingPermissionController?.complete(granted) == true) return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun onDestroy() {
        recordingPermissionController?.close()
        recordingPermissionController = null
        exportController?.close()
        exportController = null
        val playback = playbackController
        playbackController = null
        playbackHandler.post {
            playback?.close()
            playbackThread.quitSafely()
        }
        recoveryExecutor.shutdown()
        exportExecutor.shutdown()
        storageMetricsExecutor.shutdown()
        performanceMetricsExecutor.shutdown()
        transcriptionController?.close()
        transcriptionController = null
        transcriptionEventSink?.endOfStream()
        transcriptionEventSink = null
        transcriptionExecutor.shutdown()
        super.onDestroy()
    }
}
