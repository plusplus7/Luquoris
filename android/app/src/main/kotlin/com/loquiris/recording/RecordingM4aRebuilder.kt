package com.loquiris.recording

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.Closeable
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer

data class RecordingM4aFormat(
    val sampleRateHz: Int,
    val channelCount: Int,
    val bitRateBitsPerSecond: Int,
    val codecSpecificData: List<ByteArray>,
)

interface RecordingM4aMuxer : Closeable {
    fun start(format: RecordingM4aFormat)

    fun writeSample(
        accessUnit: ByteArray,
        presentationTimeMicroseconds: Long,
    )

    fun finish()
}

fun interface RecordingM4aMuxerFactory {
    fun create(output: File): RecordingM4aMuxer
}

sealed interface RecordingM4aRebuildResult {
    data class Success(
        val fileName: String,
        val accessUnitCount: Int,
        val mediaSamples: Long,
        val bytesWritten: Long,
    ) : RecordingM4aRebuildResult

    data class Failure(
        val code: String,
    ) : RecordingM4aRebuildResult
}

class RecordingM4aRebuilder(
    private val muxerFactory: RecordingM4aMuxerFactory =
        RecordingM4aMuxerFactory(::AndroidRecordingM4aMuxer),
    private val fileOperations: RecordingFileOperations = AndroidRecordingFileOperations,
) {
    fun rebuild(directory: File): RecordingM4aRebuildResult {
        if (!directory.isDirectory) return failure("recording_m4a_directory_missing")
        val statusStore = RecordingM4aArtifactStatusStore(directory, fileOperations)
        if (!statusStore.publish(RecordingM4aArtifactStatus(RecordingM4aArtifactState.building))) {
            return failure("recording_m4a_status_publish_failed")
        }
        val generation =
            when (val computed = RecordingM4aSourceGeneration.compute(directory, fileOperations)) {
                is RecordingM4aSourceGenerationResult.Success -> computed.value
                is RecordingM4aSourceGenerationResult.Failure ->
                    return failed(statusStore, computed.code)
            }
        val manifest =
            when (val loaded = AtomicRecordingSegmentManifestStore(directory, fileOperations).load()) {
                is RecordingSegmentManifestDecodeResult.Success -> loaded.manifest
                is RecordingSegmentManifestDecodeResult.Corrupt -> return failed(statusStore, loaded.code, generation)
            }
        if (manifest.segments.isEmpty()) return failed(statusStore, "recording_m4a_source_empty", generation)

        val target = File(directory, OUTPUT_FILE_NAME)
        val temporary = File(directory, "$OUTPUT_FILE_NAME.tmp")
        if (temporary.exists() && !temporary.delete()) {
            return failed(statusStore, "recording_m4a_temporary_cleanup_failed", generation)
        }

        var muxer: RecordingM4aMuxer? = null
        var accessUnitCount = 0
        var mediaSamples = 0L
        var muxStarted = false
        try {
            val activeMuxer = muxerFactory.create(temporary)
            muxer = activeMuxer
            activeMuxer.start(
                RecordingM4aFormat(
                    sampleRateHz = manifest.sampleRateHz,
                    channelCount = manifest.channelCount,
                    bitRateBitsPerSecond = manifest.bitRateBitsPerSecond,
                    codecSpecificData = manifest.codecSpecificData.map(ByteArray::copyOf),
                ),
            )
            muxStarted = true
            manifest.segments.forEach { entry ->
                val dataFile = File(directory, entry.dataFileName)
                val journalFile = File(directory, entry.journalFileName)
                if (!dataFile.isFile || !journalFile.isFile) {
                    throw RecordingM4aSourceException("recording_m4a_segment_missing")
                }
                val dataBytes = dataFile.readBytes()
                val recovered = RecordingCommittedPrefixRecovery.recover(dataBytes, journalFile.readBytes())
                if (entry.startSample != mediaSamples) {
                    throw RecordingM4aSourceException("recording_m4a_timeline_invalid")
                }
                var segmentFrames = 0
                RecordingAdtsAccessUnitReader.forEach(
                    dataBytes = dataBytes,
                    byteEndExclusive = recovered.committedBytes,
                ) { accessUnit ->
                    activeMuxer.writeSample(
                        accessUnit = accessUnit,
                        presentationTimeMicroseconds =
                            mediaSamples * MICROSECONDS_PER_SECOND / manifest.sampleRateHz,
                    )
                    mediaSamples = Math.addExact(mediaSamples, AAC_SAMPLES_PER_ACCESS_UNIT.toLong())
                    accessUnitCount = Math.addExact(accessUnitCount, 1)
                    segmentFrames += 1
                }
                if (
                    recovered.committedFrames != segmentFrames ||
                    recovered.committedSamples != segmentFrames.toLong() * AAC_SAMPLES_PER_ACCESS_UNIT
                ) {
                    throw RecordingM4aSourceException("recording_m4a_committed_prefix_invalid")
                }
            }
            if (accessUnitCount == 0) throw RecordingM4aSourceException("recording_m4a_source_empty")
            activeMuxer.finish()
            activeMuxer.close()
            muxer = null
        } catch (failure: RecordingM4aSourceException) {
            runCatching { muxer?.close() }
            temporary.delete()
            return failed(statusStore, failure.code, generation)
        } catch (_: Exception) {
            runCatching { muxer?.close() }
            temporary.delete()
            return failed(
                statusStore,
                if (muxStarted) "recording_m4a_mux_failed" else "recording_m4a_initialize_failed",
                generation,
            )
        }

        if (!temporary.isFile) return failed(statusStore, "recording_m4a_output_missing", generation)
        val synced =
            try {
                RandomAccessFile(temporary, "rw").use { it.fd.sync() }
                true
            } catch (_: Exception) {
                false
            }
        if (!synced) return failureAndDelete(temporary, statusStore, "recording_m4a_sync_failed", generation)
        val replaced = runCatching { fileOperations.atomicReplace(temporary, target) }.getOrDefault(false)
        if (!replaced) return failureAndDelete(temporary, statusStore, "recording_m4a_publish_failed", generation)
        val directorySynced = runCatching { fileOperations.syncDirectory(directory) }.getOrDefault(false)
        if (!directorySynced) return failed(statusStore, "recording_m4a_directory_sync_failed", generation)
        val currentGeneration = RecordingM4aSourceGeneration.compute(directory, fileOperations)
        if (
            currentGeneration !is RecordingM4aSourceGenerationResult.Success ||
            currentGeneration.value != generation
        ) {
            return failed(statusStore, "recording_m4a_source_changed", generation)
        }
        val result = RecordingM4aRebuildResult.Success(
            fileName = OUTPUT_FILE_NAME,
            accessUnitCount = accessUnitCount,
            mediaSamples = mediaSamples,
            bytesWritten = target.length(),
        )
        val ready =
            RecordingM4aArtifactStatus(
                state = RecordingM4aArtifactState.ready,
                generation = generation,
                fileName = result.fileName,
                accessUnitCount = result.accessUnitCount,
                mediaSamples = result.mediaSamples,
                bytesWritten = result.bytesWritten,
            )
        if (!statusStore.publish(ready)) {
            return failed(statusStore, "recording_m4a_status_publish_failed", generation)
        }
        return result
    }

    private fun failureAndDelete(
        temporary: File,
        statusStore: RecordingM4aArtifactStatusStore,
        code: String,
        generation: String,
    ): RecordingM4aRebuildResult.Failure {
        temporary.delete()
        return failed(statusStore, code, generation)
    }

    private fun failed(
        statusStore: RecordingM4aArtifactStatusStore,
        code: String,
        generation: String? = null,
    ): RecordingM4aRebuildResult.Failure {
        statusStore.publish(
            RecordingM4aArtifactStatus(
                state = RecordingM4aArtifactState.failed,
                generation = generation,
                failureCode = code,
            ),
        )
        return failure(code)
    }

    private fun failure(code: String) = RecordingM4aRebuildResult.Failure(code)

    companion object {
        const val OUTPUT_FILE_NAME = "playback.m4a"
        private const val AAC_SAMPLES_PER_ACCESS_UNIT = 1_024
        private const val MICROSECONDS_PER_SECOND = 1_000_000L
    }
}

