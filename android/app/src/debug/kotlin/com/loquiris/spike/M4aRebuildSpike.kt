package com.loquiris.spike

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaPlayer
import android.os.SystemClock
import android.system.Os
import android.system.OsConstants
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

data class M4aRebuildReport(
    val sourceAccessUnits: Int,
    val sourceWasSingleContinuousEncode: Boolean,
    val sourcePcmSamples: Int,
    val sourceEncodeElapsedMilliseconds: Long,
    val extractedAccessUnits: Int,
    val authoritativeSegmentFiles: Int,
    val manifestDiscoveredSegmentIndices: List<Int>,
    val recoveredSegmentFrameCounts: List<Int>,
    val recoveredCommittedSamples: List<Long>,
    val recoveredSegmentPayloadsMatchTimeline: Boolean,
    val unpublishedRotationSegmentWasIgnored: Boolean,
    val manifestDirectorySyncCount: Int,
    val commitBoundaryFrameIndices: List<Int>,
    val commitBoundaryCount: Int,
    val calculatedLogicalBoundaryFrameIndices: List<Int>,
    val containerDurationMilliseconds: Long,
    val extractorDurationMilliseconds: Long,
    val payloadsMatch: Boolean,
    val allTimestampsMatchCumulativeSamples: Boolean,
    val firstPresentationTimeMicroseconds: Long,
    val lastPresentationTimeMicroseconds: Long,
    val maximumTimestampDeltaMicroseconds: Long,
    val timestampsStrictlyIncrease: Boolean,
    val commitBoundaryTimestampsMatch: Boolean,
    val extractedSampleRateHz: Int,
    val extractedChannelCount: Int,
    val containerSampleCoverage: Double,
    val decodedSampleCoverage: Double,
    val platformPlayerDurationMilliseconds: Long,
    val platformPlayerSeekTargetsMilliseconds: List<Int>,
    val platformPlayerDecodedAllProbePositions: Boolean,
    val rebuiltBytes: Long,
) {
    fun toJson(): String =
        JSONObject()
            .put("schemaVersion", 1)
            .put("fixture", "repeated_deterministic_multi_tone_304_seconds")
            .put("sourceAccessUnits", sourceAccessUnits)
            .put("sourceWasSingleContinuousEncode", sourceWasSingleContinuousEncode)
            .put("sourcePcmSamples", sourcePcmSamples)
            .put("sourceEncodeElapsedMilliseconds", sourceEncodeElapsedMilliseconds)
            .put("extractedAccessUnits", extractedAccessUnits)
            .put("authoritativeSegmentFiles", authoritativeSegmentFiles)
            .put("manifestDiscoveredSegmentIndices", JSONArray(manifestDiscoveredSegmentIndices))
            .put("recoveredSegmentFrameCounts", JSONArray(recoveredSegmentFrameCounts))
            .put("recoveredCommittedSamples", JSONArray(recoveredCommittedSamples))
            .put("recoveredSegmentPayloadsMatchTimeline", recoveredSegmentPayloadsMatchTimeline)
            .put("unpublishedRotationSegmentWasIgnored", unpublishedRotationSegmentWasIgnored)
            .put("manifestDirectorySyncCount", manifestDirectorySyncCount)
            .put("commitBoundaryFrameIndices", JSONArray(commitBoundaryFrameIndices))
            .put("commitBoundaryCount", commitBoundaryCount)
            .put("calculatedLogicalBoundaryFrameIndices", JSONArray(calculatedLogicalBoundaryFrameIndices))
            .put("containerDurationMilliseconds", containerDurationMilliseconds)
            .put("extractorDurationMilliseconds", extractorDurationMilliseconds)
            .put("payloadsMatch", payloadsMatch)
            .put("allTimestampsMatchCumulativeSamples", allTimestampsMatchCumulativeSamples)
            .put("firstPresentationTimeMicroseconds", firstPresentationTimeMicroseconds)
            .put("lastPresentationTimeMicroseconds", lastPresentationTimeMicroseconds)
            .put("maximumTimestampDeltaMicroseconds", maximumTimestampDeltaMicroseconds)
            .put("timestampsStrictlyIncrease", timestampsStrictlyIncrease)
            .put("commitBoundaryTimestampsMatch", commitBoundaryTimestampsMatch)
            .put("extractedSampleRateHz", extractedSampleRateHz)
            .put("extractedChannelCount", extractedChannelCount)
            .put("containerSampleCoverage", containerSampleCoverage)
            .put("decodedSampleCoverage", decodedSampleCoverage)
            .put("platformPlayerDurationMilliseconds", platformPlayerDurationMilliseconds)
            .put("platformPlayerSeekTargetsMilliseconds", JSONArray(platformPlayerSeekTargetsMilliseconds))
            .put("platformPlayerDecodedAllProbePositions", platformPlayerDecodedAllProbePositions)
            .put("rebuiltBytes", rebuiltBytes)
            .put(
                "limitation",
                "One continuous 304-second synthetic PCM stream is encoded, persisted into two ADTS/journal " +
                    "segments discovered through an atomically published manifest, then recovered and remuxed. " +
                    "An unpublished next-segment write is injected at rotation and ignored by recovery. This is " +
                    "also opened and briefly decoded at four muted MediaPlayer seek points, but is not real speech, " +
                    "AudioRecord input, process death during rotation, complete platform playback, or human listening.",
            ).toString(2)
}

