package com.loquiris

import com.loquiris.performance.PerformanceMetricsChannelContract
import com.loquiris.performance.PerformanceMetricsChannelController
import com.loquiris.performance.PerformanceMetricsReader
import com.loquiris.transcription.TranscriptionChannelContract
import com.loquiris.transcription.TranscriptionChannelController
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val performanceMetricsExecutor = Executors.newSingleThreadExecutor()
    private val transcriptionExecutor = Executors.newSingleThreadExecutor()
    private var transcriptionController: TranscriptionChannelController? = null
    private var transcriptionEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
                }
            },
        )
    }

    override fun onDestroy() {
        performanceMetricsExecutor.shutdown()
        transcriptionController?.close()
        transcriptionController = null
        transcriptionEventSink?.endOfStream()
        transcriptionEventSink = null
        transcriptionExecutor.shutdown()
        super.onDestroy()
    }
}
