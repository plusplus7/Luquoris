package com.loquiris.recording

import android.content.Context
import android.system.Os
import android.system.OsConstants
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.RandomAccessFile
import java.util.Base64
import java.util.zip.CRC32

enum class RecordingInterruptionSource {
    audioFocus,
    microphone,
    call,
    system,
}

enum class RecordingInterruptionPhase {
    began,
    ended,
    confirmationRequired,
    confirmed,
}

enum class RecordingInterruptionSignal {
    transientFocusLost,
    permanentFocusLost,
    focusGained,
    microphoneSilenced,
    microphoneAvailable,
    callModeEntered,
    callModeExited,
    confirmationGranted,
}

data class RecordingInterruptionMarker(
    val source: RecordingInterruptionSource,
    val phase: RecordingInterruptionPhase,
)

data class RecordingInterruptionDecision(
    val shouldPause: Boolean,
    val shouldResume: Boolean,
    val confirmationRequired: Boolean,
    val canUserResume: Boolean,
    val markers: List<RecordingInterruptionMarker>,
)

class RecordingInterruptionPolicy {
    private var focusActive = false
    private var microphoneSilenced = false
    private var callModeActive = false
    private var permanentFocusLoss = false
    private var ownsPause = false
    private var autoResumeEligible = false
    private var requiresConfirmation = false
    private var confirmationSource = RecordingInterruptionSource.microphone

    @Synchronized
    fun onSignal(
        signal: RecordingInterruptionSignal,
        currentState: NativeRecordingState,
    ): RecordingInterruptionDecision {
        val markers = mutableListOf<RecordingInterruptionMarker>()
        var shouldPause = false
        var shouldResume = false
        when (signal) {
            RecordingInterruptionSignal.transientFocusLost -> {
                if (!focusActive) {
                    focusActive = true
                    permanentFocusLoss = false
                    markers += marker(RecordingInterruptionSource.audioFocus, RecordingInterruptionPhase.began)
                }
                if (currentState == NativeRecordingState.recording) {
                    shouldPause = true
                    ownsPause = true
                    autoResumeEligible = true
                }
            }
            RecordingInterruptionSignal.permanentFocusLost -> {
                if (!focusActive) {
                    focusActive = true
                    markers += marker(RecordingInterruptionSource.audioFocus, RecordingInterruptionPhase.began)
                }
                if (!permanentFocusLoss) {
                    permanentFocusLoss = true
                    markers += marker(RecordingInterruptionSource.system, RecordingInterruptionPhase.began)
                }
                autoResumeEligible = false
                if (currentState == NativeRecordingState.recording) {
                    shouldPause = true
                    ownsPause = true
                }
            }
            RecordingInterruptionSignal.focusGained -> {
                if (focusActive) {
                    focusActive = false
                    markers += marker(RecordingInterruptionSource.audioFocus, RecordingInterruptionPhase.ended)
                }
                if (permanentFocusLoss) {
                    permanentFocusLoss = false
                    markers += marker(RecordingInterruptionSource.system, RecordingInterruptionPhase.ended)
                }
            }
            RecordingInterruptionSignal.microphoneSilenced -> {
                if (!microphoneSilenced) {
                    microphoneSilenced = true
                    markers += marker(RecordingInterruptionSource.microphone, RecordingInterruptionPhase.began)
                    requireConfirmation(RecordingInterruptionSource.microphone, markers)
                }
                if (currentState == NativeRecordingState.recording) {
                    shouldPause = true
                    ownsPause = true
                }
            }
            RecordingInterruptionSignal.microphoneAvailable -> {
                if (microphoneSilenced) {
                    microphoneSilenced = false
                    markers += marker(RecordingInterruptionSource.microphone, RecordingInterruptionPhase.ended)
                }
            }
            RecordingInterruptionSignal.callModeEntered -> {
                if (!callModeActive) {
                    callModeActive = true
                    markers += marker(RecordingInterruptionSource.call, RecordingInterruptionPhase.began)
                    requireConfirmation(RecordingInterruptionSource.call, markers)
                }
                if (currentState == NativeRecordingState.recording) {
                    shouldPause = true
                    ownsPause = true
                }
            }
            RecordingInterruptionSignal.callModeExited -> {
                if (callModeActive) {
                    callModeActive = false
                    markers += marker(RecordingInterruptionSource.call, RecordingInterruptionPhase.ended)
                }
            }
            RecordingInterruptionSignal.confirmationGranted -> {
                if (!focusActive && !callModeActive && microphoneSilenced) {
                    microphoneSilenced = false
                    markers += marker(RecordingInterruptionSource.microphone, RecordingInterruptionPhase.ended)
                }
                if (!hasActiveInterruption() && requiresConfirmation) {
                    requiresConfirmation = false
                    markers += marker(confirmationSource, RecordingInterruptionPhase.confirmed)
                    shouldResume = ownsPause && currentState == NativeRecordingState.pausedByInterruption
                }
            }
        }
        if (
            signal != RecordingInterruptionSignal.confirmationGranted &&
            !hasActiveInterruption() &&
            ownsPause &&
            autoResumeEligible &&
            !requiresConfirmation &&
            currentState == NativeRecordingState.pausedByInterruption
        ) {
            shouldResume = true
        }
        if (shouldResume) {
            ownsPause = false
            autoResumeEligible = false
        }
        return RecordingInterruptionDecision(
            shouldPause = shouldPause,
            shouldResume = shouldResume,
            confirmationRequired = requiresConfirmation,
            canUserResume = !hasActiveInterruption() && !requiresConfirmation,
            markers = markers,
        )
    }

