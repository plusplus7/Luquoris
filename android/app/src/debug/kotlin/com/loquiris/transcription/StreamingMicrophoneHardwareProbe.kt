package com.loquiris.transcription

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import com.loquiris.recording.*
import java.io.File
import java.util.UUID
import java.util.concurrent.CompletableFuture
import java.util.concurrent.atomic.AtomicInteger
import org.json.JSONArray
import org.json.JSONObject

/** Android hardware wiring only. Scheduling/ownership lives in the tested owner/runner. */
internal class StreamingMicrophoneHardwareProbe(
    private val context: Context,
    identity: StreamingRemoteIdentity,
    digest: String,
    events: (StreamingCaptureEvent) -> Unit,
    failure: (StreamingStopCause) -> Unit,
) {
    private var binding: StreamingMessengerBinding? = null
    private var consumer: StreamingPcmConsumer? = null
    private var remoteConstructionUncertain = false
    private var captureFactory: StreamingProbeCaptureFactory? = null
    private val captureConstructionUncertain: Boolean get() = captureFactory?.releaseUncertain ?: false
    private var directory: File? = null
    private var readiness: ((StreamingStopCause?) -> Unit)? = null
    private val textCount = AtomicInteger()
    private val gapCount = AtomicInteger()
    private val id = "streaming-dart-mic-${UUID.randomUUID()}"
    val lease = StreamingMicrophoneProbeOwner(
        startRemote = { ready ->
            readiness = ready
            remoteConstructionUncertain = true
            val remote = StreamingMessengerBinding(context, identity, digest,
                "com.loquiris.spike.StreamingNativeKernelProbeService",
                { cause -> readiness?.invoke(cause); failure(cause) },
                { reply, _ -> if (reply is StreamingRemoteReply.Ready) readiness?.invoke(null) })
            binding = remote
            remoteConstructionUncertain = false
            consumer = StreamingPcmConsumer(remote.session, { batch ->
                batch.forEach { event ->
                    if (event is StreamingCaptureText) textCount.incrementAndGet()
                    if (event is StreamingCaptureGap) gapCount.incrementAndGet()
                    events(event)
                }
            }, failure)
            if (!remote.bindRemote()) ready(StreamingStopCause.ENGINE)
        },
        runProbe = { wait, cancelled, stopped ->
            val activeConsumer = checkNotNull(consumer)
            val report = StreamingMicrophoneProbeRunner(
                ::createCapture, activeConsumer, activeConsumer::finishBoundary,
                activeConsumer::closeAsync, wait, cancelled, stopped,
            ).run()
            val snapshot = report.capture
            val complete = snapshot != null && snapshot.state == RecordingCapturePipelineState.finished &&
                snapshot.failureCode == null && snapshot.bytesWritten > 0 &&
                snapshot.fanOut.canonicalRejectedFrames == 0L && snapshot.fanOut.canonicalSinkFailures == 0L &&
                snapshot.fanOut.canonicalAcceptedFrames == snapshot.fanOut.canonicalProcessedFrames &&
                snapshot.fanOut.inferenceConsumerFailures == 0L &&
                directory?.let { AtomicRecordingSegmentManifestStore(it).load() is RecordingSegmentManifestDecodeResult.Success } == true
            if (report.status == StreamingMicrophoneProbeStatus.COMPLETED && !complete) {
                report.copy(status = StreamingMicrophoneProbeStatus.FAILED,
                    failure = report.failure ?: StreamingStopCause.ENGINE,
                    resourcesReleased = report.resourcesReleased && !captureConstructionUncertain)
            } else report.copy(resourcesReleased = report.resourcesReleased && !captureConstructionUncertain)
        },
        closeInference = { consumer?.closeAsync() ?: binding?.session?.closeRemote() ?: CompletableFuture.completedFuture(Unit) },
        closeRemote = {
            if (remoteConstructionUncertain || captureConstructionUncertain) {
                CompletableFuture<Unit>().also { it.completeExceptionally(IllegalStateException("streaming_probe_construction_release_unconfirmed")) }
            } else binding?.closeBinding() ?: CompletableFuture.completedFuture(Unit)
        },
        onReport = ::writeReport,
        onFailure = failure,
    )

    private fun createCapture(): RecordingCapturePipeline {
        // Recheck immediately before touching hardware; no permission request or grant.
        check(context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED)
        val folder = File(context.filesDir, id)
        check(folder.mkdir()) // Always new, never clear/reset an earlier recording.
        directory = folder
        val factory = StreamingProbeCaptureFactory(source = {
            val createdSource = AndroidAudioRecordSource.create(context)
            check(createdSource is PcmCaptureSourceCreateResult.Success)
            createdSource.source
        }, encoder = {
            val createdEncoder = AndroidAacSegmentEncoder.create(folder, id)
            check(createdEncoder is RecordingEncoderCreateResult.Success)
            AndroidCanonicalPcmEncoder(createdEncoder.encoder)
        })
        captureFactory = factory
        return factory.create()
    }

    private fun writeReport(report: StreamingMicrophoneProbeReport) {
        val folder = directory ?: return
        val snapshot = report.capture
        val json = JSONObject().put("run", id).put("microphone", true)
            .put("dartChannelProbe", true).put("status", report.status.name)
            .put("cleanupFailed", report.cleanupFailed)
            .put("resourcesReleased", report.resourcesReleased)
            .put("failure", report.failure?.name ?: JSONObject.NULL)
            .put("canonicalBytes", snapshot?.bytesWritten ?: 0)
            .put("canonicalAcceptedFrames", snapshot?.fanOut?.canonicalAcceptedFrames ?: 0)
            .put("canonicalProcessedFrames", snapshot?.fanOut?.canonicalProcessedFrames ?: 0)
            .put("canonicalRejectedFrames", snapshot?.fanOut?.canonicalRejectedFrames ?: 0)
            .put("canonicalSinkFailures", snapshot?.fanOut?.canonicalSinkFailures ?: 0)
            .put("textEvents", textCount.get()).put("gapEvents", gapCount.get())
            .put("controlMilliseconds", JSONArray(report.controlsMs))
            .put("limitation", "Short debug microphone/channel smoke; not lexical accuracy, decoded AAC sample audit or release qualification")
        File(folder, "probe-report.json").writeText(json.toString(2))
        // No raw transcript, audio, private paths or debugger capability in logs.
        println("streaming_dart_microphone_report=$id/probe-report.json")
    }
}