private class RecordingM4aSourceException(
    val code: String,
) : Exception()

private object RecordingAdtsAccessUnitReader {
    fun forEach(
        dataBytes: ByteArray,
        byteEndExclusive: Int,
        consume: (ByteArray) -> Unit,
    ) {
        require(byteEndExclusive in 0..dataBytes.size)
        var offset = 0
        while (offset < byteEndExclusive) {
            if (byteEndExclusive - offset < ADTS_HEADER_BYTES) {
                throw RecordingM4aSourceException("recording_m4a_adts_invalid")
            }
            if (unsigned(dataBytes[offset]) != 0xff || unsigned(dataBytes[offset + 1]) and 0xf6 != 0xf0) {
                throw RecordingM4aSourceException("recording_m4a_adts_invalid")
            }
            val headerBytes =
                if (unsigned(dataBytes[offset + 1]) and 1 == 1) ADTS_HEADER_BYTES else ADTS_CRC_HEADER_BYTES
            val frameBytes =
                ((unsigned(dataBytes[offset + 3]) and 0x03) shl 11) or
                    (unsigned(dataBytes[offset + 4]) shl 3) or
                    ((unsigned(dataBytes[offset + 5]) and 0xe0) ushr 5)
            val frameEnd = offset + frameBytes
            if (frameBytes <= headerBytes || frameEnd > byteEndExclusive) {
                throw RecordingM4aSourceException("recording_m4a_adts_invalid")
            }
            consume(dataBytes.copyOfRange(offset + headerBytes, frameEnd))
            offset = frameEnd
        }
    }

    private fun unsigned(value: Byte): Int = value.toInt() and 0xff

    private const val ADTS_HEADER_BYTES = 7
    private const val ADTS_CRC_HEADER_BYTES = 9
}

private class AndroidRecordingM4aMuxer(
    output: File,
) : RecordingM4aMuxer {
    private val delegate = MediaMuxer(output.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    private var trackIndex = -1
    private var started = false
    private var finished = false

    override fun start(format: RecordingM4aFormat) {
        check(!started)
        val mediaFormat =
            MediaFormat.createAudioFormat(
                MediaFormat.MIMETYPE_AUDIO_AAC,
                format.sampleRateHz,
                format.channelCount,
            ).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, format.bitRateBitsPerSecond)
                format.codecSpecificData.forEachIndexed { index, bytes ->
                    setByteBuffer("csd-$index", ByteBuffer.wrap(bytes))
                }
            }
        trackIndex = delegate.addTrack(mediaFormat)
        delegate.start()
        started = true
    }

    override fun writeSample(
        accessUnit: ByteArray,
        presentationTimeMicroseconds: Long,
    ) {
        check(started && !finished)
        val info =
            MediaCodec.BufferInfo().apply {
                set(0, accessUnit.size, presentationTimeMicroseconds, 0)
            }
        delegate.writeSampleData(trackIndex, ByteBuffer.wrap(accessUnit), info)
    }

    override fun finish() {
        check(started && !finished)
        delegate.stop()
        finished = true
    }

    override fun close() {
        delegate.release()
    }
}
