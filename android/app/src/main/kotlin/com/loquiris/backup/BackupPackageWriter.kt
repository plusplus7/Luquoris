package com.loquiris.backup

import java.io.FilterOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.security.DigestOutputStream
import java.security.MessageDigest
import java.time.Instant
import java.time.format.DateTimeParseException
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

data class BackupPackageRequest(
    val formatVersion: Int,
    val schemaVersion: Int,
    val appVersion: String,
    val exportedAtUtc: String,
    val sources: List<BackupPayloadSource>,
)

data class BackupPayloadSource(
    val path: String,
    val open: () -> InputStream,
)

sealed interface BackupWriteResult {
    data class Success(
        val bytesWritten: Long,
        val sha256: String,
    ) : BackupWriteResult

    data class Failure(
        val code: String,
    ) : BackupWriteResult
}

class BackupPackageWriter {
    fun write(
        request: BackupPackageRequest,
        output: OutputStream,
    ): BackupWriteResult {
        val validationFailure = validate(request)
        if (validationFailure != null) return BackupWriteResult.Failure(validationFailure)
        return try {
            val hashedSources =
                request.sources
                    .sortedBy(BackupPayloadSource::path)
                    .map { source -> HashedSource(source, hash(source.open)) }
            val checksumBytes = checksumJson(hashedSources).toByteArray(Charsets.UTF_8)
            val manifestBytes = manifestJson(request, sha256(checksumBytes)).toByteArray(Charsets.UTF_8)
            val archiveDigest = MessageDigest.getInstance(SHA_256)
            val counted = CountingOutputStream(DigestOutputStream(output, archiveDigest))
            val zip = ZipOutputStream(counted)
            zip.writeEntry(MANIFEST_PATH, manifestBytes.inputStream())
            zip.writeEntry(CHECKSUM_PATH, checksumBytes.inputStream())
            hashedSources.forEach { hashed ->
                zip.putNextEntry(deterministicEntry(hashed.source.path))
                val actual = hash(hashed.source.open) { bytes -> zip.write(bytes) }
                zip.closeEntry()
                if (actual != hashed.digest) throw BackupSourceChangedException()
            }
            zip.finish()
            zip.flush()
            counted.flush()
            BackupWriteResult.Success(
                bytesWritten = counted.count,
                sha256 = archiveDigest.digest().toHex(),
            )
        } catch (_: BackupSourceChangedException) {
            BackupWriteResult.Failure("backup_source_changed")
        } catch (_: IOException) {
            BackupWriteResult.Failure("backup_source_unavailable")
        } catch (_: RuntimeException) {
            BackupWriteResult.Failure("backup_write_failed")
        }
    }

    private fun validate(request: BackupPackageRequest): String? {
        if (
            request.formatVersion <= 0 || request.schemaVersion <= 0 ||
            request.appVersion.isBlank() || request.appVersion.length > 128 ||
            request.appVersion.any { it.code < 0x20 }
        ) {
            return "backup_request_invalid"
        }
        try {
            Instant.parse(request.exportedAtUtc)
        } catch (_: DateTimeParseException) {
            return "backup_request_invalid"
        }
        val paths = request.sources.map(BackupPayloadSource::path)
        if (paths.any { !isAllowedPayloadPath(it) }) return "backup_payload_path_not_allowed"
        if (paths.distinct().size != paths.size) return "backup_payload_path_duplicate"
        if (paths.count { it == DATABASE_PATH } != 1) return "backup_database_snapshot_missing"
        return null
    }

    private fun checksumJson(sources: List<HashedSource>): String =
        buildString {
            append("{\"schemaVersion\":1,\"entries\":[")
            sources.forEachIndexed { index, source ->
                if (index > 0) append(',')
                append("{\"path\":\"")
                append(jsonEscape(source.source.path))
                append("\",\"bytes\":")
                append(source.digest.bytes)
                append(",\"sha256\":\"")
                append(source.digest.sha256)
                append("\"}")
            }
            append("]}")
        }

    private fun manifestJson(
        request: BackupPackageRequest,
        checksumSha256: String,
    ): String =
        buildString {
            append("{\"formatVersion\":")
            append(request.formatVersion)
            append(",\"schemaVersion\":")
            append(request.schemaVersion)
            append(",\"appVersion\":\"")
            append(jsonEscape(request.appVersion))
            append("\",\"exportedAtUtc\":\"")
            append(jsonEscape(request.exportedAtUtc))
            append("\",\"encrypted\":false,\"checksums\":{\"path\":\"")
            append(CHECKSUM_PATH)
            append("\",\"sha256\":\"")
            append(checksumSha256)
            append("\"}}")
        }

    private fun hash(
        open: () -> InputStream,
        consume: (ByteArray) -> Unit = {},
    ): SourceDigest {
        val digest = MessageDigest.getInstance(SHA_256)
        var count = 0L
        open().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                if (read == 0) continue
                val bytes = if (read == buffer.size) buffer else buffer.copyOf(read)
                digest.update(bytes)
                consume(bytes)
                count = Math.addExact(count, read.toLong())
            }
        }
        return SourceDigest(count, digest.digest().toHex())
    }

    private fun ZipOutputStream.writeEntry(
        path: String,
        input: InputStream,
    ) {
        putNextEntry(deterministicEntry(path))
        input.use { it.copyTo(this) }
        closeEntry()
    }

    private fun deterministicEntry(path: String) = ZipEntry(path).apply { time = 0L }

    private fun isAllowedPayloadPath(path: String): Boolean =
        path == DATABASE_PATH || RECORDING_PATH.matches(path)

    private fun jsonEscape(value: String): String =
        buildString {
            value.forEach { character ->
                when (character) {
                    '\\' -> append("\\\\")
                    '"' -> append("\\\"")
                    else -> append(character)
                }
            }
        }

    private fun sha256(bytes: ByteArray): String =
        MessageDigest.getInstance(SHA_256).digest(bytes).toHex()

    private fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }

    private data class SourceDigest(
        val bytes: Long,
        val sha256: String,
    )

    private data class HashedSource(
        val source: BackupPayloadSource,
        val digest: SourceDigest,
    )

    private class BackupSourceChangedException : IOException()

    private class CountingOutputStream(output: OutputStream) : FilterOutputStream(output) {
        var count = 0L
            private set

        override fun write(value: Int) {
            out.write(value)
            count = Math.addExact(count, 1L)
        }

        override fun write(
            buffer: ByteArray,
            offset: Int,
            length: Int,
        ) {
            out.write(buffer, offset, length)
            count = Math.addExact(count, length.toLong())
        }
    }

    private companion object {
        const val SHA_256 = "SHA-256"
        const val MANIFEST_PATH = "manifest.json"
        const val CHECKSUM_PATH = "payload/checksums.json"
        const val DATABASE_PATH = "payload/database/loquiris.sqlite"
        val RECORDING_PATH =
            Regex(
                "payload/recordings/[a-f0-9]{64}/(?:segments\\.manifest|segment-[0-9]{5,}\\.(?:adts|commit))",
            )
    }
}
