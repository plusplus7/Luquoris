package com.loquiris.spike

import android.os.SystemClock
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.RandomAccessFile
import kotlin.math.sqrt

data class AuthenticAacTruncationScenario(
    val name: String,
    val sourceFrames: Int,
    val recoveredFrames: Int,
    val recoveredBytes: Int,
    val discardedBytes: Int,
    val lossUs: Long,
    val recoveredPrefixMatches: Boolean,
    val decodedSampleCoverage: Double,
    val decodedRms: Double,
    val sourceSamples: Long,
    val recoveredSamples: Long,
    val committedSamplesMatchFrames: Boolean,
    val codecConfigReloadedFromDisk: Boolean,
    val originalDataBytes: Int,
    val observedDataBytes: Int,
    val originalJournalBytes: Int,
    val observedJournalBytes: Int,
    val completeFramesAfterTruncation: Int,
    val trailingBytesAfterTruncation: Int,
    val maxCommitSyncUs: Long,
)

data class AuthenticAacTruncationMatrixReport(
    val encoderName: String,
    val encoderAudioSpecificConfigHex: String,
    val scenarios: List<AuthenticAacTruncationScenario>,
    val maxLossUs: Long,
    val durabilityBudget: AdtsDurabilityBudget,
) {
    fun toJson(): String {
        val scenarioJson = JSONArray()
        scenarios.forEach { scenario ->
            scenarioJson.put(
                JSONObject()
                    .put("name", scenario.name)
                    .put("sourceFrames", scenario.sourceFrames)
                    .put("recoveredFrames", scenario.recoveredFrames)
                    .put("recoveredBytes", scenario.recoveredBytes)
                    .put("discardedBytes", scenario.discardedBytes)
                    .put("lossMicroseconds", scenario.lossUs)
                    .put("recoveredPrefixMatches", scenario.recoveredPrefixMatches)
                    .put("decodedSampleCoverage", scenario.decodedSampleCoverage)
                    .put("decodedRms", scenario.decodedRms)
                    .put("sourceSamples", scenario.sourceSamples)
                    .put("recoveredSamples", scenario.recoveredSamples)
                    .put("committedSamplesMatchFrames", scenario.committedSamplesMatchFrames)
                    .put("codecConfigReloadedFromDisk", scenario.codecConfigReloadedFromDisk)
                    .put("originalDataBytes", scenario.originalDataBytes)
                    .put("observedDataBytes", scenario.observedDataBytes)
                    .put("originalJournalBytes", scenario.originalJournalBytes)
                    .put("observedJournalBytes", scenario.observedJournalBytes)
                    .put("completeFramesAfterTruncation", scenario.completeFramesAfterTruncation)
                    .put("trailingBytesAfterTruncation", scenario.trailingBytesAfterTruncation)
                    .put("maxCommitSyncMicroseconds", scenario.maxCommitSyncUs),
            )
        }
        return JSONObject()
            .put("schemaVersion", 1)
            .put("fixture", "authentic_mediacodec_aac_controlled_truncation_v1")
            .put("sampleRateHz", AacRoundTripSpike.SAMPLE_RATE_HZ)
            .put("channelCount", AacRoundTripSpike.CHANNEL_COUNT)
            .put("bitRateBitsPerSecond", AacRoundTripSpike.BIT_RATE_BITS_PER_SECOND)
            .put("framesPerCommit", FRAMES_PER_COMMIT)
            .put("encoderName", encoderName)
            .put("encoderAudioSpecificConfigHex", encoderAudioSpecificConfigHex)
            .put("scenarios", scenarioJson)
            .put("maxLossMicroseconds", maxLossUs)
            .put("measuredRiskWindowMicroseconds", durabilityBudget.measuredRiskWindowUs)
            .put("remainingHeadroomMicroseconds", durabilityBudget.remainingHeadroomUs)
            .put("requiredUnmeasuredHeadroomMicroseconds", durabilityBudget.requiredUnmeasuredHeadroomUs)
            .put("hasRequiredUnmeasuredHeadroom", durabilityBudget.hasRequiredUnmeasuredHeadroom)
            .put(
                "limitation",
                "Controlled file truncation of authentic MediaCodec AAC; process kill and force-stop are measured separately.",
            ).toString(2)
    }

    companion object {
        private const val FRAMES_PER_COMMIT = 75
    }
}

