package com.loquiris.remote

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
import java.nio.channels.FileLock
import java.nio.channels.OverlappingFileLockException
import java.util.concurrent.Executors

class RemoteDatabaseLease(private val file: RandomAccessFile, private val lock: FileLock): AutoCloseable {
    override fun close() { try { lock.release() } finally { file.close() } }
}

/** Serializes closed-file migration snapshots against native background database use. */
object RemoteRuntime {
    val transfers=RemoteTransferGate()
    private val executor=Executors.newSingleThreadExecutor()
    private var migrationLease: RemoteDatabaseLease?=null
    fun lock(context: Context): RemoteDatabaseLease {
        val file=RandomAccessFile(File(context.filesDir,"remote-database.lock"),"rw")
        try {
            while(true) {
                val acquired=try { file.channel.tryLock() } catch (_: OverlappingFileLockException) { null }
                if(acquired!=null) return RemoteDatabaseLease(file,acquired)
                Thread.sleep(50)
            }
        } catch(error: Exception) { file.close();throw error }
    }
    fun install(context: Context, messenger: BinaryMessenger) {
        val handler=android.os.Handler(android.os.Looper.getMainLooper())
        MethodChannel(messenger,"com.loquiris/remote_v1").setMethodCallHandler { call,result ->
            executor.execute {
                val reply=try {
                    when(call.method) {
                        "prepare" -> { transfers.pause(); if(migrationLease==null) migrationLease=lock(context);mapOf("ok" to true) }
                        "resume" -> {
                            val path=call.argument<String>("databasePath") ?: error("remote_database")
                            require(File(path).canonicalFile==File(context.filesDir,"loquiris.sqlite").canonicalFile)
                            context.getSharedPreferences("remote-runtime",Context.MODE_PRIVATE).edit().putString("database",path).commit()
                            migrationLease?.close();migrationLease=null
                            transfers.resume()
                            RemoteTranscriptionJobService.schedule(context)
                            mapOf("ok" to true)
                        }
                        "wake" -> { RemoteTranscriptionJobService.schedule(context);mapOf("ok" to true) }
                        "loadConnection" -> mapOf("ok" to true, "value" to RemoteCredentials(context).connection())
                        "saveConnection" -> mapOf("ok" to true, "value" to RemoteCredentials(context).saveConnection(
                            call.argument<String>("endpoint") ?: "", call.argument<String>("token") ?: ""))
                        "saveCredential" -> mapOf("ok" to true,"value" to RemoteCredentials(context).save(
                            call.argument<String>("endpoint") ?: "",call.argument<String>("token") ?: ""))
                        else -> mapOf("ok" to false)
                    }
                } catch (_: Exception) {
                    if(call.method=="resume") { migrationLease?.close();migrationLease=null }
                    mapOf("ok" to false)
                }
                handler.post { result.success(reply) }
            }
        }
    }
}
