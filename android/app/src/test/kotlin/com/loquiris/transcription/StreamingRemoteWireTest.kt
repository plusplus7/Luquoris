package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame
import org.junit.Assert.*
import org.junit.Test

class StreamingRemoteWireTest {
    private val owner = StreamingRemoteIdentity("run", "binding-1")

    @Test fun finishCommandIsStrictAndRoundTrips() {
        val wire = mapOf<String, Any>("v" to 1, "type" to "finish", "run" to "run",
            "epoch" to "binding-1", "request" to 7L)
        val decoded = StreamingRemoteWire.decodeRemoteCommand(wire)
        assertNotNull("finish is an independently acknowledged operation", decoded)
        assertEquals(StreamingRemoteCommand.Finish(owner, 7), decoded)
        assertEquals(wire, StreamingRemoteWire.encodeRemoteCommand(StreamingRemoteCommand.Finish(owner, 7)))
        for (invalid in listOf(wire - "request", wire + ("request" to -1L),
            wire + ("request" to 7), wire + ("pcm" to ByteArray(2)))) {
            assertNull(StreamingRemoteWire.decodeRemoteCommand(invalid))
        }
    }

    @Test fun pcmRoundTripPreservesCanonicalIdentityAndCopiesPayload() {
        val frame = PcmCaptureFrame(7, byteArrayOf(1, 2, 3, 4), 100, 3)
        val wire = StreamingRemoteWire.encodeRemoteCommand(StreamingRemoteCommand.Pcm(owner, 19, frame))
        assertEquals("pcm", wire["type"])
        val decoded = StreamingRemoteWire.decodeRemoteCommand(wire) as? StreamingRemoteCommand.Pcm
        assertNotNull("valid PCM must decode", decoded)
        decoded!!
        (wire["pcm"] as ByteArray)[0] = 99
        assertArrayEquals(byteArrayOf(1, 2, 3, 4), decoded.frame.copyBytes())
        assertArrayEquals(byteArrayOf(1, 2, 3, 4), frame.copyBytes())
        assertEquals(19L, decoded.requestId)
        assertEquals(7L, decoded.frame.sequence)
        assertEquals(100L, decoded.frame.canonicalStartSample)
        assertEquals(102L, decoded.frame.canonicalEndSampleExclusive)
        assertEquals(3L, decoded.frame.captureEpoch)
        assertEquals(owner, decoded.owner)
        for (command in listOf(StreamingRemoteCommand.Open(owner, "a".repeat(64)), StreamingRemoteCommand.Close(owner))) {
            assertEquals(command, StreamingRemoteWire.decodeRemoteCommand(StreamingRemoteWire.encodeRemoteCommand(command)))
        }
    }

    @Test fun allReplyShapesRoundTripWithoutInferringTimestamps() {
        val replies = listOf(
            StreamingRemoteReply.Ready(owner), StreamingRemoteReply.Text(owner, 0, "你好 \"English\"\n", true),
            StreamingRemoteReply.Released(owner), StreamingRemoteReply.Rejected(owner, StreamingStopCause.ENGINE),
            *StreamingStopCause.entries.map { StreamingRemoteReply.Failure(owner, it) }.toTypedArray(),
        )
        for (reply in replies) {
            val wire = StreamingRemoteWire.encodeRemoteReply(reply)
            assertNotNull("valid reply must decode", StreamingRemoteWire.decodeRemoteReply(wire))
            assertEquals(reply, StreamingRemoteWire.decodeRemoteReply(wire))
            assertFalse(wire.containsKey("timestamp")) // Paraformer supplies no inferred wall-time coordinate.
        }
    }

    @Test fun malformedWireDataCannotAllocateOrReachNativeInference() {
        val valid = mapOf<String, Any>(
            "v" to 1, "type" to "pcm", "run" to "run", "epoch" to "binding-1", "request" to 1L,
            "sequence" to 3L, "start" to 0L, "captureEpoch" to 0L, "pcm" to ByteArray(640),
        )
        assertNotNull("hand-authored PCM fixture must decode", StreamingRemoteWire.decodeRemoteCommand(valid))
        val malformed = listOf(
            valid + ("v" to 2), valid + ("v" to 1L), valid + ("type" to "unknown"), valid + ("run" to ""),
            valid + ("epoch" to "x".repeat(257)), valid + ("request" to -1L), valid + ("request" to 1),
            valid + ("sequence" to -1L), valid + ("start" to Long.MAX_VALUE), valid + ("captureEpoch" to -1L),
            valid + ("pcm" to ByteArray(32002)), valid + ("pcm" to ByteArray(3)), valid + ("pcm" to ByteArray(0)),
            valid + ("pcm" to "not bytes"), valid + ("unrecognized" to true), valid - "start",
        )
        for (wire in malformed) assertNull(StreamingRemoteWire.decodeRemoteCommand(wire))
        val text = mapOf<String, Any>("v" to 1, "type" to "text", "run" to "run", "epoch" to "binding-1", "request" to 1L, "text" to "ok", "endpoint" to true)
        assertEquals(StreamingRemoteReply.Text(owner, 1, "ok", true), StreamingRemoteWire.decodeRemoteReply(text))
        for (wire in listOf(text + ("request" to -1L), text + ("endpoint" to 1), text + ("text" to "x".repeat(16001)), text + ("extra" to false))) {
            assertNull(StreamingRemoteWire.decodeRemoteReply(wire))
        }
        assertNull(StreamingRemoteWire.decodeRemoteCommand(mapOf("v" to 1, "type" to "open", "run" to "run", "epoch" to "binding-1", "bundle" to "mutable-path")))
        assertNull(StreamingRemoteWire.decodeRemoteReply(mapOf("v" to 1, "type" to "failure", "run" to "run", "epoch" to "binding-1", "cause" to "unknown")))
    }
}