    @Synchronized
    fun resetAfterManualResume() {
        if (!hasActiveInterruption() && !requiresConfirmation) {
            ownsPause = false
            autoResumeEligible = false
        }
    }

    @Synchronized
    fun confirmationRequired(): Boolean = requiresConfirmation

    @Synchronized
    fun hasActiveInterruption(): Boolean = focusActive || microphoneSilenced || callModeActive

    @Synchronized
    fun canUserResume(): Boolean = !hasActiveInterruption() && !requiresConfirmation

    @Synchronized
    fun focusReacquisitionRequired(): Boolean = permanentFocusLoss

    private fun requireConfirmation(
        source: RecordingInterruptionSource,
        markers: MutableList<RecordingInterruptionMarker>,
    ) {
        autoResumeEligible = false
        if (requiresConfirmation) return
        requiresConfirmation = true
        confirmationSource = source
        markers += marker(source, RecordingInterruptionPhase.confirmationRequired)
    }

    private fun marker(
        source: RecordingInterruptionSource,
        phase: RecordingInterruptionPhase,
    ) = RecordingInterruptionMarker(source, phase)
}

data class RecordingInterruptionEvent(
    val sessionId: String,
    val source: RecordingInterruptionSource,
    val phase: RecordingInterruptionPhase,
    val mediaElapsedMilliseconds: Long,
    val wallClockEpochMilliseconds: Long,
) {
    init {
        require(sessionId.isNotBlank()) { "sessionId must be non-blank" }
        require(mediaElapsedMilliseconds >= 0) { "media time must be non-negative" }
        require(wallClockEpochMilliseconds >= 0) { "wall time must be non-negative" }
    }
}

interface RecordingInterruptionSink {
    fun appendAndSync(line: String): Boolean
}

class RecordingInterruptionJournal(
    private val sink: RecordingInterruptionSink,
) {
    fun append(event: RecordingInterruptionEvent): Boolean =
        sink.appendAndSync(RecordingInterruptionFrame.encode(event))
}

