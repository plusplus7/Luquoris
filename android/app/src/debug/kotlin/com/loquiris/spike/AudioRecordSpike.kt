package com.loquiris.spike

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTimestamp
import android.media.MediaRecorder
import android.os.SystemClock
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

sealed interface AudioRecordSpikeResult {
    data class Success(
        val diagnostics: AudioRecordDiagnostics,
    ) : AudioRecordSpikeResult

    data class Failure(
        val code: String,
    ) : AudioRecordSpikeResult
}

data class AudioRouteDiagnostics(
    val id: Int,
    val type: Int,
    val productName: String,
    val isSource: Boolean,
)

data class AudioRecordDiagnostics(
    val sampleRateHz: Int,
    val channelCount: Int,
    val encoding: Int,
    val bufferBytes: Int,
    val audioSessionId: Int,
    val route: AudioRouteDiagnostics?,
    val requestedDurationMillis: Long,
    val capturedBytes: Long,
    val captureElapsedNanos: Long,
    val timestampStatus: Int,
    val framePosition: Long?,
    val frameTimestampNanos: Long?,
) {
    fun toJson(): String =
        JSONObject()
            .put("schemaVersion", 1)
            .put("sampleRateHz", sampleRateHz)
            .put("channelCount", channelCount)
            .put("encoding", encoding)
            .put("bufferBytes", bufferBytes)
            .put("audioSessionId", audioSessionId)
            .put("requestedDurationMillis", requestedDurationMillis)
            .put("capturedBytes", capturedBytes)
            .put("captureElapsedNanos", captureElapsedNanos)
            .put("timestampStatus", timestampStatus)
            .put("framePosition", framePosition ?: JSONObject.NULL)
            .put("frameTimestampNanos", frameTimestampNanos ?: JSONObject.NULL)
            .put(
                "route",
                route?.let {
                    JSONObject()
                        .put("id", it.id)
                        .put("type", it.type)
                        .put("productName", it.productName)
                        .put("isSource", it.isSource)
                } ?: JSONObject.NULL,
            ).toString(2)
}

class AudioRecordSpike internal constructor(
    private val permissionGranted: () -> Boolean,
    private val minimumBufferBytes: () -> Int,
    private val recorderFactory: (PcmCapturePlan) -> AudioRecord,
    private val elapsedRealtimeNanos: () -> Long,
) {
    constructor(context: Context) :
        this(
            permissionGranted = {
                context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                    PackageManager.PERMISSION_GRANTED
            },
            minimumBufferBytes = {
                AudioRecord.getMinBufferSize(
                    PcmCapturePlan.SAMPLE_RATE_HZ,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                )
            },
            recorderFactory = { plan -> buildRecorder(plan) },
            elapsedRealtimeNanos = SystemClock::elapsedRealtimeNanos,
        )

    fun capture(
        outputFile: File,
        durationMillis: Long,
    ): AudioRecordSpikeResult {
        if (!permissionGranted()) {
            return AudioRecordSpikeResult.Failure("microphone_permission_denied")
        }
        val minBufferBytes = minimumBufferBytes()
        if (minBufferBytes <= 0) {
            return AudioRecordSpikeResult.Failure("pcm_configuration_unsupported")
        }
        val plan =
            try {
                PcmCapturePlan.create(minBufferBytes)
            } catch (_: IllegalArgumentException) {
                return AudioRecordSpikeResult.Failure("pcm_configuration_invalid")
            }
        val targetBytes =
            try {
                plan.targetBytes(durationMillis)
            } catch (_: IllegalArgumentException) {
                return AudioRecordSpikeResult.Failure("capture_duration_invalid")
            }

        var recorder: AudioRecord? = null
        return try {
            recorder = recorderFactory(plan)
            if (recorder.state != AudioRecord.STATE_INITIALIZED) {
                return AudioRecordSpikeResult.Failure("audio_record_uninitialized")
            }
            outputFile.parentFile?.mkdirs()
            recorder.startRecording()
            val startedAtNanos = elapsedRealtimeNanos()
            val capturedBytes = writePcm(recorder, outputFile, plan, targetBytes)
            val completedAtNanos = elapsedRealtimeNanos()
            val timestamp = AudioTimestamp()
            val timestampStatus =
                recorder.getTimestamp(timestamp, AudioTimestamp.TIMEBASE_MONOTONIC)
            AudioRecordSpikeResult.Success(
                AudioRecordDiagnostics(
                    sampleRateHz = recorder.sampleRate,
                    channelCount = recorder.channelCount,
                    encoding = recorder.audioFormat,
                    bufferBytes = plan.bufferBytes,
                    audioSessionId = recorder.audioSessionId,
                    route = recorder.routedDevice?.toDiagnostics(),
                    requestedDurationMillis = durationMillis,
                    capturedBytes = capturedBytes,
                    captureElapsedNanos = completedAtNanos - startedAtNanos,
                    timestampStatus = timestampStatus,
                    framePosition =
                        timestamp.framePosition.takeIf {
                            timestampStatus == AudioRecord.SUCCESS
                        },
                    frameTimestampNanos =
                        timestamp.nanoTime.takeIf {
                            timestampStatus == AudioRecord.SUCCESS
                        },
                ),
            )
        } catch (_: SecurityException) {
            AudioRecordSpikeResult.Failure("microphone_permission_denied")
        } catch (_: UnsupportedOperationException) {
            AudioRecordSpikeResult.Failure("pcm_configuration_unsupported")
        } catch (_: IOException) {
            AudioRecordSpikeResult.Failure("pcm_file_write_failed")
        } catch (_: IllegalArgumentException) {
            AudioRecordSpikeResult.Failure("audio_record_configuration_failed")
        } catch (_: IllegalStateException) {
            AudioRecordSpikeResult.Failure("audio_record_state_failed")
        } finally {
            recorder?.let {
                if (it.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    try {
                        it.stop()
                    } catch (_: IllegalStateException) {
                        // Release remains mandatory after a failed stop.
                    }
                }
                it.release()
            }
        }
    }

    private fun writePcm(
        recorder: AudioRecord,
        outputFile: File,
        plan: PcmCapturePlan,
        targetBytes: Long,
    ): Long {
        val buffer = ByteArray(plan.bufferBytes)
        var capturedBytes = 0L
        FileOutputStream(outputFile).use { output ->
            while (capturedBytes < targetBytes) {
                val requested = minOf(buffer.size.toLong(), targetBytes - capturedBytes).toInt()
                val count =
                    recorder.read(
                        buffer,
                        0,
                        requested,
                        AudioRecord.READ_BLOCKING,
                    )
                if (count <= 0) {
                    throw IllegalStateException("audio_record_read_failed_$count")
                }
                output.write(buffer, 0, count)
                capturedBytes += count
            }
            output.flush()
            output.fd.sync()
        }
        return capturedBytes
    }

    private fun AudioDeviceInfo.toDiagnostics(): AudioRouteDiagnostics =
        AudioRouteDiagnostics(
            id = id,
            type = type,
            productName = productName.toString(),
            isSource = isSource,
        )

    companion object {
        // capture() checks the revocable permission immediately before this
        // call and converts a concurrent revocation into a typed failure.
        @SuppressLint("MissingPermission")
        private fun buildRecorder(plan: PcmCapturePlan): AudioRecord =
            AudioRecord.Builder()
                .setAudioSource(MediaRecorder.AudioSource.MIC)
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(plan.sampleRateHz)
                        .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                        .build(),
                ).setBufferSizeInBytes(plan.bufferBytes)
                .build()
    }
}
