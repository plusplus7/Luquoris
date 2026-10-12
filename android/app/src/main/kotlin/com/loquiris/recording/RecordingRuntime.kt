package com.loquiris.recording

import android.content.Context
import android.system.Os
import android.system.OsConstants
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.RandomAccessFile
import java.security.MessageDigest
import java.util.Base64
import java.util.Locale
import java.util.zip.CRC32
import kotlin.math.max

data class RecordingProgressSnapshot(
    val elapsedMilliseconds: Long,
    val bytesWritten: Long,
)

class MonotonicRecordingTimer(
    initialElapsedMilliseconds: Long = 0,
    private val elapsedRealtimeMillis: () -> Long,
) {
    private var accumulatedMilliseconds = initialElapsedMilliseconds
    private var runningSinceMilliseconds: Long? = null
    private var lastReportedMilliseconds = initialElapsedMilliseconds

    init {
        require(initialElapsedMilliseconds >= 0) { "initial duration must be non-negative" }
    }

    @Synchronized
    fun resume() = resumeAt(elapsedRealtimeMillis())

    @Synchronized
    fun resumeAt(captureBoundaryElapsedRealtimeMillis: Long) {
        if (runningSinceMilliseconds == null) {
            runningSinceMilliseconds = max(0, captureBoundaryElapsedRealtimeMillis)
        }
    }

    @Synchronized
    fun pause() = pauseAt(elapsedRealtimeMillis())

    @Synchronized
    fun pauseAt(captureBoundaryElapsedRealtimeMillis: Long) {
        if (runningSinceMilliseconds == null) return
        accumulatedMilliseconds =
            max(
                lastReportedMilliseconds,
                currentElapsedMilliseconds(max(0, captureBoundaryElapsedRealtimeMillis)),
            )
        runningSinceMilliseconds = null
    }

    @Synchronized
    fun snapshot(bytesWritten: Long): RecordingProgressSnapshot {
        require(bytesWritten >= 0) { "bytesWritten must be non-negative" }
        val elapsed = currentElapsedMilliseconds(elapsedRealtimeMillis())
        lastReportedMilliseconds = max(lastReportedMilliseconds, elapsed)
        return RecordingProgressSnapshot(
            elapsedMilliseconds = lastReportedMilliseconds,
            bytesWritten = bytesWritten,
        )
    }

    private fun currentElapsedMilliseconds(nowElapsedRealtimeMillis: Long): Long {
        val runningSince = runningSinceMilliseconds ?: return accumulatedMilliseconds
        val delta = max(0, nowElapsedRealtimeMillis - runningSince)
        return if (Long.MAX_VALUE - accumulatedMilliseconds < delta) {
            Long.MAX_VALUE
        } else {
            accumulatedMilliseconds + delta
        }
    }
}

object RecordingNotificationFormatter {
    fun duration(elapsedMilliseconds: Long): String {
        val totalSeconds = max(0, elapsedMilliseconds) / 1_000
        val hours = totalSeconds / 3_600
        val minutes = totalSeconds % 3_600 / 60
        val seconds = totalSeconds % 60
        return String.format(Locale.ROOT, "%02d:%02d:%02d", hours, minutes, seconds)
    }

    fun bytes(bytesWritten: Long): String {
        val safeBytes = max(0, bytesWritten)
        if (safeBytes < KIBIBYTE) return "$safeBytes B"
        if (safeBytes < MEBIBYTE) {
            return String.format(Locale.ROOT, "%.1f KiB", safeBytes.toDouble() / KIBIBYTE)
        }
        return String.format(Locale.ROOT, "%.1f MiB", safeBytes.toDouble() / MEBIBYTE)
    }

    private const val KIBIBYTE = 1_024L
    private const val MEBIBYTE = KIBIBYTE * KIBIBYTE
}

data class RecordingBookmarkEvent(
    val sessionId: String,
    val mediaElapsedMilliseconds: Long,
    val wallClockEpochMilliseconds: Long,
) {
    init {
        require(sessionId.isNotBlank()) { "sessionId must be non-blank" }
        require(mediaElapsedMilliseconds >= 0) { "media time must be non-negative" }
        require(wallClockEpochMilliseconds >= 0) { "wall time must be non-negative" }
    }
}

interface RecordingBookmarkSink {
    fun appendAndSync(line: String): Boolean
}

class RecordingBookmarkJournal(
    private val sink: RecordingBookmarkSink,
) {
    fun append(event: RecordingBookmarkEvent): Boolean {
        return sink.appendAndSync(RecordingBookmarkFrame.encode(event))
    }
}

object RecordingBookmarkFrame {
    fun encode(event: RecordingBookmarkEvent): String {
        val encodedSession =
            Base64.getUrlEncoder().withoutPadding().encodeToString(event.sessionId.toByteArray(Charsets.UTF_8))
        val payload =
            "${event.wallClockEpochMilliseconds}\t${event.mediaElapsedMilliseconds}\t$encodedSession"
        val payloadBytes = payload.toByteArray(Charsets.UTF_8)
        val checksum = CRC32().apply { update(payloadBytes) }.value
        val encodedPayload = Base64.getUrlEncoder().withoutPadding().encodeToString(payloadBytes)
        return "v1\t${payloadBytes.size}\t${checksum.toString(16).padStart(8, '0')}\t$encodedPayload"
    }

