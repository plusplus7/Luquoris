package com.loquiris.transcription

import com.loquiris.recording.CanonicalPcmEncoder
import com.loquiris.recording.PcmCaptureSource
import com.loquiris.recording.RecordingCapturePipeline

/** A throwing native creator may own an object it never returned. */
internal class StreamingProbeCaptureFactory(
    private val source: () -> PcmCaptureSource,
    private val encoder: () -> CanonicalPcmEncoder,
) {
    var releaseUncertain = false
        private set
    private var attempted = false
    fun create(): RecordingCapturePipeline {
        check(!attempted)
        attempted = true
        var ownedSource: PcmCaptureSource? = null
        var ownedEncoder: CanonicalPcmEncoder? = null
        // Set BEFORE every native creator, including one that throws before
        // returning an object. A later error cannot erase that uncertainty.
        releaseUncertain = true
        try {
            ownedSource = source()
            ownedEncoder = encoder()
            val pipeline = RecordingCapturePipeline(ownedSource, ownedEncoder)
            ownedSource = null
            ownedEncoder = null
            releaseUncertain = false
            return pipeline
        } catch (problem: Throwable) {
            try { ownedSource?.release() } catch (cleanup: Throwable) { problem.addSuppressed(cleanup) }
            try { ownedEncoder?.abort() } catch (cleanup: Throwable) { problem.addSuppressed(cleanup) }
            throw problem
        }
    }
}
