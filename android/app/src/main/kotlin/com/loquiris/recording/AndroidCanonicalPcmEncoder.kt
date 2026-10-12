package com.loquiris.recording

class AndroidCanonicalPcmEncoder(
    private val delegate: AndroidAacSegmentEncoder,
) : CanonicalPcmEncoder {
    override fun prepare(): Boolean =
        delegate.prepare() is RecordingEncoderCommandResult.Success

    override fun appendPcm(frame: PcmCaptureFrame): Boolean =
        delegate.appendPcm(frame.copyBytes()) is RecordingEncoderCommandResult.Success

    override fun finish(): Boolean = delegate.finish() is RecordingEncoderCommandResult.Success

    override fun abort() = delegate.abort()

    override fun bytesWritten(): Long = delegate.snapshot().bytesWritten
}