class M4aRebuildSpike {
    fun run(outputFile: File): M4aRebuildReport {
        val codecHarness = AacRoundTripSpike()
        val fixture = codecHarness.deterministicFixture()
        val source =
            ShortArray(TOTAL_ACCESS_UNITS * AAC_SAMPLES_PER_ACCESS_UNIT) { index ->
                fixture[index % fixture.size]
            }
        val baseEncoded = codecHarness.encode(source, LONG_CODEC_TIMEOUT_MILLISECONDS)
        check(baseEncoded.accessUnits.size == TOTAL_ACCESS_UNITS) {
            "Expected $TOTAL_ACCESS_UNITS continuous AAC access units, got ${baseEncoded.accessUnits.size}"
        }
        val expandedAccessUnits = baseEncoded.accessUnits
        val outputDirectory = checkNotNull(outputFile.parentFile)
        check(outputDirectory.mkdirs() || outputDirectory.isDirectory) { "Could not create M4A output directory" }
        val recoveredSegments =
            persistAndRecoverSegments(
                outputDirectory = outputDirectory,
                codecSpecificData = baseEncoded.codecSpecificData,
                timeline = expandedAccessUnits,
            )
        val recoveredAccessUnits =
            recoveredSegments.payloads.mapIndexed { index, bytes ->
                AacRoundTripSpike.AccessUnit(
                    bytes = bytes,
                    presentationTimeUs = presentationTimeMicroseconds(index * AAC_SAMPLES_PER_ACCESS_UNIT),
                )
            }
        val encoded =
            AacRoundTripSpike.EncodedAudio(
                codecName = baseEncoded.codecName,
                codecSpecificData = recoveredSegments.codecSpecificData,
                accessUnits = recoveredAccessUnits,
                elapsedMilliseconds = baseEncoded.elapsedMilliseconds,
                mediaEndPresentationTimeUs =
                    presentationTimeMicroseconds(TOTAL_ACCESS_UNITS * AAC_SAMPLES_PER_ACCESS_UNIT),
            )
        check(!outputFile.exists() || outputFile.delete()) { "Could not replace prior M4A spike output" }
        mux(outputFile, encoded)
        val extracted = extract(outputFile)
        val rebuilt =
            AacRoundTripSpike.EncodedAudio(
                codecName = encoded.codecName,
                codecSpecificData = extracted.codecSpecificData,
                accessUnits = extracted.accessUnits,
                elapsedMilliseconds = 0L,
                mediaEndPresentationTimeUs = encoded.mediaEndPresentationTimeUs,
            )
        val decoded = codecHarness.decode(rebuilt)
        val platformPlayerProbe = probePlatformPlayer(outputFile)
        val boundaries =
            generateSequence(COMMIT_FRAMES) { previous -> previous + COMMIT_FRAMES }
                .takeWhile { boundary -> boundary < encoded.accessUnits.size }
                .toList()
        return M4aRebuildReport(
            sourceAccessUnits = encoded.accessUnits.size,
            sourceWasSingleContinuousEncode = true,
            sourcePcmSamples = source.size,
            sourceEncodeElapsedMilliseconds = baseEncoded.elapsedMilliseconds,
            extractedAccessUnits = extracted.accessUnits.size,
            authoritativeSegmentFiles = recoveredSegments.frameCounts.size,
            manifestDiscoveredSegmentIndices = recoveredSegments.segmentIndices,
            recoveredSegmentFrameCounts = recoveredSegments.frameCounts,
            recoveredCommittedSamples = recoveredSegments.committedSamples,
            recoveredSegmentPayloadsMatchTimeline =
                expandedAccessUnits.map(AacRoundTripSpike.AccessUnit::bytes).contentDeepEquals(
                    recoveredSegments.payloads,
                ),
            unpublishedRotationSegmentWasIgnored = recoveredSegments.unpublishedRotationSegmentWasIgnored,
            manifestDirectorySyncCount = recoveredSegments.manifestDirectorySyncCount,
            commitBoundaryFrameIndices = boundaries,
            commitBoundaryCount = boundaries.size,
            calculatedLogicalBoundaryFrameIndices = listOf(LOGICAL_SEGMENT_FRAMES),
            containerDurationMilliseconds = encoded.mediaEndPresentationTimeUs / MICROSECONDS_PER_MILLISECOND,
            extractorDurationMilliseconds = extracted.durationMicroseconds / MICROSECONDS_PER_MILLISECOND,
            payloadsMatch =
                encoded.accessUnits.map(AacRoundTripSpike.AccessUnit::bytes).contentDeepEquals(
                    extracted.accessUnits.map(AacRoundTripSpike.AccessUnit::bytes),
                ),
            allTimestampsMatchCumulativeSamples =
                extracted.accessUnits.withIndex().all { (index, accessUnit) ->
                    accessUnit.presentationTimeUs == presentationTimeMicroseconds(index * AAC_SAMPLES_PER_ACCESS_UNIT)
                },
            firstPresentationTimeMicroseconds = extracted.accessUnits.first().presentationTimeUs,
            lastPresentationTimeMicroseconds = extracted.accessUnits.last().presentationTimeUs,
            maximumTimestampDeltaMicroseconds =
                extracted.accessUnits.zipWithNext().maxOf { (first, second) ->
                    second.presentationTimeUs - first.presentationTimeUs
                },
            timestampsStrictlyIncrease =
                extracted.accessUnits.zipWithNext().all { (first, second) ->
                    first.presentationTimeUs < second.presentationTimeUs
                },
            commitBoundaryTimestampsMatch =
                boundaries.all { boundary ->
                    extracted.accessUnits[boundary].presentationTimeUs ==
                        presentationTimeMicroseconds(boundary * AAC_SAMPLES_PER_ACCESS_UNIT)
                },
            extractedSampleRateHz = extracted.sampleRateHz,
            extractedChannelCount = extracted.channelCount,
            containerSampleCoverage =
                (extracted.accessUnits.last().presentationTimeUs + AAC_FRAME_DURATION_MICROSECONDS).toDouble() /
                    encoded.mediaEndPresentationTimeUs,
            decodedSampleCoverage =
                decoded.samples.size.toDouble() / (TOTAL_ACCESS_UNITS * AAC_SAMPLES_PER_ACCESS_UNIT),
            platformPlayerDurationMilliseconds = platformPlayerProbe.durationMilliseconds,
            platformPlayerSeekTargetsMilliseconds = platformPlayerProbe.seekTargetsMilliseconds,
            platformPlayerDecodedAllProbePositions = platformPlayerProbe.decodedAllProbePositions,
            rebuiltBytes = outputFile.length(),
        )
    }

