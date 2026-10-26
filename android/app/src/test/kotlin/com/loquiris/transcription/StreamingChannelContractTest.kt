package com.loquiris.transcription

import org.junit.Assert.*
import org.junit.Test

class StreamingChannelContractTest {
    private val owner = StreamingPlatformOwner("meeting", "live", 7)
    private val identity = StreamingRemoteIdentity("live", "fresh-binding")
    private val header = mapOf<String, Any>("v" to 1, "meetingId" to "meeting", "runId" to "live", "epoch" to 7L)

    @Test fun decodesPinnedRequestAndCloseReasonWithoutPathsOrPcm() {
        val request = header + mapOf("modelId" to "debug-zipformer", "bundleSha256" to "a".repeat(64), "parameterVersion" to 1)
        assertEquals(StreamingPlatformStart(owner, "debug-zipformer", "a".repeat(64), 1), StreamingChannelContract.decodeStart(request))
        for ((reason, value) in mapOf("stopped" to StreamingPlatformCloseReason.STOPPED,
            "cancelled" to StreamingPlatformCloseReason.CANCELLED, "replaced" to StreamingPlatformCloseReason.REPLACED)) {
            assertEquals(StreamingPlatformClose(owner, value), StreamingChannelContract.decodeClose(header + ("reason" to reason)))
        }
        for (patch in listOf(mapOf("v" to 2), mapOf("epoch" to -1), mapOf("epoch" to 7.0),
            mapOf("modelId" to "../weights"), mapOf("bundleSha256" to "A".repeat(64)),
            mapOf("parameterVersion" to 2), mapOf("path" to "/private"), mapOf("pcm" to byteArrayOf(1, 2)))) {
            assertNull(StreamingChannelContract.decodeStart(request + patch))
        }
        assertNull(StreamingChannelContract.decodeClose(header + ("reason" to "pause")))
        assertNull(StreamingChannelContract.decodeClose(header + mapOf("reason" to "stopped", "path" to "secret")))
    }

    @Test fun sendsUnmodifiedRawTextAndExactCanonicalSamples() {
        val event = StreamingCaptureText(identity, 0, "utterance-1", 3200, 6400, 2, "  中文 API\n", false)
        assertEquals(header + mapOf("type" to "text", "sequence" to 0L, "utteranceId" to "utterance-1",
            "startSample" to 3200L, "endSampleExclusive" to 6400L, "captureEpoch" to 2L,
            "rawText" to "  中文 API\n", "finalized" to false), StreamingChannelContract.encodeCapture(owner, identity, event))
        assertNull(StreamingChannelContract.encodeCapture(owner, identity, event.copy(owner = identity.copy(epoch = "old"))))
        assertNull(StreamingChannelContract.encodeCapture(owner, identity, event.copy(startSample = 6400)))
        assertNull(StreamingChannelContract.encodeCapture(owner, identity, event.copy(rawText = "x".repeat(16001))))
        assertNull(StreamingChannelContract.encodeCapture(owner, identity, event.copy(endSampleExclusive = Long.MAX_VALUE)))
        assertNull(StreamingChannelContract.encodeCapture(owner, identity, event.copy(sequence = Long.MAX_VALUE)))
        assertNull(StreamingChannelContract.encodeCapture(owner, identity, event.copy(sequence = Long.MAX_VALUE - 1)))
    }

    @Test fun gapHasNoTextAndKeepsZeroLengthEpochBoundary() {
        val event = StreamingCaptureGap(identity, 1, 6400, 6400, 3, StreamingBoundaryReason.PAUSE)
        assertEquals(header + mapOf("type" to "gap", "sequence" to 1L,
            "startSample" to 6400L, "endSampleExclusive" to 6400L, "captureEpoch" to 3L,
            "reason" to "pause"), StreamingChannelContract.encodeCapture(owner, identity, event))
        assertNull(StreamingChannelContract.encodeCapture(owner, identity, event.copy(reason = StreamingBoundaryReason.STOP)))
        assertNull(StreamingChannelContract.encodeCapture(owner, identity, event.copy(captureEpoch = -1)))
    }
}
