package com.loquiris.remote

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.loquiris.recording.AppPrivateRecordingStorage
import com.loquiris.transcription.AuthoritativeAudioResolver
import com.loquiris.transcription.AuthoritativeAudioResolution
import org.json.JSONObject
import java.io.File
import java.io.RandomAccessFile
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** A disposable OS wake-up over the shared durable remote task ledger. */
class RemoteTranscriptionJobService: JobService() {
    private val stopped = AtomicBoolean()
    override fun onStartJob(params: JobParameters): Boolean {
        stopped.set(false)
        executor.execute {
            var pending = false
            try {
                RemoteRuntime.lock(this).use { lease ->
                    val path = getSharedPreferences("remote-runtime", MODE_PRIVATE).getString("database", null)
                    if (path != null && File(path).isFile) {
                        RemoteSqlite(path).use { db ->
                            db.execSQL("PRAGMA foreign_keys=ON")
                            val runner = NativeRemoteRepository(this, db) { stopped.get() || RemoteRuntime.transfers.paused }
                            pending = runner.synchronize()
                        }
                    }
                }
            } catch (_: Exception) { pending = true }
            Handler(Looper.getMainLooper()).post { jobFinished(params, pending && !stopped.get()) }
        }
        return true
    }
    override fun onStopJob(params: JobParameters): Boolean { stopped.set(true); return true }
    companion object {
        private val executor = Executors.newSingleThreadExecutor()
        fun schedule(context: Context) {
            val scheduler = context.getSystemService(JobScheduler::class.java)
            scheduler.schedule(JobInfo.Builder(7301, ComponentName(context, RemoteTranscriptionJobService::class.java))
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY).setPersisted(true)
                .setBackoffCriteria(10000, JobInfo.BACKOFF_POLICY_EXPONENTIAL).build())
        }
    }
}

