package com.loquiris.spike

import android.os.SystemClock
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

data class AdtsDurabilityScenario(
    val name: String,
    val generatedFrames: Int,
    val expectedCommittedFrames: Int,
    val recoveredFrames: Int,
    val recoveredBytes: Int,
    val discardedBytes: Int,
    val lossUs: Long,
    val committedPrefixPreserved: Boolean,
)

data class AdtsDurabilityReport(
    val scenarios: List<AdtsDurabilityScenario>,
    val commitSyncMicros: List<Long>,
    val maxLossUs: Long,
    val durabilityBudget: AdtsDurabilityBudget,
) {
    fun toJson(): String {
        val scenarioJson = JSONArray()
        scenarios.forEach { scenario ->
            scenarioJson.put(
                JSONObject()
                    .put("name", scenario.name)
                    .put("generatedFrames", scenario.generatedFrames)
                    .put("expectedCommittedFrames", scenario.expectedCommittedFrames)
                    .put("recoveredFrames", scenario.recoveredFrames)
                    .put("recoveredBytes", scenario.recoveredBytes)
                    .put("discardedBytes", scenario.discardedBytes)
                    .put("lossUs", scenario.lossUs)
                    .put("committedPrefixPreserved", scenario.committedPrefixPreserved),
            )
        }
        val syncJson = JSONArray()
        commitSyncMicros.forEach(syncJson::put)
        return JSONObject()
            .put("schemaVersion", 1)
            .put("fixture", "synthetic_adts_fixed_frame_v1")
            .put("sampleRateHz", SAMPLE_RATE_HZ)
            .put("samplesPerFrame", SAMPLES_PER_FRAME)
            .put("framesPerCommit", FRAMES_PER_COMMIT)
            .put("commitDurationUs", COMMIT_DURATION_US)
            .put("scenarios", scenarioJson)
            .put("commitSyncMicros", syncJson)
            .put("maxCommitSyncMicros", commitSyncMicros.maxOrNull() ?: 0L)
            .put("maxLossUs", maxLossUs)
            .put("measuredRiskWindowUs", durabilityBudget.measuredRiskWindowUs)
            .put("remainingHeadroomUs", durabilityBudget.remainingHeadroomUs)
            .put("requiredUnmeasuredHeadroomUs", durabilityBudget.requiredUnmeasuredHeadroomUs)
            .put("hasRequiredUnmeasuredHeadroom", durabilityBudget.hasRequiredUnmeasuredHeadroom)
            .put(
                "limitation",
                "Synthetic ADTS and controlled file truncation only; no MediaCodec payload, process kill, force-stop, playback, or target-device evidence.",
            ).toString(2)
    }

    companion object {
        private const val SAMPLE_RATE_HZ = 16_000
        private const val SAMPLES_PER_FRAME = 1_024
        private const val FRAMES_PER_COMMIT = 75
        private const val COMMIT_DURATION_US = 4_800_000L
    }
}

data class AdtsDurabilityBudget(
    val measuredRiskWindowUs: Long,
    val remainingHeadroomUs: Long,
    val requiredUnmeasuredHeadroomUs: Long,
) {
    val hasRequiredUnmeasuredHeadroom: Boolean
        get() = remainingHeadroomUs >= requiredUnmeasuredHeadroomUs

    companion object {
        fun evaluate(
            maximumUncommittedFrames: Int,
            frameDurationUs: Long,
            maximumCommitSyncUs: Long,
        ): AdtsDurabilityBudget {
            require(maximumUncommittedFrames >= 0)
            require(frameDurationUs > 0L)
            require(maximumCommitSyncUs >= 0L)
            val mediaRiskUs = Math.multiplyExact(maximumUncommittedFrames.toLong(), frameDurationUs)
            val measuredRiskWindowUs = Math.addExact(mediaRiskUs, maximumCommitSyncUs)
            return AdtsDurabilityBudget(
                measuredRiskWindowUs = measuredRiskWindowUs,
                remainingHeadroomUs = FIVE_SECONDS_US - measuredRiskWindowUs,
                requiredUnmeasuredHeadroomUs = REQUIRED_UNMEASURED_HEADROOM_US,
            )
        }

        private const val FIVE_SECONDS_US = 5_000_000L
        private const val REQUIRED_UNMEASURED_HEADROOM_US = 100_000L
    }
}

