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

class WhisperModelStoreTest {
    @Test
    fun `materializes verified model atomically and reuses the verified file`() {
        val bytes = "verified-model".toByteArray()
        val root = Files.createTempDirectory("loquiris-model-store").toFile()
        var opens = 0
        val store =
            WhisperModelStore(
                modelRoot = root,
                spec = ModelArtifactSpec("model", "models/model.bin", bytes.size.toLong(), sha256(bytes)),
                openAsset = {
                    opens += 1
                    ByteArrayInputStream(bytes)
                },
            )

        val first = store.materialize() as ModelMaterializationResult.Ready
        val second = store.materialize() as ModelMaterializationResult.Ready

        assertEquals(first.file.canonicalFile, second.file.canonicalFile)
        assertArrayEquals(bytes, first.file.readBytes())
        assertEquals(1, opens)
        assertFalse(File(first.file.parentFile, "${first.file.name}.tmp").exists())
    }

    @Test
    fun `never publishes an asset whose digest does not match`() {
        val root = Files.createTempDirectory("loquiris-model-store").toFile()
        val bytes = "wrong-model".toByteArray()
        val store =
            WhisperModelStore(
                modelRoot = root,
                spec = ModelArtifactSpec("model", "models/model.bin", bytes.size.toLong(), "0".repeat(64)),
                openAsset = { ByteArrayInputStream(bytes) },
            )

        assertEquals(
            ModelMaterializationResult.Failure("transcription_model_hash_mismatch"),
            store.materialize(),
        )
        assertTrue(root.walkTopDown().none { it.isFile })
    }
}

private fun sha256(bytes: ByteArray): String =
    MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
