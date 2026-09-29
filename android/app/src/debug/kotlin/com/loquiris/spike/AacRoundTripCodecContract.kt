package com.loquiris.spike

internal fun selectCodecSpecificData(
    formatCodecSpecificData: List<ByteArray>,
    configBufferCodecSpecificData: List<ByteArray>,
): List<ByteArray> =
    (formatCodecSpecificData.ifEmpty { configBufferCodecSpecificData })
        .map(ByteArray::copyOf)

internal fun timestampsAreStrictlyIncreasing(timestampsMicroseconds: List<Long>): Boolean =
    timestampsMicroseconds.zipWithNext().all { (previous, next) -> next > previous }

internal fun mediaEndTimestampMicroseconds(
    totalSamples: Int,
    sampleRateHz: Int,
): Long {
    require(totalSamples >= 0) { "totalSamples must not be negative" }
    require(sampleRateHz > 0) { "sampleRateHz must be positive" }
    return totalSamples.toLong() * 1_000_000L / sampleRateHz
}

internal fun finishCodecLifecycle(
    primaryFailure: Throwable?,
    stop: () -> Unit,
    release: () -> Unit,
): Throwable? {
    var failure = primaryFailure
    fun record(cleanupFailure: Throwable) {
        if (failure == null) {
            failure = cleanupFailure
        } else if (failure !== cleanupFailure) {
            checkNotNull(failure).addSuppressed(cleanupFailure)
        }
    }

    try {
        stop()
    } catch (cleanupFailure: Throwable) {
        record(cleanupFailure)
    }
    try {
        release()
    } catch (cleanupFailure: Throwable) {
        record(cleanupFailure)
    }
    return failure
}
