package com.loquiris.remote

import java.net.URI
import java.security.MessageDigest

/** The v1 protocol keeps journal hashes and upload-manifest hashes distinct. */
object RemoteWire {
    fun validEndpoint(value: String): Boolean = runCatching {
        val uri = URI(value)
        value == value.trim() && value.none { it.isWhitespace() || it.code < 32 || it.code >= 127 || it == '%' } &&
            !uri.host.isNullOrBlank() && uri.userInfo == null && uri.port.let { it == -1 || it in 1..65535 } &&
            uri.query == null && uri.fragment == null && uri.path in listOf("", "/") &&
            (uri.scheme.equals("https", ignoreCase = true) || (uri.scheme.equals("http", ignoreCase = true) && privateIpv4(uri.host)))
    }.getOrDefault(false)

    private fun privateIpv4(host: String): Boolean {
        val parts = host.split('.')
        if (parts.size != 4) return false
        val bytes = parts.map { part ->
            val number = part.toIntOrNull() ?: return false
            if (number !in 0..255 || number.toString() != part) return false
            number
        }
        return host == "127.0.0.1" || bytes[0] == 10 ||
            (bytes[0] == 172 && bytes[1] in 16..31) || (bytes[0] == 192 && bytes[1] == 168)
    }

    fun retentionSeconds(value: Map<String,Any?>, profile: String): Long {
        require(value["schemaVersion"]==1 && (value["profiles"] as? List<*>)?.contains(profile)==true)
        val seconds=integer(value["retentionSeconds"]) ?: throw IllegalArgumentException("remote_retention")
        require(seconds>0)
        chunkBytes(value["chunkBytes"])
        return seconds
    }

    fun chunkBytes(value: Any?): Int {
        val size=when(value) { is Int -> value.toLong();is Long -> value;else -> throw IllegalArgumentException("remote_chunk_limit") }
        require(size in 1..8388608)
        return minOf(size,1048576).toInt()
    }

    fun canonical(value: Any?): String = when (value) {
        null -> "null"
        is Boolean, is Int, is Long -> value.toString()
        is String -> buildString {
            append('"')
            for (ch in value) when (ch) {
                '"' -> append("\\\"")
                '\\' -> append("\\\\")
                '\n' -> append("\\n")
                '\r' -> append("\\r")
                '\t' -> append("\\t")
                '\b' -> append("\\b")
                '\u000C' -> append("\\f")
                else -> if (ch.code < 32 || ch.code > 127) append("\\u%04x".format(ch.code)) else append(ch)
            }
            append('"')
        }
        is Map<*,*> -> value.entries.sortedBy { it.key as String }.joinToString(",", "{", "}") {
            canonical(it.key as String) + ":" + canonical(it.value)
        }
        is List<*> -> value.joinToString(",", "[", "]") { canonical(it) }
        else -> error("remote_wire_type")
    }

    fun digest(value: Any?): String = MessageDigest.getInstance("SHA-256")
        .digest(canonical(value).toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }

    fun validResult(value: Map<String,Any?>, meeting: String, run: String, job: String,
                    digest: String, duration: Long): Boolean {
        val fields=setOf("schemaVersion","jobId","meetingId","runId","audioManifestDigest","durationMs","provenance","segments")
        if(value.keys.any {it !in fields} || !digest.matches(Regex("[a-f0-9]{64}")) ||
            !meeting.matches(Regex("[A-Za-z0-9_-]{1,128}")) || !run.matches(Regex("[A-Za-z0-9_-]{1,128}"))) return false
        if (value["schemaVersion"] != 1 || value["meetingId"] != meeting || value["runId"] != run ||
            value["jobId"] != job || value["audioManifestDigest"] != digest || integer(value["durationMs"]) != duration) return false
        val provenance = value["provenance"] as? Map<*,*> ?: return false
        if ((provenance["modelRevision"] as? String).isNullOrBlank() ||
            (provenance["runtime"] as? String).isNullOrBlank() || provenance.values.any { it !is String }) return false
        val segments = value["segments"] as? List<*> ?: return false
        if (segments.size > 100000 || duration !in 0..43200000) return false
        var previous = 0L
        for (raw in segments) {
            val segment = raw as? Map<*,*> ?: return false
            if(segment.keys.any {it !in setOf("startMs","endMs","text","language","speaker")}) return false
            val language=segment["language"]
            if(language!=null && (language !is String || language.length>32)) return false
            val start = integer(segment["startMs"]) ?: return false
            val end = integer(segment["endMs"]) ?: return false
            val text = segment["text"] as? String ?: return false
            if (start < previous || end <= start || end > duration || text.isEmpty() || text.length > 16000 || segment["speaker"] != null) return false
            previous = end
        }
        return true
    }

    private fun integer(value: Any?): Long? = when (value) {
        is Long -> value
        is Int -> value.toLong()
        else -> null
    }
}