    private fun probePlatformPlayer(outputFile: File): PlatformPlayerProbe {
        val player = MediaPlayer()
        try {
            val playbackError = AtomicReference<String?>(null)
            player.setOnErrorListener { _, what, extra ->
                playbackError.set("MediaPlayer error what=$what extra=$extra")
                true
            }
            player.setDataSource(outputFile.absolutePath)
            player.setVolume(0f, 0f)
            player.prepare()
            val durationMilliseconds = player.duration.toLong()
            val decodedAllProbePositions =
                PLATFORM_PLAYER_SEEK_TARGETS_MILLISECONDS.all { targetMilliseconds ->
                    val seekCompleted = CountDownLatch(1)
                    player.setOnSeekCompleteListener { seekCompleted.countDown() }
                    player.seekTo(targetMilliseconds.toLong(), MediaPlayer.SEEK_CLOSEST)
                    val seekSucceeded =
                        seekCompleted.await(PLATFORM_PLAYER_OPERATION_TIMEOUT_SECONDS, TimeUnit.SECONDS) &&
                            playbackError.get() == null
                    if (!seekSucceeded) {
                        false
                    } else {
                        val minimumProgressMilliseconds =
                            minOf(targetMilliseconds + PLATFORM_PLAYER_PROBE_PROGRESS_MILLISECONDS, player.duration - 1)
                        val deadline =
                            SystemClock.elapsedRealtime() +
                                TimeUnit.SECONDS.toMillis(PLATFORM_PLAYER_OPERATION_TIMEOUT_SECONDS)
                        player.start()
                        while (
                            player.currentPosition < minimumProgressMilliseconds &&
                            SystemClock.elapsedRealtime() < deadline &&
                            playbackError.get() == null
                        ) {
                            SystemClock.sleep(PLATFORM_PLAYER_POLL_MILLISECONDS)
                        }
                        val progressed =
                            player.currentPosition >= minimumProgressMilliseconds && playbackError.get() == null
                        player.pause()
                        progressed
                    }
                }
            return PlatformPlayerProbe(
                durationMilliseconds = durationMilliseconds,
                seekTargetsMilliseconds = PLATFORM_PLAYER_SEEK_TARGETS_MILLISECONDS,
                decodedAllProbePositions = decodedAllProbePositions,
            )
        } finally {
            player.release()
        }
    }

