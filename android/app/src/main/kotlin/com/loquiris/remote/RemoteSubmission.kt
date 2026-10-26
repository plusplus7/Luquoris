package com.loquiris.remote

/** Recover idempotent submission even after cancellation, then remove the remote job. */
object RemoteSubmission {
    fun failureAfterRetry(previous: String?, failure: String): String =
        if(previous=="remote_submission_pending") previous else failure
    fun reconcile(run: String, upload: String, profile: String, knownJob: String?,
                  cancelled: () -> Boolean, remember: (String) -> Unit,
                  send: (String,String,Map<String,Any?>?,String?) -> Map<String,Any?>, submissionPending: Boolean=false): String? {
        if(cancelled() && knownJob==null && !submissionPending) return null
        val job=knownJob ?: (send("POST","/v1/transcriptions",mapOf("schemaVersion" to 1,
            "uploadId" to upload,"profileId" to profile),"job-$run")["jobId"] as? String
            ?: throw RemoteRequestFailure("remote_identity"))
        if(!job.matches(Regex("[A-Za-z0-9_-]{1,128}"))) throw RemoteRequestFailure("remote_identity")
        remember(job)
        if(cancelled()) {send("DELETE","/v1/transcriptions/$job",null,null);return null}
        return job
    }
}
