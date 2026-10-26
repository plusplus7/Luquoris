package com.loquiris.remote

import org.junit.Assert.*
import org.junit.Test

class RemoteWireTest {
    @Test fun rejectsUnsafeOrCleartextEndpoint() {
        assertFalse(RemoteWire.validEndpoint("http://server.example"))
        assertFalse(RemoteWire.validEndpoint("https://user:secret@server.example"))
        assertFalse(RemoteWire.validEndpoint("https://server.example?token=secret"))
        assertTrue(RemoteWire.validEndpoint("https://server.example"))
    }
    @Test fun canonicalEncodingMatchesProtocolAsciiRules() {
        assertEquals("{\"a\":\"\\u4f60\\u597d\",\"z\":[1,true,null]}",
            RemoteWire.canonical(mapOf("z" to listOf(1,true,null), "a" to "你好")))
    }
    @Test fun resultCannotChangeMeetingOrMediaGeometry() {
        val result = mapOf<String,Any?>("schemaVersion" to 1,"jobId" to "job-1",
            "meetingId" to "m", "runId" to "r", "audioManifestDigest" to "a".repeat(64),
            "durationMs" to 1000,"provenance" to mapOf("modelRevision" to "b".repeat(40),"runtime" to "test"),
            "segments" to listOf(mapOf("startMs" to 0,"endMs" to 1000,"text" to "hello")))
        assertTrue(RemoteWire.validResult(result,"m","r","job-1","a".repeat(64),1000))
        assertFalse(RemoteWire.validResult(result,"other","r","job-1","a".repeat(64),1000))
        assertFalse(RemoteWire.validResult(result + ("schemaVersion" to 2),"m","r","job-1","a".repeat(64),1000))
    }
}
