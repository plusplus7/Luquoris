package com.loquiris.remote

import java.net.ServerSocket
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread
import org.junit.Assert.*
import org.junit.Test

class RemoteHttpLanTest {
    @Test fun authenticatedLanRequestDoesNotFollowRedirect() {
        val headers = CompletableFuture<List<String>>()
        ServerSocket(0, 1, java.net.InetAddress.getByName("127.0.0.1")).use { server ->
            server.soTimeout = 3000
            val listener = thread {
                try {
                    server.accept().use { socket ->
                        socket.soTimeout = 3000
                        val input = socket.getInputStream().bufferedReader()
                        val lines = mutableListOf<String>()
                        while (true) { val line = input.readLine() ?: break; if (line.isEmpty()) break; lines.add(line) }
                        headers.complete(lines)
                        socket.getOutputStream().write(("HTTP/1.1 302 Found\r\nLocation: http://127.0.0.1:1/\r\nContent-Length: 0\r\nConnection: close\r\n\r\n").toByteArray())
                    }
                } catch (error: Throwable) { headers.completeExceptionally(error) }
            }
            RemoteRuntime.transfers.resume()
            try {
                RemoteHttp("http://127.0.0.1:${server.localPort}", "test-token", { false }).call("GET", "/v1/capabilities", null, null)
                fail("redirect must be rejected")
            } catch (error: RemoteRequestFailure) {
                assertEquals("remote_transport", error.code)
                assertFalse(error.retryable)
            } finally { listener.join(4000) }
            assertTrue(headers.get(1, TimeUnit.SECONDS).any { it.equals("Authorization: Bearer test-token", ignoreCase = true) })
        }
    }
}
