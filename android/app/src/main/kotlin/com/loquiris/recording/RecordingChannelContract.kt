package com.loquiris.recording

object RecordingChannelContract {
    const val channelName = "com.loquiris/recording_control_v1"
    const val version = 1

    fun accepted(commandId: String): Map<String, Any?> =
        mapOf(
            "v" to version,
            "ok" to true,
            "commandId" to commandId,
        )

    fun receipt(receipt: NativeRecordingCommandReceipt): Map<String, Any?> =
        mapOf(
            "v" to version,
            "ok" to true,
            "receipt" to
                mapOf(
                    "state" to receipt.state.name,
                    "snapshot" to receipt.snapshot?.let(::snapshotBody),
                    "failure" to receipt.failureCode?.let {
                        failureBody(it, receipt.availableBytes, receipt.requiredBytes)
                    },
                ),
        )

    fun snapshot(
        snapshot: NativeRecordingSnapshot,
        inputHealth: AudioInputHealthSnapshot? = null,
    ): Map<String, Any?> =
        mapOf(
            "v" to version,
            "ok" to true,
            "snapshot" to snapshotBody(snapshot, inputHealth),
        )

    fun recoveryInventory(inventory: RecordingRecoveryInventory): Map<String, Any?> =
        mapOf(
            "v" to version,
            "ok" to true,
            "recovery" to
                mapOf(
                    "sessions" to
                        inventory.sessions.map { session ->
                            mapOf(
                                "meetingId" to session.meetingId,
                                "storageKey" to session.storageKey,
                                "sampleRateHz" to session.sampleRateHz,
                                "integrityState" to session.integrityState.name,
                                "diagnostics" to
                                    session.diagnostics.map { diagnostic ->
                                        mapOf(
                                            "code" to diagnostic.code,
                                            "segmentSequence" to diagnostic.segmentSequence,
                                        )
                                    },
                                "rawExportSegments" to
                                    session.rawExportSegments.map { segment ->
                                        mapOf(
                                            "sequence" to segment.sequence,
                                            "relativePath" to segment.relativePath,
                                            "committedBytes" to segment.committedBytes,
                                        )
                                    },
                                "segments" to
                                    session.segments.map { segment ->
                                        mapOf(
                                            "sequence" to segment.sequence,
                                            "relativePath" to segment.relativePath,
                                            "startSample" to segment.startSample,
                                            "committedSamples" to segment.committedSamples,
                                            "committedBytes" to segment.committedBytes,
                                            "state" to segment.state.name,
                                        )
                                    },
                            )
                        },
                    "deletedIncompleteDerivedFiles" to inventory.deletedIncompleteDerivedFiles,
                    "issueCodes" to inventory.issueCodes,
                    "liveMeetingIds" to inventory.liveMeetingIds,
                    "invalidStorageKeys" to inventory.invalidStorageKeys,
                ),
        )

    fun failure(
        code: String,
        availableBytes: Long? = null,
        requiredBytes: Long? = null,
    ): Map<String, Any?> =
        mapOf(
            "v" to version,
            "ok" to false,
            "failure" to failureBody(code, availableBytes, requiredBytes),
        )

    private fun snapshotBody(
        snapshot: NativeRecordingSnapshot,
        inputHealth: AudioInputHealthSnapshot? = null,
    ): Map<String, Any?> =
        mapOf(
            "sessionId" to snapshot.sessionId,
            "state" to snapshot.state.name,
            "elapsedMilliseconds" to snapshot.elapsedMilliseconds,
            "bytesWritten" to snapshot.bytesWritten,
            "revision" to snapshot.revision,
            "inputHealth" to inputHealth?.let(::inputHealthBody),
        )

    private fun inputHealthBody(snapshot: AudioInputHealthSnapshot): Map<String, Any?> =
        mapOf(
            "readCalls" to snapshot.readCalls,
            "pcmBytes" to snapshot.pcmBytes,
            "shortReads" to snapshot.shortReads,
            "zeroReads" to snapshot.zeroReads,
            "errorReads" to snapshot.errorReads,
            "maximumReadGapNanos" to snapshot.maximumReadGapNanos,
            "timestampRegressions" to snapshot.timestampRegressions,
        )

    private fun failureBody(code: String, availableBytes: Long?, requiredBytes: Long?): Map<String, Any?> =
        mapOf("code" to code, "availableBytes" to availableBytes, "requiredBytes" to requiredBytes)
}
