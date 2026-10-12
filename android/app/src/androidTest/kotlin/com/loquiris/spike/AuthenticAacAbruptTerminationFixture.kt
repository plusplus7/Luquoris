package com.loquiris.spike

import android.os.Bundle
import org.json.JSONObject
import java.io.File
import java.io.RandomAccessFile
import kotlin.math.sqrt

data class AuthenticAacAbruptMarker(
    val nonce: String,
    val sourceSamples: Int,
    val generatedFrames: Int,
    val committedFrames: Int,
    val generatedBytes: Long,
    val encoderName: String,
    val audioSpecificConfigHex: String,
)

data class AuthenticAacRecoveryReport(
    val sourceSamples: Int,
    val generatedFrames: Int,
    val committedFrames: Int,
    val committedSamples: Long,
    val encodedSampleCoverage: Double,
    val sourceToCommittedLossUs: Long,
)

object AuthenticAacAbruptTerminationFixture {
    const val PHASE_ARGUMENT = "loquirisAbruptPhase"
    const val NONCE_ARGUMENT = "loquirisRunNonce"
    const val PREPARE_PHASE = "authentic-process-kill-prepare"
    const val RECOVER_PHASE = "authentic-process-kill-recover"
    const val FORCE_STOP_PREPARE_PHASE = "authentic-force-stop-prepare"
    const val FORCE_STOP_RECOVER_PHASE = "authentic-force-stop-recover"

    private const val DATA_FILE = "active.adts"
    private const val JOURNAL_FILE = "active.commit"
    private const val MARKER_FILE = "generation-complete"
    private const val REPORT_FILE = "recovery-report.json"
    private const val FIXTURE_REPETITIONS = 8
    private const val FRAMES_PER_COMMIT = 75
    private const val SAMPLES_PER_FRAME = 1_024
    private const val FRAME_DURATION_US = 64_000L
    private const val FIVE_SECONDS_US = 5_000_000L

    fun requireNonce(arguments: Bundle): String =
        requireNotNull(arguments.getString(NONCE_ARGUMENT)?.takeIf(String::isNotBlank)) {
            "$NONCE_ARGUMENT must be nonblank"
        }.also { nonce ->
            require(nonce.all { character -> character.code in 0x21..0x7E }) {
                "$NONCE_ARGUMENT must contain printable non-space ASCII only"
            }
        }

    fun prepare(
        root: File,
        nonce: String,
    ): AdtsDurableCommitStore {
        check(!root.exists() || root.deleteRecursively()) { "Unable to clear authentic AAC fixture" }
        check(root.mkdirs()) { "Unable to create authentic AAC fixture" }
        val dataFile = File(root, DATA_FILE).apply { check(createNewFile()) }
        val journalFile = File(root, JOURNAL_FILE).apply { check(createNewFile()) }

        val codec = AacRoundTripSpike()
        val baseFixture = codec.deterministicFixture()
        val repeatedFixture =
            ShortArray(baseFixture.size * FIXTURE_REPETITIONS) { index ->
                baseFixture[index % baseFixture.size]
            }
        val encoded = codec.encode(repeatedFixture)
        val audioSpecificConfig = encoded.codecSpecificData.first()
        AacAudioSpecificConfigParser.requireAacLc16KhzMono(audioSpecificConfig)
        check(encoded.accessUnits.size > FRAMES_PER_COMMIT) { "Authentic AAC fixture is too short" }
        val encodedSampleCoverage =
            encoded.accessUnits.size.toDouble() * SAMPLES_PER_FRAME / repeatedFixture.size
        check(encodedSampleCoverage in 0.98..1.02) {
            "Authentic AAC encoder covered only $encodedSampleCoverage of source PCM"
        }

        val store = AdtsDurableCommitStore.open(dataFile, journalFile)
        try {
            var committedFrames = 0
            encoded.accessUnits.forEachIndexed { index, accessUnit ->
                store.appendFrame(
                    frame =
                        AdtsAacFrameCodec.wrap(
                            accessUnit.bytes,
                            AacRoundTripSpike.SAMPLE_RATE_HZ,
                            AacRoundTripSpike.CHANNEL_COUNT,
                        ),
                    mediaSamples = SAMPLES_PER_FRAME,
                )
                val writtenFrames = index + 1
                if (writtenFrames % FRAMES_PER_COMMIT == 0 && index != encoded.accessUnits.lastIndex) {
                    store.commit()
                    committedFrames = writtenFrames
                }
            }
            check(committedFrames > 0) { "Authentic AAC fixture produced no durable commit" }
            val tailFrames = encoded.accessUnits.size - committedFrames
            check(tailFrames > 0) { "Authentic AAC fixture produced no uncommitted tail" }
            val sourceToCommittedLossUs =
                (repeatedFixture.size.toLong() - committedFrames.toLong() * SAMPLES_PER_FRAME) *
                    1_000_000L / AacRoundTripSpike.SAMPLE_RATE_HZ
            check(sourceToCommittedLossUs in 0..FIVE_SECONDS_US) {
                "Authentic AAC fixture source-to-commit loss exceeds five seconds"
            }
            writeMarker(
                File(root, MARKER_FILE),
                AuthenticAacAbruptMarker(
                    nonce = nonce,
                    sourceSamples = repeatedFixture.size,
                    generatedFrames = encoded.accessUnits.size,
                    committedFrames = committedFrames,
                    generatedBytes = dataFile.length(),
                    encoderName = encoded.codecName,
                    audioSpecificConfigHex = audioSpecificConfig.toHex(),
                ),
            )
            return store
        } catch (failure: Throwable) {
            try {
                store.close()
            } catch (closeFailure: Throwable) {
                failure.addSuppressed(closeFailure)
            }
            throw failure
        }
    }

