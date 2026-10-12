package com.loquiris.recording

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioRecordingConfiguration
import android.media.AudioTimestamp
import android.media.MediaRecorder
import java.util.concurrent.Executor
import kotlin.math.max

sealed interface PcmCaptureSourceCreateResult {
    data class Success(
        val source: AndroidAudioRecordSource,
    ) : PcmCaptureSourceCreateResult

    data class Failure(
        val code: String,
    ) : PcmCaptureSourceCreateResult
}

class AndroidAudioRecordSource private constructor(
    private val recorder: AudioRecord,
    callbackExecutor: Executor,
    private val onClientSilencedChanged: (Boolean) -> Unit,
) : PcmCaptureSource {
    @Volatile
    private var recording = false

    @Volatile
    private var released = false

    @Volatile
    private var lastClientSilenced: Boolean? = null

    private val recordingCallback =
        object : AudioManager.AudioRecordingCallback() {
            override fun onRecordingConfigChanged(configs: List<AudioRecordingConfiguration>) {
                val configuration =
                    configs.firstOrNull { it.clientAudioSessionId == recorder.audioSessionId } ?: return
                val silenced = configuration.isClientSilenced
                val previous = lastClientSilenced
                lastClientSilenced = silenced
                if (silenced && previous != true) onClientSilencedChanged(true)
                if (!silenced && previous == true) onClientSilencedChanged(false)
            }
        }

    init {
        recorder.registerAudioRecordingCallback(callbackExecutor, recordingCallback)
    }

    override fun start(): Boolean {
        if (released) return false
        if (recording) return true
        return try {
            recorder.startRecording()
            recording = recorder.recordingState == AudioRecord.RECORDSTATE_RECORDING
            recording
        } catch (_: IllegalStateException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    override fun read(target: ByteArray): Int {
        if (!recording || released) return PcmCaptureSource.READ_STOPPED
        return try {
            val read = recorder.read(target, 0, target.size, AudioRecord.READ_BLOCKING)
            if (!recording && read <= 0) PcmCaptureSource.READ_STOPPED else read
        } catch (_: IllegalStateException) {
            if (recording) AudioRecord.ERROR_INVALID_OPERATION else PcmCaptureSource.READ_STOPPED
        }
    }

    override fun stop(): Boolean {
        if (released || !recording) return true
        recording = false
        return try {
            recorder.stop()
            true
        } catch (_: IllegalStateException) {
            false
        }
    }

    override fun timestampFramePosition(): Long? {
        if (released) return null
        val timestamp = AudioTimestamp()
        return try {
            if (recorder.getTimestamp(timestamp, AudioTimestamp.TIMEBASE_MONOTONIC) == AudioRecord.SUCCESS) {
                timestamp.framePosition
            } else {
                null
            }
        } catch (_: IllegalStateException) {
            null
        }
    }

    override fun release() {
        if (released) return
        stop()
        released = true
        recorder.unregisterAudioRecordingCallback(recordingCallback)
        recorder.release()
    }

    companion object {
        fun create(
            context: Context,
            onClientSilencedChanged: (Boolean) -> Unit = {},
        ): PcmCaptureSourceCreateResult {
            if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                return PcmCaptureSourceCreateResult.Failure("microphone_permission_denied")
            }
            val minimumBufferBytes =
                AudioRecord.getMinBufferSize(
                    AndroidAacSegmentEncoder.SAMPLE_RATE_HZ,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                )
            if (minimumBufferBytes <= 0) {
                return PcmCaptureSourceCreateResult.Failure("recording_input_configuration_unsupported")
            }
            var recorder: AudioRecord? = null
            return try {
                recorder = buildRecorder(max(minimumBufferBytes, MINIMUM_INTERNAL_BUFFER_BYTES))
                if (recorder.state != AudioRecord.STATE_INITIALIZED) {
                    recorder.release()
                    PcmCaptureSourceCreateResult.Failure("recording_input_uninitialized")
                } else {
                    PcmCaptureSourceCreateResult.Success(
                        AndroidAudioRecordSource(
                            recorder = recorder,
                            callbackExecutor = context.applicationContext.mainExecutor,
                            onClientSilencedChanged = onClientSilencedChanged,
                        ),
                    )
                }
            } catch (_: SecurityException) {
                recorder?.release()
                PcmCaptureSourceCreateResult.Failure("microphone_permission_denied")
            } catch (_: IllegalArgumentException) {
                recorder?.release()
                PcmCaptureSourceCreateResult.Failure("recording_input_configuration_failed")
            } catch (_: UnsupportedOperationException) {
                recorder?.release()
                PcmCaptureSourceCreateResult.Failure("recording_input_configuration_unsupported")
            }
        }

        @SuppressLint("MissingPermission")
        private fun buildRecorder(bufferSizeBytes: Int): AudioRecord =
            AudioRecord.Builder()
                .setAudioSource(MediaRecorder.AudioSource.MIC)
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(AndroidAacSegmentEncoder.SAMPLE_RATE_HZ)
                        .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                        .build(),
                ).setBufferSizeInBytes(bufferSizeBytes)
                .build()

        private const val MINIMUM_INTERNAL_BUFFER_BYTES = RecordingCapturePipeline.PCM_READ_BYTES * 4
    }
}