    private fun persistAndRecoverSegments(
        outputDirectory: File,
        codecSpecificData: List<ByteArray>,
        timeline: List<AacRoundTripSpike.AccessUnit>,
    ): RecoveredSegments {
        val codecSpecificDataFileNames =
            codecSpecificData.mapIndexed { index, bytes ->
                val fileName = "m4a-rebuild-csd-$index.bin"
                val file = File(outputDirectory, fileName)
                check(!file.exists() || file.delete()) { "Could not replace AAC config fixture $index" }
                RandomAccessFile(file, "rw").use { config ->
                    config.write(bytes)
                    config.fd.sync()
                }
                fileName
            }
        val segmentPayloads =
            listOf(
                timeline.subList(0, LOGICAL_SEGMENT_FRAMES),
                timeline.subList(LOGICAL_SEGMENT_FRAMES, timeline.size),
            )
        val publishedSegments = mutableListOf<SegmentManifestEntry>()
        var manifestDirectorySyncCount =
            publishManifest(outputDirectory, codecSpecificDataFileNames, publishedSegments)
        var unpublishedRotationSegmentWasIgnored = false
        segmentPayloads.forEachIndexed { segmentIndex, payloads ->
            val dataFile = File(outputDirectory, "m4a-rebuild-segment-$segmentIndex.adts")
            val journalFile = File(outputDirectory, "m4a-rebuild-segment-$segmentIndex.journal")
            listOf(dataFile, journalFile).forEach { file ->
                check(!file.exists() || file.delete()) { "Could not replace ${file.name}" }
            }
            if (segmentIndex == 1) {
                AdtsDurableCommitStore.open(dataFile, journalFile).use { store ->
                    store.appendFrame(
                        frame =
                            AdtsAacFrameCodec.wrap(
                                accessUnit = payloads.first().bytes,
                                sampleRateHz = AacRoundTripSpike.SAMPLE_RATE_HZ,
                                channelCount = AacRoundTripSpike.CHANNEL_COUNT,
                            ),
                        mediaSamples = AAC_SAMPLES_PER_ACCESS_UNIT,
                    )
                }
                val interruptedRecovery = recoverPublishedManifest(outputDirectory)
                unpublishedRotationSegmentWasIgnored =
                    dataFile.length() > 0L &&
                        interruptedRecovery.segmentIndices == listOf(0) &&
                        interruptedRecovery.frameCounts == listOf(LOGICAL_SEGMENT_FRAMES)
                listOf(dataFile, journalFile).forEach { file ->
                    check(file.delete()) { "Could not clear injected rotation fixture ${file.name}" }
                }
            }
            AdtsDurableCommitStore.open(dataFile, journalFile).use { store ->
                payloads.forEachIndexed { localIndex, accessUnit ->
                    store.appendFrame(
                        frame =
                            AdtsAacFrameCodec.wrap(
                                accessUnit = accessUnit.bytes,
                                sampleRateHz = AacRoundTripSpike.SAMPLE_RATE_HZ,
                                channelCount = AacRoundTripSpike.CHANNEL_COUNT,
                            ),
                        mediaSamples = AAC_SAMPLES_PER_ACCESS_UNIT,
                    )
                    if ((localIndex + 1) % COMMIT_FRAMES == 0 || localIndex == payloads.lastIndex) {
                        store.commit()
                    }
                }
            }
            publishedSegments +=
                SegmentManifestEntry(
                    index = segmentIndex,
                    dataFileName = dataFile.name,
                    journalFileName = journalFile.name,
                )
            manifestDirectorySyncCount +=
                publishManifest(outputDirectory, codecSpecificDataFileNames, publishedSegments)
        }
        return recoverPublishedManifest(outputDirectory).copy(
            unpublishedRotationSegmentWasIgnored = unpublishedRotationSegmentWasIgnored,
            manifestDirectorySyncCount = manifestDirectorySyncCount,
        )
    }

