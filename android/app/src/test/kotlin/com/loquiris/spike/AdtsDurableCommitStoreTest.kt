package com.loquiris.spike

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.util.zip.CRC32

class AdtsDurableCommitStoreTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun `complete but uncommitted ADTS frames are excluded from recovery`() {
        val dataFile = temporaryFolder.newFile("segment.adts")
        val journalFile = temporaryFolder.newFile("segment.commit")
        AdtsDurableCommitStore.open(dataFile, journalFile).use { store ->
            store.appendFrame(adtsFrame(100, 1), mediaSamples = 1_024)
            store.appendFrame(adtsFrame(100, 2), mediaSamples = 1_024)
            store.commit()
            store.appendFrame(adtsFrame(100, 3), mediaSamples = 1_024)
        }

        val recovery = AdtsCommittedPrefixRecovery.recover(dataFile.readBytes(), journalFile.readBytes())

        assertEquals(2, recovery.committedFrames)
        assertEquals(200, recovery.committedBytes)
        assertEquals(2_048L, recovery.committedSamples)
        assertEquals(100, recovery.uncommittedOrInvalidBytes)
    }

    @Test
    fun `truncated data falls back to the last fully present commit`() {
        val first = adtsFrame(100, 1)
        val second = adtsFrame(100, 2)
        val data = first + second
        val firstCommit = commit(sequence = 1, frames = 1, bytes = first, samples = 1_024)
        val secondCommit = commit(sequence = 2, frames = 2, bytes = data, samples = 2_048)
        val journal = AdtsCommitJournal.encode(firstCommit) + AdtsCommitJournal.encode(secondCommit)

        val recovery = AdtsCommittedPrefixRecovery.recover(data.copyOf(150), journal)

        assertEquals(1, recovery.committedFrames)
        assertEquals(100, recovery.committedBytes)
        assertEquals(50, recovery.uncommittedOrInvalidBytes)
    }

    @Test
    fun `partial journal tail preserves the preceding valid commit`() {
        val frame = adtsFrame(100, 1)
        val validRecord = AdtsCommitJournal.encode(commit(1, 1, frame, 1_024))
        val tornRecord = AdtsCommitJournal.encode(commit(2, 2, frame + frame, 2_048)).copyOf(17)

        val recoveredRecords = AdtsCommitJournal.decodeCompletePrefix(validRecord + tornRecord)

        assertEquals(1, recoveredRecords.size)
        assertEquals(100L, recoveredRecords.single().byteEndExclusive)
    }

    @Test
    fun `opening the journal failure closes the already opened data file`() {
        val dataFile = temporaryFolder.newFile("segment.adts")
        val journalFile = temporaryFolder.newFile("segment.commit")
        lateinit var openedData: RandomAccessFile
        var openCount = 0

        assertThrows(IOException::class.java) {
            AdtsDurableCommitStore.open(dataFile, journalFile) { file ->
                openCount += 1
                if (openCount == 2) throw IOException("journal open failed")
                RandomAccessFile(file, "rw").also { openedData = it }
            }
        }

        assertThrows(IOException::class.java) { openedData.length() }
    }

    @Test
    fun `nonempty inputs are rejected before either file is opened`() {
        val dataFile = temporaryFolder.newFile("segment.adts").apply { writeText("existing") }
        val journalFile = temporaryFolder.newFile("segment.commit")
        var openCount = 0

        assertThrows(IllegalArgumentException::class.java) {
            AdtsDurableCommitStore.open(dataFile, journalFile) { file ->
                openCount += 1
                RandomAccessFile(file, "rw")
            }
        }

        assertEquals(0, openCount)
    }

    private fun commit(
        sequence: Long,
        frames: Long,
        bytes: ByteArray,
        samples: Long,
    ): AdtsCommitRecord =
        AdtsCommitRecord(
            sequence = sequence,
            frameEndExclusive = frames,
            byteEndExclusive = bytes.size.toLong(),
            sampleEndExclusive = samples,
            prefixCrc32 = crc32(bytes),
        )
}

private fun crc32(bytes: ByteArray): Long = CRC32().also { it.update(bytes) }.value

private fun adtsFrame(
    length: Int,
    marker: Int,
): ByteArray {
    require(length >= 7)
    return ByteArray(length) { marker.toByte() }.also { frame ->
        frame[0] = 0xFF.toByte()
        frame[1] = 0xF1.toByte()
        frame[2] = 0x60.toByte()
        frame[3] = ((length ushr 11) and 0x03).toByte()
        frame[4] = ((length ushr 3) and 0xFF).toByte()
        frame[5] = (((length and 0x07) shl 5) or 0x1F).toByte()
        frame[6] = 0xFC.toByte()
    }
}
