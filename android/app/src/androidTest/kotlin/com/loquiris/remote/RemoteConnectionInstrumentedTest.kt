package com.loquiris.remote

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RemoteConnectionInstrumentedTest {
    @Test fun connectionSurvivesStoreRecreationWithoutExposingToken() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val root = File(context.noBackupFilesDir, "remote-credentials")
        val pointer = File(root, "default-connection.json")
        val prior = if (pointer.exists()) pointer.readBytes() else null
        var reference: String? = null
        try {
            val saved = RemoteCredentials(context).saveConnection("http://192.168.1.20:18000", "z".repeat(32))
            reference = saved
            val loaded = RemoteCredentials(context).connection()!!
            assertEquals("http://192.168.1.20:18000", loaded["endpoint"])
            assertEquals(reference, loaded["credentialRef"])
            assertFalse(pointer.readText().contains("z".repeat(32)))
            assertEquals("z".repeat(32), RemoteCredentials(context).token(saved, "http://192.168.1.20:18000"))
        } finally {
            reference?.let { File(root,it).delete() }
            if (prior == null) pointer.delete() else pointer.writeBytes(prior)
        }
    }
    @Test fun lanHttpUsesPlatformCleartextPolicyAndKeepsBearerAuthentication() {
        val server = java.net.ServerSocket(0,1,java.net.InetAddress.getByName("127.0.0.1"))
        server.soTimeout=5000
        val received=java.util.concurrent.CompletableFuture<List<String>>()
        val listener=kotlin.concurrent.thread {
            try {
                server.accept().use { socket ->
                    socket.soTimeout=5000
                    val input=socket.getInputStream().bufferedReader()
                    val headers=mutableListOf<String>()
                    while(true) { val line=input.readLine() ?: break; if(line.isEmpty())break;headers.add(line) }
                    received.complete(headers)
                    val body="{\"schemaVersion\":1,\"profiles\":[\"qwen-1.7b\"]}"
                    socket.getOutputStream().write(("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: ${body.toByteArray().size}\r\nConnection: close\r\n\r\n"+body).toByteArray())
                }
            } catch(error:Throwable){received.completeExceptionally(error)}
        }
        try {
            RemoteRuntime.transfers.resume()
            val response=RemoteHttp("http://127.0.0.1:${server.localPort}","test-token",{false}).call("GET","/v1/capabilities",null,null)
            assertEquals(1,response["schemaVersion"])
            assertEquals(listOf("qwen-1.7b"),response["profiles"])
            assertTrue(received.get(1,java.util.concurrent.TimeUnit.SECONDS).any {it.equals("Authorization: Bearer test-token",ignoreCase=true)})
        } finally {server.close();listener.join(6000)}
    }

}