class AdtsDurabilitySpike(
    private val root: File,
) {
    fun run(): AdtsDurabilityReport {
        check(root.mkdirs() || root.isDirectory) { "Unable to create spike directory" }
        val syncMicros = mutableListOf<Long>()
        val scenarios =
            listOf(8, 75, 78, 80).map { tailFrames ->
                val files = writeCase("tail-$tailFrames", BASE_COMMITTED_FRAMES + tailFrames, syncMicros)
                recoverScenario(
                    name = "crash_tail_${tailFrames}_frames",
                    generatedFrames = BASE_COMMITTED_FRAMES + tailFrames,
                    expectedCommittedFrames = ((BASE_COMMITTED_FRAMES + tailFrames) / FRAMES_PER_COMMIT) * FRAMES_PER_COMMIT,
                    dataBytes = files.data.readBytes(),
                    journalBytes = files.journal.readBytes(),
                )
            }.toMutableList()

        val truncationFiles = writeCase("tail-truncation", BASE_COMMITTED_FRAMES + 75, syncMicros)
        listOf(1, 64, 127).forEach { truncatedBytes ->
            val bytes = truncationFiles.data.readBytes().copyOf(truncationFiles.data.length().toInt() - truncatedBytes)
            scenarios +=
                recoverScenario(
                    name = "truncate_uncommitted_tail_${truncatedBytes}_bytes",
                    generatedFrames = BASE_COMMITTED_FRAMES + 75,
                    expectedCommittedFrames = BASE_COMMITTED_FRAMES,
                    dataBytes = bytes,
                    journalBytes = truncationFiles.journal.readBytes(),
                )
        }

        val tornJournalFiles = writeCase("torn-journal", BASE_COMMITTED_FRAMES + FRAMES_PER_COMMIT, syncMicros)
        val completeJournal = tornJournalFiles.journal.readBytes()
        scenarios +=
            recoverScenario(
                name = "truncate_latest_journal_record",
                generatedFrames = BASE_COMMITTED_FRAMES + FRAMES_PER_COMMIT,
                expectedCommittedFrames = BASE_COMMITTED_FRAMES,
                dataBytes = tornJournalFiles.data.readBytes(),
                journalBytes = completeJournal.copyOf(completeJournal.size - 1),
            )

        val maxLossUs = scenarios.maxOf(AdtsDurabilityScenario::lossUs)
        return AdtsDurabilityReport(
            scenarios = scenarios,
            commitSyncMicros = syncMicros,
            maxLossUs = maxLossUs,
            durabilityBudget =
                AdtsDurabilityBudget.evaluate(
                    maximumUncommittedFrames = (maxLossUs / FRAME_DURATION_US).toInt(),
                    frameDurationUs = FRAME_DURATION_US,
                    maximumCommitSyncUs = syncMicros.maxOrNull() ?: 0L,
                ),
        )
    }

    private fun writeCase(
        name: String,
        frameCount: Int,
        syncMicros: MutableList<Long>,
    ): CaseFiles {
        val dataFile = File(root, "$name.adts").also(::replaceWithEmptyFile)
        val journalFile = File(root, "$name.commit").also(::replaceWithEmptyFile)
        AdtsDurableCommitStore.open(dataFile, journalFile).use { store ->
            repeat(frameCount) { frameIndex ->
                store.appendFrame(syntheticFrame(frameIndex), SAMPLES_PER_FRAME)
                if ((frameIndex + 1) % FRAMES_PER_COMMIT == 0) {
                    val started = SystemClock.elapsedRealtimeNanos()
                    store.commit()
                    syncMicros += (SystemClock.elapsedRealtimeNanos() - started) / 1_000L
                }
            }
        }
        return CaseFiles(dataFile, journalFile)
    }

    private fun recoverScenario(
        name: String,
        generatedFrames: Int,
        expectedCommittedFrames: Int,
        dataBytes: ByteArray,
        journalBytes: ByteArray,
    ): AdtsDurabilityScenario {
        val recovered = AdtsCommittedPrefixRecovery.recover(dataBytes, journalBytes)
        return AdtsDurabilityScenario(
            name = name,
            generatedFrames = generatedFrames,
            expectedCommittedFrames = expectedCommittedFrames,
            recoveredFrames = recovered.committedFrames,
            recoveredBytes = recovered.committedBytes,
            discardedBytes = recovered.uncommittedOrInvalidBytes,
            lossUs = (generatedFrames - recovered.committedFrames).toLong() * FRAME_DURATION_US,
            committedPrefixPreserved = recovered.committedFrames == expectedCommittedFrames,
        )
    }

    private fun syntheticFrame(frameIndex: Int): ByteArray =
        ByteArray(FRAME_BYTES) { (frameIndex and 0xFF).toByte() }.also { frame ->
            frame[0] = 0xFF.toByte()
            frame[1] = 0xF1.toByte()
            frame[2] = 0x60.toByte()
            frame[3] = ((FRAME_BYTES ushr 11) and 0x03).toByte()
            frame[4] = ((FRAME_BYTES ushr 3) and 0xFF).toByte()
            frame[5] = (((FRAME_BYTES and 0x07) shl 5) or 0x1F).toByte()
            frame[6] = 0xFC.toByte()
        }

    private fun replaceWithEmptyFile(file: File) {
        if (file.exists()) check(file.delete()) { "Unable to replace spike file" }
        check(file.createNewFile()) { "Unable to create spike file" }
    }

    private data class CaseFiles(
        val data: File,
        val journal: File,
    )

    companion object {
        private const val SAMPLE_RATE_HZ = 16_000
        private const val SAMPLES_PER_FRAME = 1_024
        private const val FRAME_DURATION_US = 64_000L
        private const val FRAMES_PER_COMMIT = 75
        private const val BASE_COMMITTED_FRAMES = FRAMES_PER_COMMIT * 2
        private const val FRAME_BYTES = 128
    }
}