    private fun publishManifest(
        outputDirectory: File,
        codecSpecificDataFileNames: List<String>,
        segments: List<SegmentManifestEntry>,
    ): Int {
        val manifest = File(outputDirectory, MANIFEST_FILE_NAME)
        val temporary = File(outputDirectory, "$MANIFEST_FILE_NAME.tmp")
        check(!temporary.exists() || temporary.delete()) { "Could not replace temporary segment manifest" }
        val json =
            JSONObject()
                .put("schemaVersion", 1)
                .put("codecSpecificDataFiles", JSONArray(codecSpecificDataFileNames))
                .put(
                    "segments",
                    JSONArray().apply {
                        segments.sortedBy(SegmentManifestEntry::index).forEach { segment ->
                            put(
                                JSONObject()
                                    .put("index", segment.index)
                                    .put("dataFile", segment.dataFileName)
                                    .put("journalFile", segment.journalFileName),
                            )
                        }
                    },
                ).toString()
        durableAtomicReplace(
            writeAndSyncTemporary = {
                RandomAccessFile(temporary, "rw").use { file ->
                    file.write(json.toByteArray(Charsets.UTF_8))
                    file.fd.sync()
                }
            },
            atomicReplace = {
                Files.move(
                    temporary.toPath(),
                    manifest.toPath(),
                    StandardCopyOption.ATOMIC_MOVE,
                    StandardCopyOption.REPLACE_EXISTING,
                )
            },
            syncParentDirectory = { syncDirectory(outputDirectory) },
        )
        return 1
    }

    private fun recoverPublishedManifest(outputDirectory: File): RecoveredSegments {
        val manifest = JSONObject(File(outputDirectory, MANIFEST_FILE_NAME).readText())
        check(manifest.getInt("schemaVersion") == 1) { "Unsupported segment manifest" }
        val codecFiles = manifest.getJSONArray("codecSpecificDataFiles")
        val codecSpecificData =
            (0 until codecFiles.length()).map { index ->
                File(outputDirectory, codecFiles.getString(index)).readBytes()
            }
        val manifestSegments = manifest.getJSONArray("segments")
        val segments =
            (0 until manifestSegments.length()).map { index ->
                val value = manifestSegments.getJSONObject(index)
                SegmentManifestEntry(
                    index = value.getInt("index"),
                    dataFileName = value.getString("dataFile"),
                    journalFileName = value.getString("journalFile"),
                )
            }.sortedBy(SegmentManifestEntry::index)
        check(segments.map(SegmentManifestEntry::index) == segments.indices.toList()) {
            "Segment manifest indices are not contiguous"
        }
        val payloads = mutableListOf<ByteArray>()
        val frameCounts = mutableListOf<Int>()
        val committedSamples = mutableListOf<Long>()
        segments.forEach { segment ->
            val dataBytes = File(outputDirectory, segment.dataFileName).readBytes()
            val journalBytes = File(outputDirectory, segment.journalFileName).readBytes()
            val recovered = AdtsCommittedPrefixRecovery.recover(dataBytes, journalBytes)
            check(recovered.committedSamples == recovered.committedFrames.toLong() * AAC_SAMPLES_PER_ACCESS_UNIT) {
                "Segment ${segment.index} sample watermark does not match its frame watermark"
            }
            val recoveredSegment =
                AdtsAacFrameCodec.unwrapCompleteFrames(dataBytes.copyOf(recovered.committedBytes))
            check(recovered.committedFrames == recoveredSegment.size) {
                "Segment ${segment.index} lost committed frames"
            }
            frameCounts += recoveredSegment.size
            committedSamples += recovered.committedSamples
            payloads += recoveredSegment
        }
        return RecoveredSegments(
            codecSpecificData = codecSpecificData,
            payloads = payloads,
            segmentIndices = segments.map(SegmentManifestEntry::index),
            frameCounts = frameCounts,
            committedSamples = committedSamples,
            unpublishedRotationSegmentWasIgnored = false,
            manifestDirectorySyncCount = 0,
        )
    }