    fun recoverAndVerify(
        root: File,
        expectedNonce: String,
    ): AuthenticAacRecoveryReport {
        val dataFile = File(root, DATA_FILE)
        val journalFile = File(root, JOURNAL_FILE)
        val markerFile = File(root, MARKER_FILE)
        check(dataFile.isFile) { "Missing authentic AAC data fixture" }
        check(journalFile.isFile) { "Missing authentic AAC journal fixture" }
        check(markerFile.isFile) { "Missing authentic AAC completion marker" }

        val marker = readMarker(markerFile)
        check(marker.nonce == expectedNonce) { "Authentic AAC fixture nonce mismatch" }
        val dataBytes = dataFile.readBytes()
        val recovered = AdtsCommittedPrefixRecovery.recover(dataBytes, journalFile.readBytes())
        check(recovered.committedFrames == marker.committedFrames) { "Authentic AAC committed frame mismatch" }
        check(recovered.committedSamples == recovered.committedFrames.toLong() * SAMPLES_PER_FRAME) {
            "Authentic AAC committed sample watermark mismatch"
        }
        val encodedSampleCoverage = marker.generatedFrames.toDouble() * SAMPLES_PER_FRAME / marker.sourceSamples
        check(encodedSampleCoverage in 0.98..1.02) { "Persisted encoder coverage was $encodedSampleCoverage" }
        val sourceToCommittedLossUs =
            (marker.sourceSamples.toLong() - recovered.committedSamples) * 1_000_000L /
                AacRoundTripSpike.SAMPLE_RATE_HZ
        check(sourceToCommittedLossUs in 0..FIVE_SECONDS_US) {
            "Authentic AAC source-to-commit loss was $sourceToCommittedLossUs us"
        }

        val payloads =
            AdtsAacFrameCodec.unwrapCompleteFrames(
                dataBytes.copyOf(recovered.committedBytes),
            )
        check(payloads.size == marker.committedFrames) { "Authentic AAC payload count mismatch" }
        val audioSpecificConfig = marker.audioSpecificConfigHex.hexToBytes()
        AacAudioSpecificConfigParser.requireAacLc16KhzMono(audioSpecificConfig)
        val accessUnits =
            payloads.mapIndexed { index, bytes ->
                AacRoundTripSpike.AccessUnit(
                    bytes,
                    index.toLong() * SAMPLES_PER_FRAME * 1_000_000L / AacRoundTripSpike.SAMPLE_RATE_HZ,
                )
            }
        val decoded =
            AacRoundTripSpike().decode(
                AacRoundTripSpike.EncodedAudio(
                    codecName = "recovered-authentic-aac",
                    codecSpecificData = listOf(audioSpecificConfig),
                    accessUnits = accessUnits,
                    elapsedMilliseconds = 0L,
                    mediaEndPresentationTimeUs =
                        accessUnits.size.toLong() * SAMPLES_PER_FRAME * 1_000_000L /
                            AacRoundTripSpike.SAMPLE_RATE_HZ,
                ),
            )
        val expectedSamples = recovered.committedFrames * SAMPLES_PER_FRAME
        val coverage = decoded.samples.size.toDouble() / expectedSamples
        val rms = decoded.samples.rootMeanSquare()
        check(coverage in 0.90..1.10) { "Authentic AAC decoded coverage was $coverage" }
        check(rms > 100.0) { "Authentic AAC decoded to silence" }
        check(decoded.sampleRateHz == AacRoundTripSpike.SAMPLE_RATE_HZ)
        check(decoded.channelCount == AacRoundTripSpike.CHANNEL_COUNT)

        File(root, REPORT_FILE).writeText(
            JSONObject()
                .put("schemaVersion", 1)
                .put("nonce", marker.nonce)
                .put("sourceSamples", marker.sourceSamples)
                .put("generatedFrames", marker.generatedFrames)
                .put("committedFrames", recovered.committedFrames)
                .put("committedSamples", recovered.committedSamples)
                .put("encodedSampleCoverage", encodedSampleCoverage)
                .put("observedDataBytes", dataBytes.size)
                .put("preparedDataBytes", marker.generatedBytes)
                .put("committedBytes", recovered.committedBytes)
                .put("sourceToCommittedLossMicroseconds", sourceToCommittedLossUs)
                .put("decodedSamples", decoded.samples.size)
                .put("decodedSampleCoverage", coverage)
                .put("decodedRms", rms)
                .put("encoderName", marker.encoderName)
                .put("decoderName", decoded.codecName)
                .put("audioSpecificConfigHex", marker.audioSpecificConfigHex)
                .toString(2),
        )
        check(markerFile.delete()) { "Unable to consume authentic AAC marker" }
        return AuthenticAacRecoveryReport(
            sourceSamples = marker.sourceSamples,
            generatedFrames = marker.generatedFrames,
            committedFrames = recovered.committedFrames,
            committedSamples = recovered.committedSamples,
            encodedSampleCoverage = encodedSampleCoverage,
            sourceToCommittedLossUs = sourceToCommittedLossUs,
        )
    }

