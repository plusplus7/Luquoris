package com.loquiris.transcription

import java.io.DataOutputStream
import java.io.File
import java.io.IOException
import java.io.OutputStream
import java.security.DigestOutputStream
import java.security.MessageDigest

sealed interface RefinementAudioInventoryResult {
    data class Ready(
        val audio: AuthoritativeAudioResolution.Ready,
        val sha256: String,
        val referenceHashes: List<String>,
    ) : RefinementAudioInventoryResult

    data class Failure(val code: String) : RefinementAudioInventoryResult

    data class Deferred(val code: String) : RefinementAudioInventoryResult

    data object Cancelled : RefinementAudioInventoryResult
}

/** Worker-only complete-audio validation; never repairs or truncates original files. */
class RefinementAudioInventoryReader(
    private val recordingsRoot: File,
    sessionDirectoryFor: (String) -> File,
    private val isRecordingActive: () -> Boolean = { false },
    private val isCancelled: () -> Boolean = { false },
) {
    private val resolver = AuthoritativeAudioResolver(recordingsRoot, sessionDirectoryFor, requireCompleteJournal = true)

    fun read(meetingId: String, expectedSha256: String? = null): RefinementAudioInventoryResult {
        return try {
            checkPriority()
            if (expectedSha256 != null && !expectedSha256.matches(Regex("[0-9a-f]{64}"))) {
                return RefinementAudioInventoryResult.Failure("refinement_audio_inventory_invalid")
            }
            val audio = when (val resolved = resolver.resolve(meetingId)) {
                is AuthoritativeAudioResolution.Failure -> return RefinementAudioInventoryResult.Failure(resolved.code)
                is AuthoritativeAudioResolution.Partial -> return RefinementAudioInventoryResult.Failure(resolved.code)
                is AuthoritativeAudioResolution.Ready -> resolved
            }
            checkPriority()
            val digest = MessageDigest.getInstance("SHA-256")
            val referenceHashes = mutableListOf<String>()
            val discard = object : OutputStream() {
                override fun write(value: Int) = Unit

                override fun write(bytes: ByteArray, offset: Int, length: Int) = Unit
            }
            DataOutputStream(DigestOutputStream(discard, digest)).use { output ->
                output.write("Loquiris.refinement-audio.v1\u0000".toByteArray(Charsets.UTF_8))
                output.writeInt(audio.sampleRateHz)
                output.writeInt(1)
                output.writeInt(audio.codecSpecificData.size)
                audio.codecSpecificData.forEach { config ->
                    output.writeInt(config.size)
                    output.write(config)
                }
                output.writeInt(audio.segments.size)
                val buffer = ByteArray(64 * 1_024)
                audio.segments.forEach { segment ->
                    checkPriority()
                    output.writeInt(segment.index)
                    output.writeLong(segment.startSample)
                    output.writeLong(segment.committedSamples)
                    output.writeLong(segment.committedBytes)
                    val contentDigest = MessageDigest.getInstance("SHA-256")
                    var count = 0L
                    segment.file.inputStream().use { input ->
                        while (true) {
                            checkPriority()
                            val length = input.read(buffer)
                            if (length < 0) break
                            count = Math.addExact(count, length.toLong())
                            if (count > segment.committedBytes) throw IOException("audio changed")
                            contentDigest.update(buffer, 0, length)
                        }
                    }
                    if (count != segment.committedBytes) throw IOException("audio changed")
                    val contentHash = contentDigest.digest()
                    if (contentHash.joinToString("") { "%02x".format(it) } != segment.verifiedSha256) {
                        throw InventoryAbort(RefinementAudioInventoryResult.Failure("refinement_audio_changed"))
                    }
                    output.write(contentHash)
                    val reference = "recordings/" + segment.file.relativeTo(recordingsRoot.canonicalFile).invariantSeparatorsPath
                    referenceHashes += MessageDigest.getInstance("SHA-256").digest(reference.toByteArray(Charsets.UTF_8))
                        .joinToString("") { "%02x".format(it) }
                }
            }
            checkPriority()
            val sha256 = digest.digest().joinToString("") { "%02x".format(it) }
            if (expectedSha256 != null && sha256 != expectedSha256) {
                RefinementAudioInventoryResult.Failure("refinement_audio_inventory_mismatch")
            } else {
                RefinementAudioInventoryResult.Ready(audio, sha256, referenceHashes.toList())
            }
        } catch (abort: InventoryAbort) {
            abort.result
        } catch (_: IOException) {
            RefinementAudioInventoryResult.Failure("transcription_audio_read_failed")
        } catch (_: SecurityException) {
            RefinementAudioInventoryResult.Failure("transcription_audio_read_failed")
        }
    }

    private fun checkPriority() {
        if (isCancelled()) throw InventoryAbort(RefinementAudioInventoryResult.Cancelled)
        if (isRecordingActive()) {
            throw InventoryAbort(RefinementAudioInventoryResult.Deferred("refinement_recording_active"))
        }
    }
}

private class InventoryAbort(val result: RefinementAudioInventoryResult) : RuntimeException()
