package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame

/** An already-created native recognizer session; callers own its complete lifetime. */
interface StreamingNativeSession : AutoCloseable {
    fun accept(samples: FloatArray): StreamingRemoteResult.Text
    /** Flush the current utterance and prepare a fresh stream on the same recognizer. */
    fun finishUtterance(): StreamingRemoteResult.Text
}

/** Canonical PCM adapter; installed only behind the remote-process owner. */
class StreamingPcmKernel(private val native: StreamingNativeSession) : StreamingRemoteKernel {
    private var nextSample: Long? = null
    private var captureEpoch: Long? = null
    private var boundaryFinished = false
    private var inferenceFailure: Throwable? = null
    private var closeRequested = false
    private var closeFailure: Throwable? = null

    @Synchronized
    override fun finishUtterance(): StreamingRemoteResult.Text {
        check(!closeRequested) { "streaming_native_session_closed" }
        inferenceFailure?.let { throw it }
        if (nextSample == null || boundaryFinished) return StreamingRemoteResult.Text("", true)
        val result = try { native.finishUtterance() } catch (failure: Throwable) {
            inferenceFailure = failure
            throw failure
        }
        boundaryFinished = true
        return result
    }

    @Synchronized
    override fun decode(frame: PcmCaptureFrame): StreamingRemoteResult.Text {
        check(!closeRequested) { "streaming_native_session_closed" }
        inferenceFailure?.let { throw it }
        val start = requireNotNull(frame.canonicalStartSample) { "canonical_pcm_required" }
        val end = requireNotNull(frame.canonicalEndSampleExclusive)
        require(end - start in 1..16000L) { "canonical_pcm_size_invalid" }
        require(nextSample == null || if (boundaryFinished) start >= requireNotNull(nextSample)
            else nextSample == start) { "canonical_pcm_discontinuity" }
        require(captureEpoch == null || if (boundaryFinished) frame.captureEpoch >= requireNotNull(captureEpoch)
            else captureEpoch == frame.captureEpoch) { "canonical_pcm_epoch_changed" }
        val bytes = frame.copyBytes()
        val samples = FloatArray(bytes.size / 2) { index ->
            val unsigned = (bytes[index * 2].toInt() and 255) or
                ((bytes[index * 2 + 1].toInt() and 255) shl 8)
            unsigned.toShort().toFloat() / 32768f
        }
        val result = try { native.accept(samples) } catch (failure: Throwable) {
            // The native stream may already contain these samples. Never retry
            // into that recognizer after an uncertain partial accept/decode.
            inferenceFailure = failure
            throw failure
        }
        nextSample = end
        captureEpoch = frame.captureEpoch
        boundaryFinished = false
        return result
    }

    @Synchronized
    override fun close() {
        if (closeRequested) {
            closeFailure?.let { throw it }
            return
        }
        closeRequested = true
        try { native.close() } catch (failure: Throwable) {
            // Never turn uncertain native release into a successful retry, nor
            // run destroy twice after a close that may have partially succeeded.
            closeFailure = failure
            throw failure
        }
    }
}