    fun decode(frame: String): RecordingBookmarkEvent? =
        try {
            val fields = frame.split('\t')
            if (fields.size != 4 || fields[0] != "v1") return null
            val expectedLength = fields[1].toInt()
            val expectedChecksum = fields[2].toLong(16)
            val payloadBytes = Base64.getUrlDecoder().decode(fields[3])
            if (payloadBytes.size != expectedLength) return null
            val checksum = CRC32().apply { update(payloadBytes) }.value
            if (checksum != expectedChecksum) return null
            val payload = payloadBytes.toString(Charsets.UTF_8).split('\t')
            if (payload.size != 3) return null
            RecordingBookmarkEvent(
                sessionId = Base64.getUrlDecoder().decode(payload[2]).toString(Charsets.UTF_8),
                mediaElapsedMilliseconds = payload[1].toLong(),
                wallClockEpochMilliseconds = payload[0].toLong(),
            )
        } catch (_: IllegalArgumentException) {
            null
        }
}

class RecordingSessionRuntime(
    private val machine: PersistedRecordingStateMachine,
    private val timer: MonotonicRecordingTimer,
    private val bytesWritten: () -> Long,
    private val bookmarkJournal: RecordingBookmarkJournal,
    private val wallClockEpochMillis: () -> Long,
    private val interruptionJournal: RecordingInterruptionJournal? = null,
) {
    @Synchronized
    fun captureStarted(captureBoundaryElapsedRealtimeMillis: Long? = null): RecordingCommandResult {
        val result = machine.markRecording()
        if (result is RecordingCommandResult.Success && result.snapshot.state == NativeRecordingState.recording) {
            if (captureBoundaryElapsedRealtimeMillis == null) {
                timer.resume()
            } else {
                timer.resumeAt(captureBoundaryElapsedRealtimeMillis)
            }
        }
        return result
    }

    @Synchronized
    fun pause(captureBoundaryElapsedRealtimeMillis: Long? = null): RecordingCommandResult {
        val result = machine.pause()
        if (result is RecordingCommandResult.Success && result.snapshot.state == NativeRecordingState.pausedByUser) {
            if (captureBoundaryElapsedRealtimeMillis == null) {
                timer.pause()
            } else {
                timer.pauseAt(captureBoundaryElapsedRealtimeMillis)
            }
            val progressResult = publishProgress()
            if (progressResult is RecordingCommandResult.Failure) {
                machine.markRecoverable()
            }
            return progressResult
        }
        return result
    }

    @Synchronized
    fun resume(captureBoundaryElapsedRealtimeMillis: Long? = null): RecordingCommandResult {
        val result = machine.resume()
        if (result is RecordingCommandResult.Success && result.snapshot.state == NativeRecordingState.recording) {
            if (captureBoundaryElapsedRealtimeMillis == null) {
                timer.resume()
            } else {
                timer.resumeAt(captureBoundaryElapsedRealtimeMillis)
            }
        }
        return result
    }

    @Synchronized
    fun pauseForInterruption(captureBoundaryElapsedRealtimeMillis: Long? = null): RecordingCommandResult {
        val result = machine.pauseForInterruption()
        if (
            result is RecordingCommandResult.Success &&
            result.snapshot.state == NativeRecordingState.pausedByInterruption
        ) {
            if (captureBoundaryElapsedRealtimeMillis == null) {
                timer.pause()
            } else {
                timer.pauseAt(captureBoundaryElapsedRealtimeMillis)
            }
            val progressResult = publishProgress()
            if (progressResult is RecordingCommandResult.Failure) {
                machine.markRecoverable()
            }
            return progressResult
        }
        return result
    }

    @Synchronized
    fun resumeFromInterruption(captureBoundaryElapsedRealtimeMillis: Long? = null): RecordingCommandResult {
        val result = machine.resumeFromInterruption()
        if (result is RecordingCommandResult.Success && result.snapshot.state == NativeRecordingState.recording) {
            if (captureBoundaryElapsedRealtimeMillis == null) {
                timer.resume()
            } else {
                timer.resumeAt(captureBoundaryElapsedRealtimeMillis)
            }
        }
        return result
    }

    @Synchronized
    fun publishProgress(): RecordingCommandResult {
        val progress = snapshot()
        return machine.updateProgress(
            elapsedMilliseconds = progress.elapsedMilliseconds,
            bytesWritten = progress.bytesWritten,
        )
    }

    @Synchronized
    fun stop(captureBoundaryElapsedRealtimeMillis: Long): RecordingCommandResult {
        timer.pauseAt(captureBoundaryElapsedRealtimeMillis)
        val progressResult = publishProgress()
        if (progressResult is RecordingCommandResult.Failure) {
            machine.markRecoverable()
            return progressResult
        }
        val stopResult = machine.stop()
        if (stopResult is RecordingCommandResult.Failure) machine.markRecoverable()
        return stopResult
    }

    @Synchronized
    fun snapshot(): RecordingProgressSnapshot = timer.snapshot(max(0, bytesWritten()))

    @Synchronized
    fun bookmark(): Boolean {
        val state = machine.snapshot().state
        if (state !in bookmarkableStates) return false
        if (publishProgress() is RecordingCommandResult.Failure) return false
        val snapshot = machine.snapshot()
        val sessionId = snapshot.sessionId ?: return false
        return bookmarkJournal.append(
            RecordingBookmarkEvent(
                sessionId = sessionId,
                mediaElapsedMilliseconds = snapshot.elapsedMilliseconds,
                wallClockEpochMilliseconds = max(0, wallClockEpochMillis()),
            ),
        )
    }

    @Synchronized
    fun recordInterruption(
        source: RecordingInterruptionSource,
        phase: RecordingInterruptionPhase,
    ): Boolean {
        val journal = interruptionJournal ?: return false
        val sessionId = machine.snapshot().sessionId ?: return false
        val progress = snapshot()
        return journal.append(
            RecordingInterruptionEvent(
                sessionId = sessionId,
                source = source,
                phase = phase,
                mediaElapsedMilliseconds = progress.elapsedMilliseconds,
                wallClockEpochMilliseconds = max(0, wallClockEpochMillis()),
            ),
        )
    }

    private companion object {
        val bookmarkableStates =
            setOf(
                NativeRecordingState.recording,
                NativeRecordingState.pausedByUser,
                NativeRecordingState.pausedByInterruption,
            )
    }
}

