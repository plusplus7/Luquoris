package com.loquiris

import com.loquiris.performance.PerformanceMetricsChannelContract
import com.loquiris.performance.PerformanceMetricsChannelController
import com.loquiris.performance.PerformanceMetricsReader
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executor
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val performanceMetricsExecutor = Executors.newSingleThreadExecutor()

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
    }

    override fun onDestroy() {
        performanceMetricsExecutor.shutdown()
        super.onDestroy()
    }
}
