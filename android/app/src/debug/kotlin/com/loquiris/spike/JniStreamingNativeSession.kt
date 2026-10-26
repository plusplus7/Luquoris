package com.loquiris.spike

import android.app.Application
import com.loquiris.BuildConfig
import com.loquiris.transcription.StreamingNativeSession
import com.loquiris.transcription.StreamingPcmKernel
import com.loquiris.transcription.StreamingRemoteKernel
import com.loquiris.transcription.StreamingRemoteModelUnavailable
import com.loquiris.transcription.StreamingRemoteResult
import com.loquiris.transcription.StreamingProbeBundle
import java.io.File
import java.security.MessageDigest

/** Fixed experiment fixture, not the production model catalog or an import API. */
internal fun createVerifiedNativeProbeKernel(filesDir: File, packageName: String, digest: String): StreamingRemoteKernel {
    // Keep the old native-only smoke sentinel; real Dart requests pin inventory.
    if (!BuildConfig.LOQUIRIS_STREAMING_NATIVE_SPIKE || digest !in setOf("1".repeat(64), StreamingProbeBundle.digest))
        throw StreamingRemoteModelUnavailable()
    check(Application.getProcessName() == "$packageName:streaming_native_probe")
    // Android may canonicalize /data/user/0 to /data/data inside the app's
    // mount namespace. Accept that OS-owned parent alias, not fixture symlinks.
    val root = File(filesDir.canonicalFile, "streaming-native-spike-20261016")
    val pins = listOf(
        "encoder.onnx" to "db6f51551762e40e549166fe041ea3e45464370b595e9ad23f06478ec3794fbb",
        "decoder.onnx" to "4b618d383af304cfae281dbf0a53e8bf442c2f0502256cd5694bd6567ebdd834",
        "joiner.onnx" to "bdda356d6f9b8c2d7cee9ee0e26075fa537490f7fd06520be408d287073667b9",
        "tokens.txt" to "a8e0e4ec53810e433789b54a5c0134a7eaa2ffca595a6334d54c00da858841d3",
    )
    val paths = pins.map { (name, expected) ->
        val file = File(root, name)
        if (!file.isFile || file.length() !in 1..200_000_000L ||
            file.canonicalFile != file.absoluteFile) throw StreamingRemoteModelUnavailable()
        val hash = MessageDigest.getInstance("SHA-256")
        file.inputStream().buffered().use { input ->
            val buffer = ByteArray(65536)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                hash.update(buffer, 0, count)
            }
        }
        if (hash.digest().joinToString("") { "%02x".format(it) } != expected)
            throw StreamingRemoteModelUnavailable()
        file.absolutePath
    }
    System.loadLibrary("loquiris_streaming_debug")
    check(StreamingNativeBridge.nativeAbiVersion() == 2)
    return StreamingPcmKernel(JniStreamingNativeSession(
        StreamingNativeBridge.nativeCreate(paths[0], paths[1], paths[2], paths[3])))
}

/** Owned solely by StreamingPcmKernel, which serializes decode/close. */
internal class JniStreamingNativeSession(private var handle: Long) : StreamingNativeSession {
    init { check(handle > 0) }
    override fun accept(samples: FloatArray): StreamingRemoteResult.Text =
        StreamingNativeBridge.nativeAccept(handle, samples)
    override fun finishUtterance(): StreamingRemoteResult.Text = StreamingNativeBridge.nativeFinish(handle)
    override fun close() {
        if (handle == 0L) return
        StreamingNativeBridge.nativeClose(handle)
        handle = 0L
    }
}

/** Version 2 adds explicit finish/reset; close remains cancellation without flush. */
internal object StreamingNativeBridge {
    external fun nativeAbiVersion(): Int
    external fun nativeCreate(encoder: String, decoder: String, joiner: String, tokens: String): Long
    external fun nativeAccept(handle: Long, samples: FloatArray): StreamingRemoteResult.Text
    external fun nativeFinish(handle: Long): StreamingRemoteResult.Text
    external fun nativeClose(handle: Long)
}