    private fun mux(
        outputFile: File,
        encoded: AacRoundTripSpike.EncodedAudio,
    ) {
        val muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var started = false
        var primaryFailure: Throwable? = null
        try {
            val format =
                MediaFormat.createAudioFormat(
                    MediaFormat.MIMETYPE_AUDIO_AAC,
                    AacRoundTripSpike.SAMPLE_RATE_HZ,
                    AacRoundTripSpike.CHANNEL_COUNT,
                ).apply {
                    setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                    setInteger(MediaFormat.KEY_BIT_RATE, AacRoundTripSpike.BIT_RATE_BITS_PER_SECOND)
                    encoded.codecSpecificData.forEachIndexed { index, bytes ->
                        setByteBuffer("csd-$index", ByteBuffer.wrap(bytes))
                    }
                }
            val trackIndex = muxer.addTrack(format)
            muxer.start()
            started = true
            encoded.accessUnits.forEachIndexed { index, accessUnit ->
                val info =
                    MediaCodec.BufferInfo().apply {
                        set(
                            0,
                            accessUnit.bytes.size,
                            presentationTimeMicroseconds(index * AAC_SAMPLES_PER_ACCESS_UNIT),
                            0,
                        )
                    }
                muxer.writeSampleData(trackIndex, ByteBuffer.wrap(accessUnit.bytes), info)
            }
        } catch (failure: Throwable) {
            primaryFailure = failure
            throw failure
        } finally {
            val lifecycleFailure =
                finishMuxerLifecycle(
                    primaryFailure = primaryFailure,
                    stop = { if (started) muxer.stop() },
                    release = muxer::release,
                )
            if (primaryFailure == null && lifecycleFailure != null) {
                throw lifecycleFailure
            }
        }
    }

