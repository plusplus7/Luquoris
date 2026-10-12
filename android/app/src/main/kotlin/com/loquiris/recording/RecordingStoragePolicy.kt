package com.loquiris.recording

import java.util.Base64
import java.util.zip.CRC32

sealed interface RecordingStoragePreflightDecision {
    data class Allowed(
        val availableBytes: Long,
        val requiredBytes: Long,
    ) : RecordingStoragePreflightDecision

    data class Denied(
        val code: String,
        val availableBytes: Long?,
        val requiredBytes: Long,
    ) : RecordingStoragePreflightDecision
}

sealed interface RecordingActiveStorageDecision {
    data class Healthy(
        val availableBytes: Long,
    ) : RecordingActiveStorageDecision

    data class Warning(
        val availableBytes: Long,
        val warningThresholdBytes: Long,
    ) : RecordingActiveStorageDecision

    data class Critical(
        val code: String,
        val availableBytes: Long?,
        val requiredBytes: Long,
    ) : RecordingActiveStorageDecision
}

enum class RecordingStorageServiceAction {
    continueRecording,
    showWarning,
    safeFinalize,
    recoverCaptureFailure,
    recoverWithStorageReason,
}

object RecordingStorageServicePolicy {
    fun action(
        pipelineFailed: Boolean,
        storage: RecordingActiveStorageDecision,
    ): RecordingStorageServiceAction {
        if (pipelineFailed) {
            return if (storage is RecordingActiveStorageDecision.Critical) {
                RecordingStorageServiceAction.recoverWithStorageReason
            } else {
                RecordingStorageServiceAction.recoverCaptureFailure
            }
        }
        return when (storage) {
            is RecordingActiveStorageDecision.Critical -> RecordingStorageServiceAction.safeFinalize
            is RecordingActiveStorageDecision.Warning -> RecordingStorageServiceAction.showWarning
            is RecordingActiveStorageDecision.Healthy -> RecordingStorageServiceAction.continueRecording
        }
    }
}

object RecordingStoragePolicy {
    const val fourHourEstimatedBytes = 120_960_000L
    const val startSafetyReserveBytes = 536_870_912L
    const val startRequiredBytes = fourHourEstimatedBytes + startSafetyReserveBytes
    const val warningThresholdBytes = 283_555_456L
    const val criticalThresholdBytes = 3_548_416L

    fun preflight(availableBytes: Long?): RecordingStoragePreflightDecision {
        if (availableBytes == null || availableBytes < 0L) {
            return RecordingStoragePreflightDecision.Denied(
                code = "recording_storage_unavailable",
                availableBytes = null,
                requiredBytes = startRequiredBytes,
            )
        }
        if (availableBytes < startRequiredBytes) {
            return RecordingStoragePreflightDecision.Denied(
                code = "recording_storage_preflight_insufficient",
                availableBytes = availableBytes,
                requiredBytes = startRequiredBytes,
            )
        }
        return RecordingStoragePreflightDecision.Allowed(availableBytes, startRequiredBytes)
    }

    fun active(availableBytes: Long?): RecordingActiveStorageDecision {
        if (availableBytes == null || availableBytes < 0L) {
            return RecordingActiveStorageDecision.Critical(
                code = "recording_storage_unavailable",
                availableBytes = null,
                requiredBytes = criticalThresholdBytes,
            )
        }
        if (availableBytes < criticalThresholdBytes) {
            return RecordingActiveStorageDecision.Critical(
                code = "recording_storage_critically_low",
                availableBytes = availableBytes,
                requiredBytes = criticalThresholdBytes,
            )
        }
        if (availableBytes < warningThresholdBytes) {
            return RecordingActiveStorageDecision.Warning(availableBytes, warningThresholdBytes)
        }
        return RecordingActiveStorageDecision.Healthy(availableBytes)
    }
}

data class RecordingStorageFailureEvent(
    val sessionId: String,
    val code: String,
    val availableBytes: Long?,
    val requiredBytes: Long,
    val mediaElapsedMilliseconds: Long,
    val wallClockEpochMilliseconds: Long,
) {
    init {
        require(sessionId.isNotBlank())
        require(code.isNotBlank())
        require(availableBytes == null || availableBytes >= 0L)
        require(requiredBytes >= 0L)
        require(mediaElapsedMilliseconds >= 0L)
        require(wallClockEpochMilliseconds >= 0L)
    }
}

fun interface RecordingStorageFailureSink {
    fun writeAndSync(frame: String): Boolean
}

class RecordingStorageFailureJournal(
    private val sink: RecordingStorageFailureSink,
) {
    fun persist(event: RecordingStorageFailureEvent): Boolean =
        sink.writeAndSync(RecordingStorageFailureFrame.encode(event))
}

object RecordingStorageFailureFrame {
    fun encode(event: RecordingStorageFailureEvent): String {
        val encoder = Base64.getUrlEncoder().withoutPadding()
        val payload =
            listOf(
                event.wallClockEpochMilliseconds.toString(),
                event.mediaElapsedMilliseconds.toString(),
                event.availableBytes?.toString() ?: "-",
                event.requiredBytes.toString(),
                encoder.encodeToString(event.code.toByteArray(Charsets.UTF_8)),
                encoder.encodeToString(event.sessionId.toByteArray(Charsets.UTF_8)),
            ).joinToString("\t")
        val bytes = payload.toByteArray(Charsets.UTF_8)
        val checksum = CRC32().apply { update(bytes) }.value
        return "v1\t${bytes.size}\t${checksum.toString(16).padStart(8, '0')}\t${encoder.encodeToString(bytes)}"
    }

    fun decode(frame: String): RecordingStorageFailureEvent? =
        try {
            val fields = frame.split('\t')
            if (fields.size != 4 || fields[0] != "v1") return null
            val bytes = Base64.getUrlDecoder().decode(fields[3])
            if (bytes.size != fields[1].toInt()) return null
            if (CRC32().apply { update(bytes) }.value != fields[2].toLong(16)) return null
            val payload = bytes.toString(Charsets.UTF_8).split('\t')
            if (payload.size != 6) return null
            RecordingStorageFailureEvent(
                sessionId = Base64.getUrlDecoder().decode(payload[5]).toString(Charsets.UTF_8),
                code = Base64.getUrlDecoder().decode(payload[4]).toString(Charsets.UTF_8),
                availableBytes = payload[2].takeUnless { it == "-" }?.toLong(),
                requiredBytes = payload[3].toLong(),
                mediaElapsedMilliseconds = payload[1].toLong(),
                wallClockEpochMilliseconds = payload[0].toLong(),
            )
        } catch (_: Exception) {
            null
        }
}
