package com.loquiris.transcription

import java.io.ByteArrayInputStream
import java.io.File
import java.nio.file.Files
import java.security.MessageDigest
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AtomicModelBundleStoreTest {
    private val contents = linkedMapOf(
        "models/test-bundle/encoder.onnx" to byteArrayOf(1, 2, 3),
        "models/test-bundle/tokens.txt" to byteArrayOf(4, 5),
        "models/test-bundle/configuration.json" to byteArrayOf(6),
    )

    @Test
    fun `publishes all verified files together and reuses the bundle`() {
        val root = Files.createTempDirectory("bundle-store").toFile()
        try {
            var opens = 0
            val store = store(root) { path -> opens++; ByteArrayInputStream(contents.getValue(path)) }
            val ready = store.materialize() as BundleMaterializationResult.Ready
            for ((path, bytes) in contents) assertArrayEquals(bytes, ready.files.getValue(path).readBytes())
            assertTrue(store.materialize() is BundleMaterializationResult.Ready)
            assertEquals(3, opens)
            assertFalse(root.listFiles()!!.any { it.name.startsWith(".staging-") })
        } finally { root.deleteRecursively() }
    }

    @Test
    fun `each absent or corrupt file fails without publishing`() {
        for (badPath in contents.keys) {
            for (missing in listOf(true, false)) {
                val root = Files.createTempDirectory("bundle-store").toFile()
                try {
                    val result = store(root) { path ->
                        if (path == badPath && missing) throw IllegalStateException("missing")
                        ByteArrayInputStream(if (path == badPath) ByteArray(contents.getValue(path).size) else contents.getValue(path))
                    }.materialize()
                    assertTrue(result is BundleMaterializationResult.Failure)
                    assertTrue(root.listFiles()!!.isEmpty())
                } finally { root.deleteRecursively() }
            }
        }
    }

    @Test
    fun `failed publication preserves previously published model sets`() {
        val root = Files.createTempDirectory("bundle-store").toFile()
        try {
            val previous = File(root, "previous-model-set").apply { mkdirs() }
            File(previous, "keep.bin").writeBytes(byteArrayOf(42))
            val result = AtomicModelBundleStore(root, spec(),
                openAsset = { ByteArrayInputStream(contents.getValue(it)) },
                directorySync = { true },
                publish = { _, _ -> throw IllegalStateException("publication failed") },
            ).materialize()
            assertTrue(result is BundleMaterializationResult.Failure)
            assertArrayEquals(byteArrayOf(42), File(previous, "keep.bin").readBytes())
            assertEquals(listOf("previous-model-set"), root.listFiles()!!.map { it.name })
        } finally { root.deleteRecursively() }
    }

    @Test
    fun `directory sync failure rolls back newly published bundle`() {
        val root = Files.createTempDirectory("bundle-store").toFile()
        try {
            val result = AtomicModelBundleStore(root, spec(),
                openAsset = { ByteArrayInputStream(contents.getValue(it)) },
                directorySync = { directory -> directory != root },
            ).materialize()
            assertTrue(result is BundleMaterializationResult.Failure)
            assertTrue(root.listFiles()!!.isEmpty())
        } finally { root.deleteRecursively() }
    }

    @Test
    fun `duplicate and traversing inventory entries fail before opening assets`() {
        val root = Files.createTempDirectory("bundle-store").toFile()
        try {
            val good = spec()
            for (artifacts in listOf(
                good.artifacts + good.artifacts.first(),
                listOf(good.artifacts.first().copy(path = "models/test-bundle/../escape.onnx")),
            )) {
                var opens = 0
                val result = AtomicModelBundleStore(root, good.copy(artifacts = artifacts),
                    openAsset = { opens++; ByteArrayInputStream(byteArrayOf()) },
                    directorySync = { true },
                ).materialize()
                assertEquals(BundleMaterializationResult.Failure("model_bundle_manifest_invalid"), result)
                assertEquals(0, opens)
            }
        } finally { root.deleteRecursively() }
    }

    private fun store(root: File, open: (String) -> java.io.InputStream) =
        AtomicModelBundleStore(root, spec(), open, directorySync = { true })

    @Test
    fun `native validates the independently fixed Dart UTF8 inventory vector`() {
        val root = Files.createTempDirectory("bundle-vector").toFile()
        try {
            var opens = 0
            val spec = ModelBundleSpec("test-bundle",
                "3ccbc6215c91484d88ff4a88ccfd5962bc63a142dd7c83e8219f6b0e4551d059",
                listOf(
                    BundleArtifactSpec("models/test-bundle/编码器.onnx", "encoder", 16, "0".repeat(64)),
                    BundleArtifactSpec("models/test-bundle/tokens.txt", "tokenizer", 8, "1".repeat(64)),
                ),
            )
            val result = AtomicModelBundleStore(root, spec,
                openAsset = { opens++; throw IllegalStateException("vector has no weight bytes") },
                directorySync = { true },
            ).materialize()
            assertEquals(BundleMaterializationResult.Failure("model_bundle_materialization_failed"), result)
            assertEquals(1, opens)
        } finally { root.deleteRecursively() }
    }

    private fun spec(): ModelBundleSpec {
        val artifacts = contents.map { (path, bytes) ->
            BundleArtifactSpec(path, when {
                path.endsWith("encoder.onnx") -> "encoder"
                path.endsWith("tokens.txt") -> "tokenizer"
                else -> "configuration"
            }, bytes.size.toLong(), hash(bytes))
        }.sortedBy { it.path }
        val json = artifacts.joinToString(",", "[", "]") {
            "{\"path\":\"${it.path}\",\"role\":\"${it.role}\",\"bytes\":${it.bytes},\"sha256\":\"${it.sha256}\"}"
        }
        return ModelBundleSpec("test-bundle", hash(json.toByteArray(Charsets.UTF_8)), artifacts)
    }
}

private fun hash(bytes: ByteArray): String =
    MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
