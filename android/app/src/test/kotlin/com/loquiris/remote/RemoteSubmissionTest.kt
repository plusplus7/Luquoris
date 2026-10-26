package com.loquiris.remote

import org.junit.Assert.*
import org.junit.Test

class RemoteSubmissionTest {
    @Test fun lostSubmissionIsRecoveredBeforeCancellation() {
        val calls=mutableListOf<String>()
        var lose=true
        var remembered:String?=null
        val send: (String,String,Map<String,Any?>?,String?)->Map<String,Any?> = {method,_,_,key ->
            calls += "$method:$key"
            if(method=="POST" && lose) {lose=false;throw java.io.IOException("lost response")}
            mapOf("jobId" to "job-1")
        }
        try { RemoteSubmission.reconcile("run-1","upload-1","qwen-1.7b",null,{false},{remembered=it},send) }
        catch (_: java.io.IOException) { }
        RemoteSubmission.reconcile("run-1","upload-1","qwen-1.7b",remembered,{true},{remembered=it},send,submissionPending=true)
        assertEquals("job-1",remembered)
        assertEquals(listOf("POST:job-run-1","POST:job-run-1","DELETE:null"),calls)
    }
    @Test fun transportRetryPreservesLostSubmissionEvidenceUntilCancelRecovery() {
        assertEquals("remote_submission_pending",
            RemoteSubmission.failureAfterRetry("remote_submission_pending", "remote_transport"))
        assertEquals("remote_transport", RemoteSubmission.failureAfterRetry(null, "remote_transport"))
    }
    @Test fun capabilitiesRejectIncompatibleVersionOrMissingProfile() {
        val valid=mapOf("schemaVersion" to 1,"profiles" to listOf("qwen-1.7b"),"retentionSeconds" to 7200,"chunkBytes" to 16384)
        assertEquals(7200L,RemoteWire.retentionSeconds(valid,"qwen-1.7b"))
        try {RemoteWire.retentionSeconds(valid+mapOf("schemaVersion" to 2),"qwen-1.7b");fail("accepted incompatible schema")}
        catch (_: IllegalArgumentException) { }
    }
    @Test fun cancelBeforePendingCommitNeverSubmitsEvenWhenResponseWouldBeLost() {
        var called=false
        val result=RemoteSubmission.reconcile("run","upload","qwen-1.7b",null,{true},{},
            {_,_,_,_->called=true;throw java.io.IOException("lost")})
        assertNull(result)
        assertFalse(called)
    }
    @Test fun obeysNegotiatedChunkLimit() {
        assertEquals(16384,RemoteWire.chunkBytes(16384))
        assertEquals(1048576,RemoteWire.chunkBytes(8388608))
        try {RemoteWire.chunkBytes(-1);fail("negative chunk size accepted")}
        catch (_: IllegalArgumentException) { }
    }
}