    private fun writeMarker(
        file: File,
        marker: AuthenticAacAbruptMarker,
    ) {
        val payload =
            "${marker.nonce}\n${marker.sourceSamples}\n${marker.generatedFrames}\n" +
                "${marker.committedFrames}\n${marker.generatedBytes}\n${marker.encoderName}\n" +
                "${marker.audioSpecificConfigHex}\n"
        RandomAccessFile(file, "rw").use { output ->
            output.setLength(0L)
            output.writeBytes(payload)
            output.fd.sync()
        }
    }

    private fun readMarker(file: File): AuthenticAacAbruptMarker {
        val fields = file.readLines()
        require(fields.size == 7) { "Authentic AAC marker must contain exactly seven fields" }
        return AuthenticAacAbruptMarker(
            nonce = fields[0],
            sourceSamples = fields[1].toInt(),
            generatedFrames = fields[2].toInt(),
            committedFrames = fields[3].toInt(),
            generatedBytes = fields[4].toLong(),
            encoderName = fields[5],
            audioSpecificConfigHex = fields[6],
        )
    }

    private fun ByteArray.toHex(): String =
        joinToString(separator = "") { byte -> "%02x".format(byte.toInt() and 0xFF) }

    private fun String.hexToBytes(): ByteArray {
        require(length % 2 == 0 && all { it.isDigit() || it.lowercaseChar() in 'a'..'f' }) {
            "Invalid AudioSpecificConfig hex"
        }
        return chunked(2).map { byte -> byte.toInt(16).toByte() }.toByteArray()
    }

    private fun ShortArray.rootMeanSquare(): Double =
        if (isEmpty()) 0.0 else sqrt(sumOf { sample -> sample.toDouble() * sample } / size)
}
