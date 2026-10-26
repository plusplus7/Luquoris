package com.loquiris.remote

import org.json.JSONArray
import org.json.JSONObject
import java.net.URL
import java.net.HttpURLConnection

class RemoteRequestFailure(val code: String, val retryable: Boolean = false): Exception(code)

/** Injectable HTTP boundary; durable repository tests use real SQLite without external TLS. */
interface RemoteTransport {
    fun call(method: String, route: String, body: ByteArray? = null, key: String? = null): Map<String,Any?>
}

/** Bounded requests with no redirect, cookie, trust override or secret-bearing logging. */
class RemoteHttp(private val endpoint: String, private val token: String,
                 private val stopped: () -> Boolean): RemoteTransport {
    override fun call(method: String, route: String, body: ByteArray?, key: String?): Map<String,Any?> {
        if (stopped() || RemoteRuntime.transfers.paused) throw RemoteRequestFailure("cancelled")
        require(RemoteWire.validEndpoint(endpoint))
        val connection = URL(endpoint.trimEnd('/') + route).openConnection() as HttpURLConnection
        val lease=RemoteRuntime.transfers.register { connection.disconnect() }
        try {
            if(RemoteRuntime.transfers.paused) throw RemoteRequestFailure("cancelled")
            connection.instanceFollowRedirects = false
            connection.requestMethod = method
            connection.connectTimeout = 15000
            connection.readTimeout = 30000
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.setRequestProperty("Accept", "application/json")
            key?.let { connection.setRequestProperty("Idempotency-Key", it) }
            if (body != null) {
                require(body.size <= 1024 * 1024)
                connection.doOutput = true
                connection.setFixedLengthStreamingMode(body.size)
                connection.setRequestProperty("Content-Type", if (method == "PUT") "application/octet-stream" else "application/json")
                connection.outputStream.use { it.write(body) }
            }
            val status = connection.responseCode
            if (status !in 200..299) throw RemoteRequestFailure(when(status) {
                401,403 -> "remote_authentication"
                404 -> "remote_missing"
                410 -> "remote_expired"
                413 -> "remote_quota"
                409,422 -> "remote_rejected"
                else -> "remote_transport"
            }, status == 429 || status >= 500)
            val data = java.io.ByteArrayOutputStream()
            connection.inputStream.use { input ->
                val buffer = ByteArray(65536)
                while (true) {
                    if (stopped() || RemoteRuntime.transfers.paused) throw RemoteRequestFailure("cancelled")
                    val count = input.read(buffer)
                    if (count < 0) break
                    if (data.size() + count > 16 * 1024 * 1024) throw RemoteRequestFailure("remote_response_limit")
                    data.write(buffer,0,count)
                }
            }
            return RemoteJson.decode(JSONObject(data.toString("UTF-8"))) as Map<String,Any?>
        } finally { lease.close();connection.disconnect() }
    }
}

object RemoteJson {
    fun decode(value: Any?): Any? = when (value) {
        JSONObject.NULL, null -> null
        is JSONObject -> value.keys().asSequence().associateWith { decode(value.get(it)) }
        is JSONArray -> (0 until value.length()).map { decode(value.get(it)) }
        else -> value
    }
}
