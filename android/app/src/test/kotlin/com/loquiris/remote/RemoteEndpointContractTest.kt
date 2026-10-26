package com.loquiris.remote

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Test

class RemoteEndpointContractTest {
    @Test fun sharedPrivateLanOrigins() {
        val source = File("../../contracts/remote_transcription/v1/endpoints.tsv")
        source.readLines().filter { it.isNotEmpty() && !it.startsWith("#") }.forEach { line ->
            val fields = line.split('\t')
            assertEquals(fields[1], fields[0] == "1", RemoteWire.validEndpoint(fields[1]))
        }
    }
}
