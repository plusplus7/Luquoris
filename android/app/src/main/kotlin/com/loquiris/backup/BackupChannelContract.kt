package com.loquiris.backup

import java.time.Instant

sealed interface BackupRequestDecodeResult {
    data class Success(
        val request: BackupArchiveRequest,
    ) : BackupRequestDecodeResult

    data class Failure(
        val code: String,
    ) : BackupRequestDecodeResult
}

sealed interface BackupVerificationDecodeResult {
    data class Success(
        val request: BackupVerificationRequest,
    ) : BackupVerificationDecodeResult

    data class Failure(
        val code: String,
    ) : BackupVerificationDecodeResult
}

object BackupChannelContract {
    const val channelName = "com.loquiris/backup_v1"
    private const val version = 1
    private const val maxSegments = 10_000

    fun decodeRequest(arguments: Any?): BackupRequestDecodeResult {
        val values = arguments as? Map<*, *> ?: return invalid()
        if (values["v"] != version) return invalid()
        val operationId = values["operationId"] as? String ?: return invalid()
        val schemaVersion = (values["schemaVersion"] as? Number)?.toInt() ?: return invalid()
        val exportedAtUtc = values["exportedAtUtc"] as? String ?: return invalid()
        val snapshotRelativePath = values["snapshotRelativePath"] as? String ?: return invalid()
        val rawAudioPlan = values["audioPlan"] as? List<*> ?: return invalid()
        if (
            !operationId.matches(Regex("[A-Za-z0-9_-]{1,128}")) || schemaVersion <= 0 ||
            runCatching { Instant.parse(exportedAtUtc) }.isFailure ||
            !snapshotRelativePath.matches(Regex("backup_staging/[A-Za-z0-9_-]{1,128}\\.sqlite")) ||
            rawAudioPlan.size > maxSegments
        ) {
            return invalid()
        }
        val audioPlan =
            rawAudioPlan.map { rawEntry ->
                val entry = rawEntry as? Map<*, *> ?: return invalid()
                val relativePath = entry["relativePath"] as? String ?: return invalid()
                val committedBytes = (entry["committedBytes"] as? Number)?.toLong() ?: return invalid()
                if (
                    committedBytes <= 0 ||
                    !relativePath.matches(Regex("recordings/[a-f0-9]{64}/segment-[0-9]{5,}\\.adts"))
                ) {
                    return invalid()
                }
                BackupAudioPlanEntry(relativePath, committedBytes)
            }
        if (audioPlan.map(BackupAudioPlanEntry::relativePath).distinct().size != audioPlan.size) return invalid()
        return BackupRequestDecodeResult.Success(
            BackupArchiveRequest(
                operationId = operationId,
                schemaVersion = schemaVersion,
                exportedAtUtc = exportedAtUtc,
                snapshotRelativePath = snapshotRelativePath,
                audioPlan = audioPlan,
            ),
        )
    }

    fun decodeVerificationRequest(arguments: Any?): BackupVerificationDecodeResult {
        val values = arguments as? Map<*, *> ?: return verificationInvalid()
        if (values["v"] != version) return verificationInvalid()
        val operationId = values["operationId"] as? String ?: return verificationInvalid()
        val archiveRelativePath = values["archiveRelativePath"] as? String ?: return verificationInvalid()
        val currentSchemaVersion = (values["currentSchemaVersion"] as? Number)?.toInt() ?: return verificationInvalid()
        if (
            !operationId.matches(Regex("[A-Za-z0-9_-]{1,128}")) || currentSchemaVersion <= 0 ||
            !archiveRelativePath.matches(Regex("(?:backups|restore_imports)/[A-Za-z0-9_.-]{1,192}\\.zip"))
        ) {
            return verificationInvalid()
        }
        return BackupVerificationDecodeResult.Success(
            BackupVerificationRequest(operationId, archiveRelativePath, currentSchemaVersion),
        )
    }

