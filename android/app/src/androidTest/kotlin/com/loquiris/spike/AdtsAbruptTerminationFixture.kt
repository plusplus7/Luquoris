package com.loquiris.spike

import android.os.Bundle
import java.io.File
import java.io.RandomAccessFile

data class AdtsAbruptFixtureMarker(
    val nonce: String,
    val generatedFrames: Int,
    val committedFrames: Int,
    val generatedBytes: Int,
)

object AdtsAbruptTerminationFixture {
    const val PHASE_ARGUMENT = "loquirisAbruptPhase"
    const val NONCE_ARGUMENT = "loquirisRunNonce"
    const val DATA_FILE = "active.adts"
    const val JOURNAL_FILE = "active.commit"
    const val MARKER_FILE = "generation-complete"
    const val GENERATED_FRAMES = 224
    const val COMMITTED_FRAMES = 150
    const val FRAME_BYTES = 128
    const val SAMPLES_PER_FRAME = 1_024
    const val FRAMES_PER_COMMIT = 75
    const val FRAME_DURATION_US = 64_000L
    const val FIVE_SECONDS_US = 5_000_000L

    fun requireNonce(arguments: Bundle): String =
        requireNotNull(arguments.getString(NONCE_ARGUMENT)?.takeIf(String::isNotBlank)) {
            "$NONCE_ARGUMENT must be nonblank"
        }

    fun writeMarker(
        file: File,
        nonce: String,
    ) {
        val payload = "$nonce\n$GENERATED_FRAMES\n$COMMITTED_FRAMES\n${GENERATED_FRAMES * FRAME_BYTES}\n"
        RandomAccessFile(file, "rw").use { marker ->
            marker.setLength(0L)
            marker.writeBytes(payload)
            marker.fd.sync()
        }
    }

    fun readMarker(file: File): AdtsAbruptFixtureMarker {
        val fields = file.readLines()
        require(fields.size == 4) { "Abrupt fixture marker must contain exactly four fields" }
        return AdtsAbruptFixtureMarker(
            nonce = fields[0],
            generatedFrames = fields[1].toInt(),
            committedFrames = fields[2].toInt(),
            generatedBytes = fields[3].toInt(),
        )
    }

    fun syntheticFrame(frameIndex: Int): ByteArray =
        ByteArray(FRAME_BYTES) { (frameIndex and 0xFF).toByte() }.also { frame ->
            val length = frame.size
            frame[0] = 0xFF.toByte()
            frame[1] = 0xF1.toByte()
            frame[2] = 0x60.toByte()
            frame[3] = ((length ushr 11) and 0x03).toByte()
            frame[4] = ((length ushr 3) and 0xFF).toByte()
            frame[5] = (((length and 0x07) shl 5) or 0x1F).toByte()
            frame[6] = 0xFC.toByte()
        }
}