class AuthenticAacTruncationMatrixSpike(
    private val root: File,
) {
    fun run(): AuthenticAacTruncationMatrixReport {
        check(!root.exists() || root.deleteRecursively()) { "Unable to clear authentic AAC truncation matrix" }
        check(root.mkdirs()) { "Unable to create authentic AAC truncation matrix" }

        val codec = AacRoundTripSpike()
        val baseFixture = codec.deterministicFixture()
        val source =
            ShortArray(baseFixture.size * FIXTURE_REPETITIONS) { index ->
                baseFixture[index % baseFixture.size]
            }
        val encoded = codec.encode(source)
        check(encoded.accessUnits.size >= FULL_COMMIT_SOURCE_FRAMES) {
            "Authentic AAC encoder emitted too few access units for the truncation matrix"
        }
        val encodedCoverage = encoded.accessUnits.size.toDouble() * SAMPLES_PER_FRAME / source.size
        check(encodedCoverage in 0.98..1.02) { "Authentic AAC encoder coverage was $encodedCoverage" }
        val audioSpecificConfig = encoded.codecSpecificData.first()
        AacAudioSpecificConfigParser.requireAacLc16KhzMono(audioSpecificConfig)
        val wrappedFrames =
            encoded.accessUnits.map { unit ->
                AdtsAacFrameCodec.wrap(
                    accessUnit = unit.bytes,
                    sampleRateHz = AacRoundTripSpike.SAMPLE_RATE_HZ,
                    channelCount = AacRoundTripSpike.CHANNEL_COUNT,
                )
            }
        val prefixBytes = IntArray(wrappedFrames.size + 1)
        wrappedFrames.forEachIndexed { index, frame -> prefixBytes[index + 1] = prefixBytes[index] + frame.size }

        val scenarios =
            listOf(
                runScenario(
                    name = "truncate_tail_after_commit_by_one_byte",
                    sourceFrames = TAIL_SOURCE_FRAMES,
                    expectedRecoveredFrames = BASE_COMMITTED_FRAMES,
                    wrappedFrames = wrappedFrames,
                    encoded = encoded,
                    audioSpecificConfig = audioSpecificConfig,
                    codec = codec,
                    truncateDataTo = prefixBytes[BASE_COMMITTED_FRAMES] + 1,
                ),
                runScenario(
                    name = "truncate_tail_mid_frame",
                    sourceFrames = TAIL_SOURCE_FRAMES,
                    expectedRecoveredFrames = BASE_COMMITTED_FRAMES,
                    wrappedFrames = wrappedFrames,
                    encoded = encoded,
                    audioSpecificConfig = audioSpecificConfig,
                    codec = codec,
                    truncateDataTo = prefixBytes[MID_TAIL_FRAME] + wrappedFrames[MID_TAIL_FRAME].size / 2,
                ),
                runScenario(
                    name = "truncate_tail_at_frame_boundary",
                    sourceFrames = TAIL_SOURCE_FRAMES,
                    expectedRecoveredFrames = BASE_COMMITTED_FRAMES,
                    wrappedFrames = wrappedFrames,
                    encoded = encoded,
                    audioSpecificConfig = audioSpecificConfig,
                    codec = codec,
                    truncateDataTo = prefixBytes[MID_TAIL_FRAME],
                ),
                runScenario(
                    name = "truncate_latest_journal_record",
                    sourceFrames = FULL_COMMIT_SOURCE_FRAMES,
                    expectedRecoveredFrames = BASE_COMMITTED_FRAMES,
                    wrappedFrames = wrappedFrames,
                    encoded = encoded,
                    audioSpecificConfig = audioSpecificConfig,
                    codec = codec,
                    truncateJournalBy = 1,
                ),
                runScenario(
                    name = "truncate_latest_committed_frame",
                    sourceFrames = FULL_COMMIT_SOURCE_FRAMES,
                    expectedRecoveredFrames = BASE_COMMITTED_FRAMES,
                    wrappedFrames = wrappedFrames,
                    encoded = encoded,
                    audioSpecificConfig = audioSpecificConfig,
                    codec = codec,
                    truncateDataBy = 1,
                ),
            )
        val maxLossUs = scenarios.maxOf(AuthenticAacTruncationScenario::lossUs)
        return AuthenticAacTruncationMatrixReport(
            encoderName = encoded.codecName,
            encoderAudioSpecificConfigHex = audioSpecificConfig.toHex(),
            scenarios = scenarios,
            maxLossUs = maxLossUs,
            durabilityBudget =
                AdtsDurabilityBudget.evaluate(
                    maximumUncommittedFrames = (maxLossUs / FRAME_DURATION_US).toInt(),
                    frameDurationUs = FRAME_DURATION_US,
                    maximumCommitSyncUs = scenarios.maxOf(AuthenticAacTruncationScenario::maxCommitSyncUs),
                ),
        )
    }

    private fun runScenario(
        name: String,
        sourceFrames: Int,
        expectedRecoveredFrames: Int,
        wrappedFrames: List<ByteArray>,
        encoded: AacRoundTripSpike.EncodedAudio,
        audioSpecificConfig: ByteArray,
        codec: AacRoundTripSpike,
        truncateDataTo: Int? = null,
        truncateDataBy: Int = 0,
        truncateJournalBy: Int = 0,
    ): AuthenticAacTruncationScenario {
        val directory = File(root, name).apply { check(mkdirs()) }
        val dataFile = File(directory, "active.adts").apply { check(createNewFile()) }
        val journalFile = File(directory, "active.commit").apply { check(createNewFile()) }
        val codecConfigFile = File(directory, "audio-specific-config.bin").apply { check(createNewFile()) }
        RandomAccessFile(codecConfigFile, "rw").use { file ->
            file.write(audioSpecificConfig)
            file.fd.sync()
        }
        val commitSyncMicros = mutableListOf<Long>()
        AdtsDurableCommitStore.open(dataFile, journalFile).use { store ->
            repeat(sourceFrames) { index ->
                store.appendFrame(wrappedFrames[index], SAMPLES_PER_FRAME)
                if ((index + 1) % FRAMES_PER_COMMIT == 0) {
                    val started = SystemClock.elapsedRealtimeNanos()
                    store.commit()
                    commitSyncMicros += (SystemClock.elapsedRealtimeNanos() - started) / 1_000L
                }
            }
        }
        val originalDataBytes = dataFile.length().toInt()
        val originalJournalBytes = journalFile.length().toInt()
        if (truncateDataTo != null || truncateDataBy > 0) {
            RandomAccessFile(dataFile, "rw").use { file ->
                val targetLength = truncateDataTo?.toLong() ?: file.length() - truncateDataBy
                check(targetLength in 0 until file.length()) { "Invalid data truncation offset for $name" }
                file.setLength(targetLength)
                file.fd.sync()
            }
        }
        if (truncateJournalBy > 0) {
            RandomAccessFile(journalFile, "rw").use { file ->
                val targetLength = file.length() - truncateJournalBy
                check(targetLength in 0 until file.length()) { "Invalid journal truncation offset for $name" }
                file.setLength(targetLength)
                file.fd.sync()
            }
        }

        val dataBytes = dataFile.readBytes()
        val journalBytes = journalFile.readBytes()
        val scan = AdtsRecoveryScanner.scan(dataBytes)
        val recovered = AdtsCommittedPrefixRecovery.recover(dataBytes, journalBytes)
        check(recovered.committedFrames == expectedRecoveredFrames) {
            "$name recovered ${recovered.committedFrames} frames; expected $expectedRecoveredFrames"
        }
        val payloads = AdtsAacFrameCodec.unwrapCompleteFrames(dataBytes.copyOf(recovered.committedBytes))
        val expectedPayloads = encoded.accessUnits.take(expectedRecoveredFrames).map(AacRoundTripSpike.AccessUnit::bytes)
        val recoveredPrefixMatches =
            payloads.size == expectedPayloads.size &&
                payloads.zip(expectedPayloads).all { (actual, expected) -> actual.contentEquals(expected) }
        val accessUnits =
            payloads.mapIndexed { index, bytes ->
                AacRoundTripSpike.AccessUnit(
                    bytes = bytes,
                    presentationTimeUs = index.toLong() * SAMPLES_PER_FRAME * 1_000_000L / AacRoundTripSpike.SAMPLE_RATE_HZ,
                )
            }
        val persistedCodecConfig = codecConfigFile.readBytes()
        AacAudioSpecificConfigParser.requireAacLc16KhzMono(persistedCodecConfig)
        val decoded =
            codec.decode(
                AacRoundTripSpike.EncodedAudio(
                    codecName = "recovered-authentic-aac",
                    codecSpecificData = listOf(persistedCodecConfig),
                    accessUnits = accessUnits,
                    elapsedMilliseconds = 0L,
                    mediaEndPresentationTimeUs =
                        accessUnits.size.toLong() * SAMPLES_PER_FRAME * 1_000_000L /
                            AacRoundTripSpike.SAMPLE_RATE_HZ,
                ),
            )
        val expectedSamples = expectedRecoveredFrames * SAMPLES_PER_FRAME
        return AuthenticAacTruncationScenario(
            name = name,
            sourceFrames = sourceFrames,
            recoveredFrames = recovered.committedFrames,
            recoveredBytes = recovered.committedBytes,
            discardedBytes = recovered.uncommittedOrInvalidBytes,
            lossUs =
                (sourceFrames - recovered.committedFrames).toLong() * SAMPLES_PER_FRAME * 1_000_000L /
                    AacRoundTripSpike.SAMPLE_RATE_HZ,
            recoveredPrefixMatches = recoveredPrefixMatches,
            decodedSampleCoverage = decoded.samples.size.toDouble() / expectedSamples,
            decodedRms = decoded.samples.rootMeanSquare(),
            sourceSamples = sourceFrames.toLong() * SAMPLES_PER_FRAME,
            recoveredSamples = recovered.committedSamples,
            committedSamplesMatchFrames =
                recovered.committedSamples == recovered.committedFrames.toLong() * SAMPLES_PER_FRAME,
            codecConfigReloadedFromDisk = persistedCodecConfig.contentEquals(audioSpecificConfig),
            originalDataBytes = originalDataBytes,
            observedDataBytes = dataBytes.size,
            originalJournalBytes = originalJournalBytes,
            observedJournalBytes = journalBytes.size,
            completeFramesAfterTruncation = scan.completeFrames,
            trailingBytesAfterTruncation = dataBytes.size - scan.completeBytes,
            maxCommitSyncUs = commitSyncMicros.maxOrNull() ?: 0L,
        )
    }

    companion object {
        private const val FIXTURE_REPETITIONS = 8
        private const val SAMPLES_PER_FRAME = 1_024
        private const val FRAME_DURATION_US = 64_000L
        private const val FRAMES_PER_COMMIT = 75
        private const val BASE_COMMITTED_FRAMES = FRAMES_PER_COMMIT * 2
        private const val TAIL_SOURCE_FRAMES = BASE_COMMITTED_FRAMES + FRAMES_PER_COMMIT - 1
        private const val FULL_COMMIT_SOURCE_FRAMES = BASE_COMMITTED_FRAMES + FRAMES_PER_COMMIT
        private const val MID_TAIL_FRAME = BASE_COMMITTED_FRAMES + FRAMES_PER_COMMIT / 2
    }
}

private fun ShortArray.rootMeanSquare(): Double =
    if (isEmpty()) 0.0 else sqrt(sumOf { sample -> sample.toDouble() * sample } / size)

private fun ByteArray.toHex(): String =
    joinToString(separator = "") { byte -> "%02x".format(byte.toInt() and 0xFF) }
