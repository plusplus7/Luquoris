package com.loquiris.backup

import com.loquiris.recording.RecordingSegmentManifest
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest

internal data class RestoreRecordingFileDigest(
    val name: String,
    val bytes: Long,
    val sha256: String,
)

/**
 * Hashes recording content independently from the meeting ID stored in the
 * manifest so a conflicting restore can retain identical-content semantics.
 */
internal fun restoreRecordingFingerprint(
    manifest: RecordingSegmentManifest,
    fileDigests: List<RestoreRecordingFileDigest>,
): String {
    val expectedNames =
        manifest.segments.flatMap { segment -> listOf(segment.dataFileName, segment.journalFileName) }
    require(fileDigests.map(RestoreRecordingFileDigest::name).sorted() == expectedNames.sorted())
    val byName = fileDigests.associateBy(RestoreRecordingFileDigest::name)
    val digest = FramedDigest()
    digest.text("loquiris-recording-content-v1")
    digest.number(manifest.sampleRateHz.toLong())
    digest.number(manifest.channelCount.toLong())
    digest.number(manifest.bitRateBitsPerSecond.toLong())
    digest.number(manifest.codecSpecificData.size.toLong())
    manifest.codecSpecificData.forEach(digest::bytes)
    digest.number(manifest.segments.size.toLong())
    manifest.segments.forEach { segment ->
        digest.number(segment.index.toLong())
        digest.number(segment.startSample)
        digest.text(segment.dataFileName)
        digest.text(segment.journalFileName)
        listOf(segment.dataFileName, segment.journalFileName).forEach { name ->
            val file = requireNotNull(byName[name])
            digest.text(file.name)
            digest.number(file.bytes)
            digest.text(file.sha256)
        }
    }
    return digest.finish()
}

private class FramedDigest {
    private val digest = MessageDigest.getInstance("SHA-256")

    fun number(value: Long) {
        digest.update(ByteBuffer.allocate(Long.SIZE_BYTES).order(ByteOrder.BIG_ENDIAN).putLong(value).array())
    }

    fun text(value: String) = bytes(value.toByteArray(Charsets.UTF_8))

    fun bytes(value: ByteArray) {
        number(value.size.toLong())
        digest.update(value)
    }

    fun finish(): String = digest.digest().joinToString("") { "%02x".format(it) }
}
