package com.loquiris.remote

import android.content.ContentValues
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class RemoteRuntimeInstrumentedTest {
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private val fixtures get() = InstrumentationRegistry.getInstrumentation().context.assets
    @Test fun sharedFixturesAgreeOnManifestDigestAndResultIdentity() {
        val upload=RemoteJson.decode(JSONObject(fixtures.open("upload.json").bufferedReader().use { it.readText() })) as Map<String,Any?>
        val result=RemoteJson.decode(JSONObject(fixtures.open("result.json").bufferedReader().use { it.readText() })) as Map<String,Any?>
        val digest=RemoteWire.digest(upload)
        assertEquals(result["audioManifestDigest"],digest)
        assertTrue(RemoteWire.validResult(result,"meeting-1","run-1","job-1",digest,2000))
        assertFalse(RemoteWire.validResult(result+mapOf("schemaVersion" to 2),"meeting-1","run-1","job-1",digest,2000))
        assertFalse(RemoteWire.validResult(result+mapOf("unexpected" to true),"meeting-1","run-1","job-1",digest,2000))
    }
    @Test fun bundledConnectionReadsStrictSchemaAndCommitsAtomically() {
        val file=File(context.cacheDir,"remote-driver-${System.nanoTime()}.sqlite")
        try {
            RemoteSqlite(file.path).use { db ->
                db.execSQL("CREATE TABLE strict_data (id TEXT PRIMARY KEY, value INTEGER NOT NULL) STRICT")
                db.beginTransaction()
                db.insertWithOnConflict("strict_data",null,ContentValues().apply {put("id","run-1");put("value",1)},0)
                db.setTransactionSuccessful();db.endTransaction()
                db.rawQuery("SELECT id,value FROM strict_data",null).use { row ->
                    assertTrue(row.moveToFirst());assertEquals("run-1",row.getString(0));assertEquals(1,row.getInt(1))
                }
                db.beginTransaction()
                db.update("strict_data",ContentValues().apply {put("value",2)},"id=?",arrayOf("run-1"))
                db.endTransaction()
                db.rawQuery("SELECT value FROM strict_data",null).use { row ->assertTrue(row.moveToFirst());assertEquals(1,row.getInt(0))}
            }
        } finally {file.delete();File(file.path+"-wal").delete();File(file.path+"-shm").delete()}
    }
    @Test fun keystoreTokenIsBoundToItsHttpsDestination() {
        val credentials=RemoteCredentials(context)
        val reference=credentials.save("https://server.example","a".repeat(32))
        try {
            assertEquals("a".repeat(32),credentials.token(reference,"https://server.example"))
            try {credentials.token(reference,"https://other.example");fail("credential crossed destination")}
            catch (_: IllegalArgumentException) { }
        } finally {File(File(context.noBackupFilesDir,"remote-credentials"),reference).delete()}
    }
}
