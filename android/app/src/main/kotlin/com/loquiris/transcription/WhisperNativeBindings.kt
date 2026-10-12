package com.loquiris.transcription

internal object WhisperNativeBindings {
    init {
        System.loadLibrary("loquiris_whisper")
    }

    external fun nativeCreateContext(modelPath: String): Long

    external fun nativeFreeContext(handle: Long)

    external fun nativeCreateRun(): Long

    external fun nativeCancelRun(handle: Long)

    external fun nativeFreeRun(handle: Long)

    external fun nativeTranscribePcm(
        contextHandle: Long,
        runHandle: Long,
        pcm: ShortArray,
        windowStartMilliseconds: Long,
        languageHint: String,
    ): Long

    external fun nativeSegmentCount(resultHandle: Long): Int

    external fun nativeSegmentStartMilliseconds(
        resultHandle: Long,
        index: Int,
    ): Long

    external fun nativeSegmentEndMilliseconds(
        resultHandle: Long,
        index: Int,
    ): Long

    external fun nativeSegmentText(
        resultHandle: Long,
        index: Int,
    ): String

    external fun nativeFreeResult(handle: Long)

    external fun nativeEngineVersion(): String

    external fun nativeLastErrorCode(): String?

    external fun nativeActiveHandleCounts(): LongArray
}

object JniWhisperNativeApi : WhisperNativeApi {
    override fun createContext(modelPath: String): Long = WhisperNativeBindings.nativeCreateContext(modelPath)

    override fun freeContext(handle: Long) = WhisperNativeBindings.nativeFreeContext(handle)

    override fun createRun(): Long = WhisperNativeBindings.nativeCreateRun()

    override fun cancelRun(handle: Long) = WhisperNativeBindings.nativeCancelRun(handle)

    override fun freeRun(handle: Long) = WhisperNativeBindings.nativeFreeRun(handle)

    override fun transcribePcm(
        contextHandle: Long,
        runHandle: Long,
        pcm: ShortArray,
        windowStartMilliseconds: Long,
        languageHint: TranscriptionLanguageHint,
    ): Long =
        WhisperNativeBindings.nativeTranscribePcm(
            contextHandle,
            runHandle,
            pcm,
            windowStartMilliseconds,
            languageHint.name,
        )

    override fun segmentCount(resultHandle: Long): Int = WhisperNativeBindings.nativeSegmentCount(resultHandle)

    override fun segmentStartMilliseconds(
        resultHandle: Long,
        index: Int,
    ): Long = WhisperNativeBindings.nativeSegmentStartMilliseconds(resultHandle, index)

    override fun segmentEndMilliseconds(
        resultHandle: Long,
        index: Int,
    ): Long = WhisperNativeBindings.nativeSegmentEndMilliseconds(resultHandle, index)

    override fun segmentText(
        resultHandle: Long,
        index: Int,
    ): String = WhisperNativeBindings.nativeSegmentText(resultHandle, index)

    override fun freeResult(handle: Long) = WhisperNativeBindings.nativeFreeResult(handle)

    override fun engineVersion(): String = WhisperNativeBindings.nativeEngineVersion()

    override fun lastErrorCode(): String? = WhisperNativeBindings.nativeLastErrorCode()

    override fun activeHandleCounts(): NativeHandleCounts {
        val counts = WhisperNativeBindings.nativeActiveHandleCounts()
        return NativeHandleCounts(counts[0], counts[1], counts[2])
    }
}