/** One native repository owns the background side of the shared SQLite state machine. */
class NativeRemoteRepository(private val context: Context, private val db: RemoteSqlite,
                             private val transportFactory: ((Map<String,String?>, ()->Boolean)->RemoteTransport)?=null,
                             private val stopped: () -> Boolean) {
    private val terminal = setOf("completed", "failed", "expired", "cancelled", "restored", "waitingSetup")
    private fun tasks(): List<Map<String,String?>> = db.rawQuery(
        "SELECT * FROM remote_transcription_tasks WHERE is_deleted=0 ORDER BY created_at", null).use { c ->
        buildList { while(c.moveToNext()) add(c.columnNames.associateWith { name ->
            val index=c.getColumnIndexOrThrow(name); if(c.isNull(index)) null else c.getString(index)
        }) }
    }
    private fun update(id: String, values: Map<String,Any?>, allowCancelled: Boolean = false) {
        val content=ContentValues()
        for ((key,value) in values) when(value) {
            null -> content.putNull(key)
            is Long -> content.put(key,value)
            is Int -> content.put(key,value)
            else -> content.put(key,value.toString())
        }
        content.put("updated_at",System.currentTimeMillis())
        content.put("updated_at_utc_ms",System.currentTimeMillis())
        val condition=if(allowCancelled) "id=? AND is_deleted=0" else "id=? AND state NOT IN ('cancelled','restored') AND is_deleted=0"
        db.update("remote_transcription_tasks",content,condition,arrayOf(id))
    }
    private fun cancelled(id: String): Boolean {
        if(stopped()) return true
        return db.rawQuery("SELECT state,is_deleted FROM remote_transcription_tasks WHERE id=?",arrayOf(id)).use {
            !it.moveToFirst() || it.getInt(1)!=0 || it.getString(0) in setOf("cancelled","restored")
        }
    }
    fun synchronize(): Boolean {
        for(task in tasks()) {
            if(stopped()) break
            val id=task.getValue("id")!!
            val state=task.getValue("state")!!
            if(state in terminal) {
                if(state=="cancelled" && (task["job_id"]!=null || task["failure_code"]=="remote_submission_pending") && task["failure_code"]!="remote_cancel_ack") {
                    try {
                        val control=client(task) { stopped() }
                        RemoteSubmission.reconcile(id,safeId(task["upload_id"]),task.getValue("profile_id")!!,
                            task["job_id"],{true},{ jid -> update(id,mapOf("job_id" to jid),true) },
                            { method,route,body,key -> control.call(method,route,body?.let { RemoteWire.canonical(it).toByteArray() },key) },submissionPending=true)
                        update(id,mapOf("failure_code" to "remote_cancel_ack"),true)
                    } catch (_: Exception) { return true }
                }
                continue
            }
            if((task["retry_at_utc_ms"]?.toLongOrNull() ?: 0)>System.currentTimeMillis()) continue
            try { process(task) }
            catch(error: Exception) {
                if(stopped() || RemoteRuntime.transfers.paused) break
                if(cancelled(id)) continue
                val failure=error as? RemoteRequestFailure
                val retryable = failure?.retryable == true || error is java.io.IOException
                val attempts=(task["attempts"]?.toIntOrNull() ?: 0)+1
                val retry=retryable && attempts<8
                val previous=db.rawQuery("SELECT failure_code FROM remote_transcription_tasks WHERE id=?",arrayOf(id)).use {
                    if(it.moveToFirst() && !it.isNull(0)) it.getString(0) else null
                }
                update(id,mapOf("state" to if(retry) "waitingNetwork" else "failed",
                    "failure_code" to RemoteSubmission.failureAfterRetry(previous, failure?.code ?: if(error is java.io.IOException) "remote_transport" else "remote_invalid"),
                    "attempts" to attempts,"retry_at_utc_ms" to (System.currentTimeMillis()+minOf(300000L,10000L*(1L shl minOf(attempts,5))))))
            }
        }
        return tasks().any { it["state"] !in terminal || (it["state"]=="cancelled" && (it["job_id"]!=null || it["failure_code"]=="remote_submission_pending") && it["failure_code"]!="remote_cancel_ack") }
    }
    private fun client(task: Map<String,String?>, stop: () -> Boolean): RemoteTransport {
        transportFactory?.let { return it(task,stop) }
        val endpoint=task.getValue("endpoint")!!
        val token=try { RemoteCredentials(context).token(task.getValue("credential_ref")!!,endpoint) }
        catch (_: Exception) { throw RemoteRequestFailure("remote_credentials_missing") }
        return RemoteHttp(endpoint,token,stop)
    }
    private fun process(task: Map<String,String?>) {
        val id=task.getValue("id")!!
        val meeting=task.getValue("meeting_id")!!
        val finalized = db.rawQuery("SELECT lifecycle,is_deleted FROM meetings WHERE id=?",arrayOf(meeting)).use {
            it.moveToFirst() && it.getString(0)=="finalized" && it.getInt(1)==0
        }
        if(!finalized) return
        if(task["job_id"]!=null && task["request_json"]!=null) {
            val frozen=RemoteJson.decode(JSONObject(task.getValue("request_json")!!)) as Map<String,Any?>
            val declared=frozen["files"] as List<Map<String,Any?>>
            poll(task,id,meeting,safeId(task["job_id"]),task.getValue("manifest_digest")!!,
                declared.sumOf { (it.getValue("durationMs") as Number).toLong() })
            return
        }
        val input=AuthoritativeAudioResolver(File(context.filesDir,"recordings"),
            { AppPrivateRecordingStorage.sessionDirectory(context,it) },true).resolve(meeting)
        if(input !is AuthoritativeAudioResolution.Ready) throw RemoteRequestFailure("remote_audio_unavailable")
        val files=input.segments.map { segment ->
            val start=segment.startSample*1000/16000
            val end=(segment.startSample+segment.committedSamples)*1000/16000
            mapOf("fileId" to "segment-${segment.index}","sizeBytes" to segment.committedBytes,
                "sha256" to (segment.verifiedSha256 ?: throw RemoteRequestFailure("remote_audio_unverified")),
                "startMs" to start,"durationMs" to end-start)
        }
        val manifest=mapOf("schemaVersion" to 1,"meetingId" to meeting,"runId" to id,"files" to files)
        val digest=RemoteWire.digest(manifest)
        if(task["manifest_digest"]!=null && task["manifest_digest"]!=digest) throw RemoteRequestFailure("remote_audio_changed")
        val http=client(task) { cancelled(id) }
        update(id,mapOf("request_json" to RemoteWire.canonical(manifest),"manifest_digest" to digest,
            "total_bytes" to input.segments.sumOf { it.committedBytes },"state" to "uploading"))
        val capabilities=http.call("GET","/v1/capabilities")
        val retention=RemoteWire.retentionSeconds(capabilities,task.getValue("profile_id")!!)
        update(id,mapOf("retention_seconds" to retention))
        val upload=http.call("POST","/v1/uploads",RemoteWire.canonical(manifest).toByteArray(),"upload-$id")
        val uid=safeId(upload["uploadId"] as? String)
        if(upload["audioManifestDigest"]!=digest) throw RemoteRequestFailure("remote_identity")
        update(id,mapOf("upload_id" to uid,"expires_at_utc_ms" to (upload["expiresAt"] as? Number)?.toLong()))
        val offsets=upload["offsets"] as? Map<*,*> ?: throw RemoteRequestFailure("remote_protocol")
        val chunkBytes=RemoteWire.chunkBytes(upload["chunkBytes"])
        var acknowledged=0L
        input.segments.forEach { segment ->
            val fid="segment-${segment.index}"
            var offset=(offsets[fid] as? Number)?.toLong() ?: throw RemoteRequestFailure("remote_protocol")
            if(offset !in 0..segment.committedBytes) throw RemoteRequestFailure("remote_offset")
            RandomAccessFile(segment.file,"r").use { source ->
                source.seek(offset)
                while(offset<segment.committedBytes) {
                    if(cancelled(id)) throw RemoteRequestFailure("cancelled")
                    val count=minOf(chunkBytes.toLong(),segment.committedBytes-offset).toInt()
                    val bytes=ByteArray(count);source.readFully(bytes)
                    val reply=http.call("PUT","/v1/uploads/$uid/files/$fid?offset=$offset",bytes)
                    val next=(reply["offset"] as? Number)?.toLong()
                    if(next!=offset+count) throw RemoteRequestFailure("remote_offset")
                    offset=next
                    update(id,mapOf("confirmed_bytes" to acknowledged+offset))
                }
            }
            acknowledged+=segment.committedBytes
        }
        http.call("POST","/v1/uploads/$uid/complete",ByteArray(0))
        update(id,mapOf("state" to "submitting","failure_code" to "remote_submission_pending"))
        val pending=db.rawQuery("SELECT failure_code FROM remote_transcription_tasks WHERE id=?",arrayOf(id)).use {
            it.moveToFirst() && !it.isNull(0) && it.getString(0)=="remote_submission_pending"
        }
        val control=client(task) { stopped() }
        val jid=RemoteSubmission.reconcile(id,uid,task.getValue("profile_id")!!,null,{cancelled(id)},
            { jobId -> update(id,mapOf("job_id" to jobId),true) },
            { method,route,body,key -> control.call(method,route,body?.let { RemoteWire.canonical(it).toByteArray() },key) },submissionPending=pending)
        if(jid==null) {update(id,mapOf("failure_code" to "remote_cancel_ack"),true);return}
        update(id,mapOf("confirmed_bytes" to acknowledged,"attempts" to 0))
        poll(task,id,meeting,jid,digest,input.totalSamples*1000/16000)
    }
    private fun poll(task: Map<String,String?>, id: String, meeting: String, jid: String, digest: String, duration: Long) {
        val http=client(task) { cancelled(id) }
        val status=http.call("GET","/v1/transcriptions/$jid")
        val deadline=(status["expiresAt"] as? Number)?.toLong()
        update(id,mapOf("expires_at_utc_ms" to deadline))
        when(status["state"]) {
            "succeeded" -> {
                val result=http.call("GET","/v1/transcriptions/$jid/result")
                if(!RemoteWire.validResult(result,meeting,id,jid,digest,duration)) throw RemoteRequestFailure("remote_result_invalid")
                db.beginTransaction()
                try {
                    if(cancelled(id)) throw RemoteRequestFailure("cancelled")
                    val json=RemoteWire.canonical(result)
                    val values=ContentValues().apply {
                        put("id",id);put("meeting_id",meeting);put("result_json",json)
                        put("created_at_utc_ms",System.currentTimeMillis())
                        put("created_at",System.currentTimeMillis());put("updated_at",System.currentTimeMillis())
                    }
                    db.insertWithOnConflict("remote_transcript_versions",null,values,0)
                    update(id,mapOf("state" to "completed","expires_at_utc_ms" to deadline,"failure_code" to null))
                    db.setTransactionSuccessful()
                } finally { db.endTransaction() }
            }
            "queued" -> update(id,mapOf("state" to "queued","failure_code" to null))
            "running" -> update(id,mapOf("state" to "running","failure_code" to null))
            "expired" -> update(id,mapOf("state" to "expired","failure_code" to "remote_expired"))
            "failed" -> update(id,mapOf("state" to "failed","failure_code" to "remote_model_failed","expires_at_utc_ms" to deadline))
            "cancelled" -> update(id,mapOf("state" to "cancelled","failure_code" to "remote_cancel_ack"))
            else -> throw RemoteRequestFailure("remote_protocol")
        }
    }
    private fun safeId(value: String?): String = value?.takeIf { it.matches(Regex("[A-Za-z0-9_-]{1,128}")) }
        ?: throw RemoteRequestFailure("remote_identity")
}
