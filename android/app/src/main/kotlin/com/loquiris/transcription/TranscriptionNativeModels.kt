package com.loquiris.transcription

import java.io.File
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicBoolean

data class AuthoritativeAudioSegment(
    val index: Int,
    val file: File,
    val committedBytes: Long,
    val startSample: Long,
    val committedSamples: Long,
)

sealed interface AuthoritativeAudioResolution {
    data class Ready(
        val segments: List<AuthoritativeAudioSegment>,
        val totalSamples: Long,
        val sampleRateHz: Int,
        val codecSpecificData: List<ByteArray>,
    ) : AuthoritativeAudioResolution

    data class Partial(
        val segments: List<AuthoritativeAudioSegment>,
        val totalSamples: Long,
        val sampleRateHz: Int,
        val codecSpecificData: List<ByteArray>,
        val code: String,
    ) : AuthoritativeAudioResolution

    data class Failure(
        val code: String,
    ) : AuthoritativeAudioResolution
}

fun interface AuthoritativeAudioProvider {
    fun resolve(meetingId: String): AuthoritativeAudioResolution
}

data class ModelArtifactSpec(
    val id: String,
    val assetPath: String,
    val bytes: Long,
    val sha256: String,
)

sealed interface ModelMaterializationResult {
    data class Ready(
        val file: File,
    ) : ModelMaterializationResult

    data class Failure(
        val code: String,
    ) : ModelMaterializationResult
}

fun interface WhisperModelProvider {
    fun materialize(): ModelMaterializationResult
}

data class PcmWindow(
    val startSample: Long,
    val samples: ShortArray,
)

sealed interface AudioDecodeResult {
    data object Completed : AudioDecodeResult

    data object Cancelled : AudioDecodeResult

    data class Failure(
        val code: String,
    ) : AudioDecodeResult
}

fun interface AacPcmDecoder {
    fun decode(
        audio: AuthoritativeAudioResolution.Ready,
        onWindow: (PcmWindow) -> Boolean,
    ): AudioDecodeResult
}

data class NativeHandleCounts(
    val contexts: Long,
    val runs: Long,
    val results: Long,
)

interface WhisperNativeApi {
    fun createContext(modelPath: String): Long

    fun freeContext(handle: Long)

    fun createRun(): Long

    fun cancelRun(handle: Long)

    fun freeRun(handle: Long)

    fun transcribePcm(
        contextHandle: Long,
        runHandle: Long,
        pcm: ShortArray,
        windowStartMilliseconds: Long,
        languageHint: TranscriptionLanguageHint = TranscriptionLanguageHint.mixed,
    ): Long

    fun segmentCount(resultHandle: Long): Int

    fun segmentStartMilliseconds(
        resultHandle: Long,
        index: Int,
    ): Long

    fun segmentEndMilliseconds(
        resultHandle: Long,
        index: Int,
    ): Long

    fun segmentText(
        resultHandle: Long,
        index: Int,
    ): String

    fun freeResult(handle: Long)

    fun engineVersion(): String

    fun lastErrorCode(): String?

    fun activeHandleCounts(): NativeHandleCounts = NativeHandleCounts(-1, -1, -1)
}

data class TranscriptionSegment(
    val id: String,
    val startMilliseconds: Long,
    val endMilliseconds: Long,
    val rawText: String,
    val displayText: String,
)

sealed interface PostSessionTranscriptionResult {
    data class Completed(
        val engineVersion: String,
        val segments: List<TranscriptionSegment>,
        val warningCode: String? = null,
    ) : PostSessionTranscriptionResult

    data object Cancelled : PostSessionTranscriptionResult

    data class Failure(
        val code: String,
    ) : PostSessionTranscriptionResult
}

class TranscriptionCancellation {
    private val cancelled = AtomicBoolean(false)
    private val listeners = CopyOnWriteArrayList<() -> Unit>()

    fun isCancelled(): Boolean = cancelled.get()

    fun cancel() {
        if (cancelled.compareAndSet(false, true)) {
            listeners.forEach { listener -> listener() }
            listeners.clear()
        }
    }

    fun invokeOnCancel(listener: () -> Unit): AutoCloseable {
        if (cancelled.get()) {
            listener()
            return AutoCloseable {}
        }
        listeners += listener
        if (cancelled.get() && listeners.remove(listener)) listener()
        return AutoCloseable { listeners.remove(listener) }
    }
}
