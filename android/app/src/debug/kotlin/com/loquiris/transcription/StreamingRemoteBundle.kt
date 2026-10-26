package com.loquiris.transcription

import android.os.Bundle

/** Android envelope only; the strict shared wire codec owns validation. */
object StreamingRemoteBundle {
    fun toRemoteBundle(fields: Map<String, Any>): Bundle = Bundle().apply {
        for ((key, value) in fields) when (value) {
            is Int -> putInt(key, value)
            is Long -> putLong(key, value)
            is String -> putString(key, value)
            is Boolean -> putBoolean(key, value)
            is ByteArray -> putByteArray(key, value)
            else -> error("invalid_streaming_envelope")
        }
    }

    @Suppress("DEPRECATION") // Preserve primitive types on API 29; no custom Parcelable.
    fun fromRemoteBundle(bundle: Bundle): Map<String, Any?>? {
        if (bundle.hasFileDescriptors() || bundle.size() > 12) return null
        val fields = mutableMapOf<String, Any?>()
        for (key in bundle.keySet()) {
            if (key.length > 32) return null
            val value = bundle.get(key)
            if (value !is Int && value !is Long && value !is String && value !is Boolean && value !is ByteArray) return null
            fields[key] = value
        }
        return fields
    }
}