object RecordingInterruptionFrame {
    fun encode(event: RecordingInterruptionEvent): String {
        val session = Base64.getUrlEncoder().withoutPadding().encodeToString(event.sessionId.toByteArray(Charsets.UTF_8))
        val payload =
            "${event.wallClockEpochMilliseconds}\t${event.mediaElapsedMilliseconds}\t${event.source.name}\t${event.phase.name}\t$session"
        val bytes = payload.toByteArray(Charsets.UTF_8)
        val checksum = CRC32().apply { update(bytes) }.value
        return "v1\t${bytes.size}\t${checksum.toString(16).padStart(8, '0')}\t${Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)}"
    }

    fun decode(frame: String): RecordingInterruptionEvent? =
        try {
            val fields = frame.split('\t')
            if (fields.size != 4 || fields[0] != "v1") return null
            val bytes = Base64.getUrlDecoder().decode(fields[3])
            if (bytes.size != fields[1].toInt()) return null
            if (CRC32().apply { update(bytes) }.value != fields[2].toLong(16)) return null
            val payload = bytes.toString(Charsets.UTF_8).split('\t')
            if (payload.size != 5) return null
            RecordingInterruptionEvent(
                sessionId = Base64.getUrlDecoder().decode(payload[4]).toString(Charsets.UTF_8),
                source = RecordingInterruptionSource.valueOf(payload[2]),
                phase = RecordingInterruptionPhase.valueOf(payload[3]),
                mediaElapsedMilliseconds = payload[1].toLong(),
                wallClockEpochMilliseconds = payload[0].toLong(),
            )
        } catch (_: IllegalArgumentException) {
            null
        }
}

class AppPrivateRecordingInterruptionSink(
    context: Context,
    sessionId: String,
) : RecordingInterruptionSink {
    private val delegate =
        RecoverableInterruptionFileSink(
            File(File(context.applicationContext.filesDir, "recording-events"), "${sessionId.sha256Hex()}.interruptions"),
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

class RecoverableInterruptionFileSink(
    private val journalFile: File,
    private val directorySync: (File) -> Boolean,
) : RecordingInterruptionSink {
    override fun appendAndSync(line: String): Boolean {
        val encoded = line.toByteArray(Charsets.UTF_8)
        if (encoded.size > MAX_RECORD_BYTES || RecordingInterruptionFrame.decode(line) == null) return false
        return try {
            val directory = requireNotNull(journalFile.parentFile)
            if (!directory.exists() && !directory.mkdirs()) return false
            if (!directory.isDirectory) return false
            val existed = journalFile.exists()
            val last = if (existed) recoverValidPrefix() else null
            if (last == line) {
                RandomAccessFile(journalFile, "rw").use { it.fd.sync() }
            } else {
                FileOutputStream(journalFile, true).use {
                    it.write(encoded)
                    it.write('\n'.code)
                    it.fd.sync()
                }
            }
            directorySync(requireNotNull(directory.parentFile)) && directorySync(directory)
        } catch (_: IOException) {
            false
        } catch (_: RuntimeException) {
            false
        }
    }

    private fun recoverValidPrefix(): String? =
        RandomAccessFile(journalFile, "rw").use { file ->
            var validEnd = 0L
            var last: String? = null
            while (file.filePointer < file.length()) {
                val record = ByteArrayOutputStream()
                var complete = false
                while (file.filePointer < file.length() && record.size() <= MAX_RECORD_BYTES) {
                    val byte = file.read()
                    if (byte == '\n'.code) {
                        complete = true
                        break
                    }
                    record.write(byte)
                }
                if (!complete || record.size() > MAX_RECORD_BYTES) break
                val line = record.toString(Charsets.UTF_8.name())
                if (RecordingInterruptionFrame.decode(line) == null) break
                validEnd = file.filePointer
                last = line
            }
            if (validEnd < file.length()) {
                file.setLength(validEnd)
                file.fd.sync()
            }
            last
        }

    private companion object {
        const val MAX_RECORD_BYTES = 16 * 1_024
    }
}
