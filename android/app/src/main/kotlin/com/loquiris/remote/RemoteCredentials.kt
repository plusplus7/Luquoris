package com.loquiris.remote

import android.content.Context
import android.util.AtomicFile
import org.json.JSONObject
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.io.File
import java.security.KeyStore
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Tokens are never written to SQLite, logs or backup/export payloads. */
class RemoteCredentials(private val context: Context) {
    private val root = File(context.noBackupFilesDir, "remote-credentials").apply { mkdirs() }
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val alias = "loquiris-remote-v1"
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
            generateKey()
        }
    }
    @Synchronized fun save(endpoint: String, token: String): String {
        require(RemoteWire.validEndpoint(endpoint) && token.length in 32..4096 && token.none { it == '\r' || it == '\n' })
        val reference = UUID.randomUUID().toString()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        val bytes = cipher.doFinal((endpoint.trimEnd('/') + "\n" + token).toByteArray(Charsets.UTF_8))
        File(root, reference).outputStream().use { out -> out.write(cipher.iv); out.write(bytes); out.flush(); out.fd.sync() }
        return reference
    }
    @Synchronized fun saveConnection(endpoint: String, token: String): String {
        val reference = save(endpoint, token)
        val file = AtomicFile(File(root, "default-connection.json"))
        val output = file.startWrite()
        try {
            output.write(JSONObject().put("endpoint", endpoint.trimEnd('/')).put("credentialRef", reference).toString().toByteArray(Charsets.UTF_8))
            file.finishWrite(output)
        } catch (error: Exception) { file.failWrite(output); throw error }
        return reference
    }
    @Synchronized fun connection(): Map<String, String>? {
        val file = AtomicFile(File(root, "default-connection.json"))
        if (!file.baseFile.exists()) return null
        val value = JSONObject(String(file.readFully(), Charsets.UTF_8))
        val endpoint = value.getString("endpoint")
        val reference = value.getString("credentialRef")
        require(RemoteWire.validEndpoint(endpoint))
        token(reference, endpoint) // Validate the encrypted destination binding; never return the secret.
        return mapOf("endpoint" to endpoint, "credentialRef" to reference)
    }
    @Synchronized fun token(reference: String, endpoint: String): String {
        require(reference.matches(Regex("[a-f0-9-]{36}")))
        val value = File(root, reference).readBytes()
        require(value.size in 29..8192)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply {
            init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, value.copyOfRange(0,12)))
        }
        val decoded = String(cipher.doFinal(value.copyOfRange(12,value.size)), Charsets.UTF_8).split('\n', limit=2)
        require(decoded.size == 2 && decoded[0] == endpoint.trimEnd('/'))
        return decoded[1]
    }
}