    private fun extract(outputFile: File): ExtractedM4a {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(outputFile.absolutePath)
            val trackIndex =
                (0 until extractor.trackCount).first { index ->
                    extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME) == MediaFormat.MIMETYPE_AUDIO_AAC
                }
            val format = extractor.getTrackFormat(trackIndex)
            extractor.selectTrack(trackIndex)
            val accessUnits = mutableListOf<AacRoundTripSpike.AccessUnit>()
            val buffer = ByteBuffer.allocate(MAX_EXTRACTED_ACCESS_UNIT_BYTES)
            while (true) {
                buffer.clear()
                val size = extractor.readSampleData(buffer, 0)
                if (size < 0) break
                buffer.position(0)
                buffer.limit(size)
                val bytes = ByteArray(size).also(buffer::get)
                accessUnits += AacRoundTripSpike.AccessUnit(bytes, extractor.sampleTime)
                extractor.advance()
            }
            val codecSpecificData =
                generateSequence(0) { index -> index + 1 }
                    .map { index -> format.getByteBuffer("csd-$index")?.duplicate() }
                    .takeWhile { bufferValue -> bufferValue != null }
                    .map { bufferValue ->
                        val value = checkNotNull(bufferValue)
                        ByteArray(value.remaining()).also(value::get)
                    }.toList()
            check(codecSpecificData.isNotEmpty()) { "Rebuilt M4A exposes no AAC codec configuration" }
            check(accessUnits.isNotEmpty()) { "Rebuilt M4A exposes no AAC samples" }
            return ExtractedM4a(
                codecSpecificData = codecSpecificData,
                accessUnits = accessUnits,
                sampleRateHz = format.getInteger(MediaFormat.KEY_SAMPLE_RATE),
                channelCount = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT),
                durationMicroseconds = format.getLong(MediaFormat.KEY_DURATION),
            )
        } finally {
            extractor.release()
        }
    }

    private fun presentationTimeMicroseconds(sampleOffset: Int): Long =
        sampleOffset.toLong() * MICROSECONDS_PER_SECOND / AacRoundTripSpike.SAMPLE_RATE_HZ

    private data class ExtractedM4a(
        val codecSpecificData: List<ByteArray>,
        val accessUnits: List<AacRoundTripSpike.AccessUnit>,
        val sampleRateHz: Int,
        val channelCount: Int,
        val durationMicroseconds: Long,
    )

    private data class RecoveredSegments(
        val codecSpecificData: List<ByteArray>,
        val payloads: List<ByteArray>,
        val segmentIndices: List<Int>,
        val frameCounts: List<Int>,
        val committedSamples: List<Long>,
        val unpublishedRotationSegmentWasIgnored: Boolean,
        val manifestDirectorySyncCount: Int,
    )

    private data class SegmentManifestEntry(
        val index: Int,
        val dataFileName: String,
        val journalFileName: String,
    )

    private data class PlatformPlayerProbe(
        val durationMilliseconds: Long,
        val seekTargetsMilliseconds: List<Int>,
        val decodedAllProbePositions: Boolean,
    )

    companion object {
        private const val COMMIT_FRAMES = 75
        private const val LOGICAL_SEGMENT_COMMIT_GROUPS = 62
        private const val LOGICAL_SEGMENT_FRAMES = COMMIT_FRAMES * LOGICAL_SEGMENT_COMMIT_GROUPS
        private const val TOTAL_ACCESS_UNITS = LOGICAL_SEGMENT_FRAMES + 100
        private const val AAC_SAMPLES_PER_ACCESS_UNIT = 1_024
        private const val MICROSECONDS_PER_SECOND = 1_000_000L
        private const val MICROSECONDS_PER_MILLISECOND = 1_000L
        private const val AAC_FRAME_DURATION_MICROSECONDS = 64_000L
        private const val MAX_EXTRACTED_ACCESS_UNIT_BYTES = 64 * 1_024
        private const val LONG_CODEC_TIMEOUT_MILLISECONDS = 120_000L
        private const val MANIFEST_FILE_NAME = "m4a-rebuild-manifest.json"
        private const val PLATFORM_PLAYER_OPERATION_TIMEOUT_SECONDS = 5L
        private const val PLATFORM_PLAYER_PROBE_PROGRESS_MILLISECONDS = 200
        private const val PLATFORM_PLAYER_POLL_MILLISECONDS = 20L
        private val PLATFORM_PLAYER_SEEK_TARGETS_MILLISECONDS = listOf(0, 4_800, 297_600, 302_000)
    }
}

internal fun durableAtomicReplace(
    writeAndSyncTemporary: () -> Unit,
    atomicReplace: () -> Unit,
    syncParentDirectory: () -> Unit,
) {
    writeAndSyncTemporary()
    atomicReplace()
    syncParentDirectory()
}

private fun syncDirectory(directory: File) {
    val descriptor =
        Os.open(
            directory.absolutePath,
            OsConstants.O_RDONLY,
            0,
        )
    try {
        Os.fsync(descriptor)
    } finally {
        Os.close(descriptor)
    }
}

private fun List<ByteArray>.contentDeepEquals(other: List<ByteArray>): Boolean =
    size == other.size && indices.all { index -> this[index].contentEquals(other[index]) }

internal fun finishMuxerLifecycle(
    primaryFailure: Throwable?,
    stop: () -> Unit,
    release: () -> Unit,
): Throwable? {
    val cleanupFailures = mutableListOf<Throwable>()
    listOf(stop, release).forEach { action ->
        try {
            action()
        } catch (failure: Throwable) {
            cleanupFailures += failure
        }
    }
    if (primaryFailure != null) {
        cleanupFailures.forEach(primaryFailure::addSuppressed)
        return primaryFailure
    }
    val firstCleanupFailure = cleanupFailures.firstOrNull() ?: return null
    cleanupFailures.drop(1).forEach(firstCleanupFailure::addSuppressed)
    return firstCleanupFailure
}
