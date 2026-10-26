package com.loquiris.transcription

import android.content.Context
import android.Manifest
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import com.loquiris.BuildConfig
import com.loquiris.recording.PcmCaptureFrame
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CompletionStage
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** Fixed diagnostic inventory, not an approved/redistributable production bundle. */
internal object StreamingProbeBundle {
    // Canonical sorted path/role/bytes/SHA inventory of the four child-verified files.
    const val digest = "18c2bc28a25d62131b108329f79a446429a2b1a757102d70288a7c777fe7933b"
    const val fileModelId = "debug-native-file-probe"
}

/** Debug source-set delegate, loaded only behind the explicit native-spike flag. */
class StreamingDebugBridge(context: Context, messenger: BinaryMessenger) : AutoCloseable {
    private val closed = AtomicBoolean()
    private val creation = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(messenger, StreamingChannelContract.channelName)
    private val controller = StreamingChannelController(
        BuildConfig.DEBUG && BuildConfig.LOQUIRIS_STREAMING_NATIVE_SPIKE,
        StreamingPlatformLeaseFactory { request, identity, events, failure ->
            when (StreamingProbeRoute.resolve(request.modelId, request.bundleSha256,
                context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED)) {
                StreamingProbeRoute.FILE -> {
                    val fixture = readVerifiedProbeFixture(context)
                    if (fixture == null) RejectedStreamingProbeLease()
                    else StreamingFileProbeLease(context.applicationContext, identity, request.bundleSha256, fixture, events, failure)
                }
                StreamingProbeRoute.MICROPHONE -> StreamingMicrophoneHardwareProbe(context.applicationContext,
                    identity, request.bundleSha256, events, failure).lease
                StreamingProbeRoute.RECORDER -> StreamingRecorderHardwareLease(context.applicationContext,
                    request, identity, events, failure).lease
                null -> RejectedStreamingProbeLease()
            }
        },
        creation,
        Executor { task -> check(main.post(task)) },
        { event -> if (!closed.get()) channel.invokeMethod("event", event) },
        { UUID.randomUUID().toString() },
    )

    init {
        channel.setMethodCallHandler { call, result ->
            controller.handle(call.method, call.arguments) { fields ->
                if (!closed.get()) result.success(fields)
            }
        }
    }

    override fun close() {
        if (!closed.compareAndSet(false, true)) return
        controller.closeOwner()
        channel.setMethodCallHandler(null)
        creation.shutdown() // Pending creations still return owned leases for cancellation.
    }
}

private class StreamingProbeStage<T>(private val root: CompletableFuture<T>) : CompletionStage<T> by root {
    override fun toCompletableFuture(): CompletableFuture<T> = root.thenApply { it }
}

private class RejectedStreamingProbeLease : StreamingPlatformLease {
    override fun start(): CompletionStage<StreamingStopCause?> =
        CompletableFuture.completedFuture(StreamingStopCause.MODEL_UNAVAILABLE)
    override fun close(reason: StreamingPlatformCloseReason): CompletionStage<Unit> = CompletableFuture.completedFuture(Unit)
}

/** Verification happens on the creation worker, before adopting a remote lease. */
private fun readVerifiedProbeFixture(context: Context): ByteArray? = try {
    val file = File(context.filesDir.canonicalFile, "streaming-native-spike-20261016/fixture.wav")
    if (!file.isFile || file.canonicalFile != file.absoluteFile || file.length() != 1440044L) null
    else file.readBytes().takeIf { bytes ->
        MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) } ==
            "83440d4ccbd82dafd1a88346ab448e1dd309e408c598d665413b910cc92c40a7"
    }
} catch (_: Exception) { null }

/** No microphone, recorder mutation, file writes, or production model selection. */
private class StreamingFileProbeLease(
    context: Context,
    private val identity: StreamingRemoteIdentity,
    digest: String,
    private val fixture: ByteArray,
    events: (StreamingCaptureEvent) -> Unit,
    private val failure: (StreamingStopCause) -> Unit,
) : StreamingPlatformLease {
    private val worker = Executors.newSingleThreadExecutor()
    private val started = AtomicBoolean()
    private val closing = AtomicBoolean()
    private val ready = CompletableFuture<StreamingStopCause?>()
    private val readyStage = StreamingProbeStage(ready)
    private val released = CompletableFuture<Unit>()
    private val releasedStage = StreamingProbeStage(released)
    private val binding = StreamingMessengerBinding(context, identity, digest,
        "com.loquiris.spike.StreamingNativeKernelProbeService", ::failed, { reply, _ ->
            if (reply is StreamingRemoteReply.Ready && ready.complete(null)) {
                worker.execute(::runFile)
            }
        })
    private val consumer = StreamingPcmConsumer(binding.session, { batch -> batch.forEach(events) }, ::failed)

    override fun start(): CompletionStage<StreamingStopCause?> {
        if (started.compareAndSet(false, true)) worker.execute {
            if (!closing.get() && !binding.bindRemote()) failed(StreamingStopCause.ENGINE)
        }
        return readyStage
    }

    private fun runFile() {
        try {
            for (part in 0L..1L) {
                for (chunk in 0L until 20L) {
                    if (closing.get()) return
                    val offset = 44 + chunk.toInt() * 6400
                    consumer.consume(PcmCaptureFrame(part * 20 + chunk,
                        fixture.copyOfRange(offset, offset + 6400), part * 100000 + chunk * 3200, part))
                    consumer.stopCause?.let { failed(it); return }
                }
                if (closing.get()) return
                consumer.finishBoundary(if (part == 0L) StreamingBoundaryReason.PAUSE else StreamingBoundaryReason.STOP)
            }
        } catch (_: OutOfMemoryError) { failed(StreamingStopCause.MEMORY) }
        catch (_: Throwable) { failed(StreamingStopCause.ENGINE) }
    }

    private fun failed(cause: StreamingStopCause) {
        ready.complete(cause)
        failure(cause) // Notification only; caller must never wait for this callback's release.
    }

    override fun close(reason: StreamingPlatformCloseReason): CompletionStage<Unit> {
        if (closing.compareAndSet(false, true)) {
            if (reason != StreamingPlatformCloseReason.STOPPED) consumer.closeAsync()
            worker.execute {
                try {
                    if (reason == StreamingPlatformCloseReason.STOPPED) consumer.finishBoundary(StreamingBoundaryReason.STOP)
                    awaitRelease()
                } catch (problem: Throwable) {
                    released.completeExceptionally(problem)
                } finally { worker.shutdown() }
            }
        }
        return releasedStage
    }

    private fun awaitRelease() {
        // Missing ACK deliberately retains ownership; no timeout fabricates release.
        consumer.closeAsync().toCompletableFuture().join()
        binding.closeBinding().toCompletableFuture().join()
        released.complete(Unit)
    }
}