class AppPrivateRecordingBookmarkSink(
    context: Context,
    sessionId: String,
) : RecordingBookmarkSink {
    private val delegate =
        RecoverableBookmarkFileSink(
            journalFile =
                File(
                    File(context.applicationContext.filesDir, "recording-events"),
                    "${sessionId.sha256Hex()}.bookmarks",
                ),
            directorySync = ::syncDirectory,
        )

    override fun appendAndSync(line: String): Boolean = delegate.appendAndSync(line)

    private fun syncDirectory(directory: File): Boolean =
        try {
            val descriptor = Os.open(directory.absolutePath, OsConstants.O_RDONLY, 0)
            try {
                Os.fsync(descriptor)
            } finally {
                Os.close(descriptor)
            }
            true
        } catch (_: RuntimeException) {
            false
        }
}

class RecoverableBookmarkFileSink(
    private val journalFile: File,
    private val directorySync: (File) -> Boolean,
) : RecordingBookmarkSink {
    override fun appendAndSync(line: String): Boolean {
        val encodedLine = line.toByteArray(Charsets.UTF_8)
        if (encodedLine.size > MAX_RECORD_BYTES || RecordingBookmarkFrame.decode(line) == null) return false
        return try {
            val directory = requireNotNull(journalFile.parentFile)
            if (!directory.exists() && !directory.mkdirs()) return false
            if (!directory.isDirectory) return false

            val fileExisted = journalFile.exists()
            val lastFrame = if (fileExisted) recoverValidPrefix() else null
            if (lastFrame == line) {
                RandomAccessFile(journalFile, "rw").use { file -> file.fd.sync() }
            } else {
                FileOutputStream(journalFile, true).use { output ->
                    output.write(encodedLine)
                    output.write('\n'.code)
                    output.fd.sync()
                }
            }
            if (!directorySync(requireNotNull(directory.parentFile))) return false
            if (!directorySync(directory)) return false
            true
        } catch (_: IOException) {
            false
        } catch (_: RuntimeException) {
            false
        }
    }

    private fun recoverValidPrefix(): String? =
        RandomAccessFile(journalFile, "rw").use { file ->
            var validEnd = 0L
            var lastFrame: String? = null
            while (file.filePointer < file.length()) {
                val record = ByteArrayOutputStream()
                var complete = false
                var oversized = false
                while (file.filePointer < file.length()) {
                    val byte = file.read()
                    if (byte == '\n'.code) {
                        complete = true
                        break
                    }
                    if (record.size() >= MAX_RECORD_BYTES) {
                        oversized = true
                        break
                    }
                    record.write(byte)
                }
                if (oversized || !complete) break
                val line = record.toString(Charsets.UTF_8.name())
                if (RecordingBookmarkFrame.decode(line) == null) break
                validEnd = file.filePointer
                lastFrame = line
            }
            if (validEnd < file.length()) {
                file.setLength(validEnd)
                file.fd.sync()
            }
            lastFrame
        }

    private companion object {
        const val MAX_RECORD_BYTES = 16 * 1_024
    }
}

internal fun String.sha256Hex(): String =
    MessageDigest
        .getInstance("SHA-256")
        .digest(toByteArray(Charsets.UTF_8))
        .joinToString(separator = "") { byte -> "%02x".format(byte.toInt() and 0xff) }
