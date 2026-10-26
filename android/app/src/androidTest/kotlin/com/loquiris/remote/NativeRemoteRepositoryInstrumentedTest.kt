package com.loquiris.remote

import android.content.ContentValues
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Uses the exported real Drift v7 database, not a handwritten schema substitute. */
@RunWith(AndroidJUnit4::class)
class NativeRemoteRepositoryInstrumentedTest {
    private val context get()=InstrumentationRegistry.getInstrumentation().targetContext
    private val assets get()=InstrumentationRegistry.getInstrumentation().context.assets
    private fun fixture(name:String)=RemoteJson.decode(JSONObject(assets.open(name).bufferedReader().use {it.readText()})) as Map<String,Any?>
    private fun withDatabase(action:(RemoteSqlite)->Unit) {
        val file=File(context.cacheDir,"remote-repository-${System.nanoTime()}.sqlite")
        assets.open("remote-v7.sqlite").use {input->file.outputStream().use {input.copyTo(it)}}
        try {RemoteSqlite(file.path).use {db->
            db.execSQL("INSERT INTO meetings(id,title,lifecycle,language_mode,created_at,updated_at) VALUES ('meeting-1','test','finalized','mixed',1,1)")
            val manifest=fixture("upload.json")
            db.insertWithOnConflict("remote_transcription_tasks",null,ContentValues().apply {
                put("id","run-1");put("meeting_id","meeting-1");put("endpoint","https://server.example")
                put("credential_ref","unused");put("profile_id","qwen-1.7b");put("state","running")
                put("request_json",RemoteWire.canonical(manifest));put("manifest_digest",RemoteWire.digest(manifest))
                put("upload_id","upload-1");put("job_id","job-1")
                put("created_at",1L);put("updated_at",1L);put("created_at_utc_ms",1L);put("updated_at_utc_ms",1L)
            },0)
            action(db)
        }} finally {file.delete();File(file.path+"-wal").delete();File(file.path+"-shm").delete()}
    }
    private fun state(db:RemoteSqlite)=db.rawQuery("SELECT state FROM remote_transcription_tasks",null).use {it.moveToFirst();it.getString(0)}
    private fun count(db:RemoteSqlite)=db.rawQuery("SELECT count(*) FROM remote_transcript_versions",null).use {it.moveToFirst();it.getInt(0)}
    private fun runner(db:RemoteSqlite,send:(String,String)->Map<String,Any?>)=NativeRemoteRepository(context,db,
        transportFactory={_,_->object:RemoteTransport {
            override fun call(method:String,route:String,body:ByteArray?,key:String?)=send(method,route)
        }}) {false}
    @Test fun importsAtomicallyAndDuplicateCompletionPreservesHumanEdits()=withDatabase {db->
        val result=fixture("result.json")
        val send:(String,String)->Map<String,Any?> = {_,route->if(route.endsWith("/result")) result else mapOf("state" to "succeeded","expiresAt" to 2000000000000L)}
        assertFalse(runner(db,send).synchronize());assertEquals("completed",state(db));assertEquals(1,count(db))
        db.execSQL("UPDATE remote_transcript_versions SET edited_text='human correction'")
        db.execSQL("UPDATE remote_transcription_tasks SET state='running'")
        assertFalse(runner(db,send).synchronize());assertEquals(1,count(db))
        db.rawQuery("SELECT edited_text FROM remote_transcript_versions",null).use {it.moveToFirst();assertEquals("human correction",it.getString(0))}
    }
    @Test fun mismatchedRunCannotPublishAndActualExpirySurvivesRejectedResult()=withDatabase {db->
        val bad=fixture("result.json")+mapOf("runId" to "other-run")
        runner(db) {_,route->if(route.endsWith("/result")) bad else mapOf("state" to "succeeded","expiresAt" to 2000000000000L)}.synchronize()
        assertEquals("failed",state(db));assertEquals(0,count(db))
        db.rawQuery("SELECT expires_at_utc_ms FROM remote_transcription_tasks",null).use {it.moveToFirst();assertEquals("2000000000000",it.getString(0))}
    }
    @Test fun cancellationDuringResultResponseCannotPublishLateResult()=withDatabase {db->
        runner(db) {_,route->
            if(route.endsWith("/result")) {db.execSQL("UPDATE remote_transcription_tasks SET state='cancelled'");fixture("result.json")}
            else mapOf("state" to "succeeded")
        }.synchronize()
        assertEquals("cancelled",state(db));assertEquals(0,count(db))
    }
    @Test fun restartRetainsKnownJobAndBackoffDoesNotResubmit()=withDatabase {db->
        val methods=mutableListOf<String>()
        runner(db) {method,_->methods+=method;throw java.io.IOException("lost response")}.synchronize()
        assertEquals("waitingNetwork",state(db));assertEquals(listOf("GET"),methods)
        db.execSQL("UPDATE remote_transcription_tasks SET retry_at_utc_ms=0")
        runner(db) {method,_->methods+=method;mapOf("state" to "queued")}.synchronize()
        assertEquals("queued",state(db));assertEquals(listOf("GET","GET"),methods)
    }
}