    fun decodeRecordingTransfer(arguments: Any?): RestoreRecordingTransfer? {
        val values = arguments as? Map<*, *> ?: return null
        if (values["v"] != version) return null
        val operationId = values["operationId"] as? String ?: return null
        val sourceMeetingId = values["sourceMeetingId"] as? String ?: return null
        val targetMeetingId = values["targetMeetingId"] as? String ?: return null
        val contentFingerprint = values["contentFingerprint"] as? String ?: return null
        if (
            !operationId.matches(Regex("[A-Za-z0-9_-]{1,128}")) ||
            !validMeetingId(sourceMeetingId) || !validMeetingId(targetMeetingId) ||
            !contentFingerprint.matches(Regex("[a-f0-9]{64}"))
        ) {
            return null
        }
        return RestoreRecordingTransfer(
            operationId = operationId,
            sourceMeetingId = sourceMeetingId,
            targetMeetingId = targetMeetingId,
            contentFingerprint = contentFingerprint,
        )
    }

    fun decodeMeetingIds(arguments: Any?): List<String>? {
        val values = arguments as? Map<*, *> ?: return null
        if (values["v"] != version) return null
        val rawIds = values["meetingIds"] as? List<*> ?: return null
        if (rawIds.size > maxSegments) return null
        val ids = rawIds.map { it as? String ?: return null }
        return ids.takeIf { valuesList ->
            valuesList.distinct().size == valuesList.size && valuesList.all(::validMeetingId)
        }
    }

    fun decodeRestorePublication(arguments: Any?): Pair<String, List<String>>? {
        val operationId = decodeOperationId(arguments) ?: return null
        val meetingIds = decodeMeetingIds(arguments) ?: return null
        return operationId to meetingIds
    }

    fun decodeOperationId(arguments: Any?): String? {
        val values = arguments as? Map<*, *> ?: return null
        if (values["v"] != version) return null
        return (values["operationId"] as? String)
            ?.takeIf { it.matches(Regex("[A-Za-z0-9_-]{1,128}")) }
    }

    fun success(result: BackupArchiveResult.Success): Map<String, Any> =
        mapOf(
            "v" to version,
            "ok" to true,
            "receipt" to
                mapOf(
                    "relativePath" to result.relativePath,
                    "sha256" to result.sha256,
                    "bytes" to result.bytes,
                ),
        )

    fun verificationSuccess(result: BackupVerificationResult.Success): Map<String, Any> =
        mapOf(
            "v" to version,
            "ok" to true,
            "verification" to
                mapOf(
                    "formatVersion" to result.formatVersion,
                    "schemaVersion" to result.schemaVersion,
                    "exportedAtUtc" to result.exportedAtUtc,
                    "databaseRelativePath" to result.databaseRelativePath,
                    "checksumIndexRelativePath" to result.checksumIndexRelativePath,
                    "stagingRelativePath" to result.stagingRelativePath,
                    "recordings" to
                        result.recordings.map { recording ->
                            mapOf(
                                "sourceMeetingId" to recording.sourceMeetingId,
                                "storageKey" to recording.storageKey,
                                "contentFingerprint" to recording.contentFingerprint,
                                "segments" to
                                    recording.segments.map { segment ->
                                        mapOf(
                                            "fileName" to segment.fileName,
                                            "committedBytes" to segment.committedBytes,
                                        )
                                    },
                            )
                        },
                ),
        )

    fun failure(code: String): Map<String, Any> =
        mapOf("v" to version, "ok" to false, "failure" to mapOf("code" to code))

    fun recordingPublishSuccess(result: RestoreRecordingPublishResult.Success): Map<String, Any> =
        mapOf("v" to version, "ok" to true, "published" to result.published)

    fun recordingFingerprintsSuccess(fingerprints: Map<String, String?>): Map<String, Any> =
        mapOf("v" to version, "ok" to true, "fingerprints" to fingerprints)

    fun emptySuccess(): Map<String, Any> = mapOf("v" to version, "ok" to true)

    private fun invalid() = BackupRequestDecodeResult.Failure("backup_request_invalid")

    private fun verificationInvalid() = BackupVerificationDecodeResult.Failure("restore_request_invalid")

    private fun validMeetingId(value: String): Boolean =
        value.isNotBlank() && value.toByteArray(Charsets.UTF_8).size <= 512
}
