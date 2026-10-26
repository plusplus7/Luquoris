package com.loquiris.transcription

import java.io.File
import org.junit.Assert.*
import org.junit.Test
import org.junit.Rule
import org.junit.rules.TemporaryFolder
import java.security.MessageDigest
import com.loquiris.recording.RecordingProcessLiveness

class RefinementPostSessionWorkerTest {
    @get:Rule val temporary = TemporaryFolder()
    private val originalFiles by lazy { listOf("first.adts", "second.adts").map { name -> temporary.newFile(name).apply { writeBytes(byteArrayOf(1)) } } }
    private val digest = "a".repeat(64)
    private val request = RefinementExecutionRequest(
        "meeting", digest, "1.9.4", ModelArtifactSpec("model", "models/pinned.bin", 3, "b".repeat(64)),
        TranscriptionLanguageHint.mixed,
    )
    private val audio by lazy { AuthoritativeAudioResolution.Ready(
        listOf(
            AuthoritativeAudioSegment(0, originalFiles[0], 1, 0, 1024, hash(byteArrayOf(1))),
            AuthoritativeAudioSegment(1, originalFiles[1], 1, 1024, 1024, hash(byteArrayOf(1))),
        ), 2048, 16000, listOf(byteArrayOf(1)),
    ) }
    private fun hash(bytes: ByteArray) = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

    @Test fun `complete ordered input is rechecked and raw output is never trimmed`() {
        val fixture = Fixture()
        val result = fixture.worker().transcribe(request) as RefinementExecutionResult.Completed
        assertEquals(listOf("meeting" to digest, "meeting" to digest), fixture.inspections)
        assertEquals(listOf(0, 1), fixture.decodedSegments)
        assertEquals(listOf(" first ", " second "), result.output.segments.map { it.rawText })
        assertEquals(result.output.segments.map { it.rawText }, result.output.segments.map { it.displayText })
        assertEquals(1, fixture.native.contextsFreed)
        assertEquals(1, fixture.native.runsFreed)
        assertEquals(2, fixture.native.resultsFreed)
        assertTrue(fixture.decodedFiles.all { !it.exists() })
        assertTrue(originalFiles.all { it.exists() })
    }

    @Test fun `changed inventory never loads a model`() {
        val fixture = Fixture()
        fixture.inspection = { RefinementAudioInventoryResult.Failure("refinement_audio_inventory_mismatch") }
        assertEquals(RefinementExecutionResult.Failure("refinement_audio_inventory_mismatch"), fixture.worker().transcribe(request))
        assertEquals(0, fixture.modelLoads)
    }

    @Test fun `active recording defers before inspecting audio or materializing models`() {
        val fixture = Fixture()
        fixture.recording = true
        assertEquals(RefinementExecutionResult.Deferred("refinement_recording_active"), fixture.worker().transcribe(request))
        assertTrue(fixture.inspections.isEmpty())
        assertEquals(0, fixture.modelLoads)
    }

    @Test fun `runtime mismatch rejects before optional native allocation`() {
        val fixture = Fixture()
        assertEquals(RefinementExecutionResult.Failure("refinement_runtime_mismatch"), fixture.worker().transcribe(request.copy(engineVersion = "other")))
        assertEquals(0, fixture.modelLoads)
    }

    @Test fun `new recording cancels active inference and releases handles before yielding`() {
        val fixture = Fixture()
        fixture.beforeWindow = { index -> if (index == 1) { fixture.recording = true; fixture.captureListener!!() } }
        assertEquals(RefinementExecutionResult.Deferred("refinement_recording_active"), fixture.worker().transcribe(request))
        assertEquals(1, fixture.native.resultsFreed)
        assertTrue(fixture.native.cancelledRuns.isNotEmpty())
        assertEquals(1, fixture.native.contextsFreed)
        assertEquals(1, fixture.native.runsFreed)
        assertNull(fixture.captureListener)
    }

    @Test fun `caller cancellation stays distinct from resource deferral`() {
        val fixture = Fixture()
        val cancellation = TranscriptionCancellation()
        fixture.beforeWindow = { cancellation.cancel() }
        assertEquals(RefinementExecutionResult.Cancelled, fixture.worker().transcribe(request, cancellation))
        assertEquals(1, fixture.native.contextsFreed)
        assertNull(fixture.captureListener)
    }

    @Test fun `decoder success with missing original samples is not complete coverage`() {
        val fixture = Fixture()
        fixture.windows = 1
        assertEquals(RefinementExecutionResult.Failure("refinement_audio_decode_incomplete"), fixture.worker().transcribe(request))
        assertEquals(1, fixture.native.contextsFreed)
    }

    @Test fun `post inference source mutation discards computed output`() {
        val fixture = Fixture()
        fixture.inspection = { if (fixture.inspections.size == 2) RefinementAudioInventoryResult.Failure("refinement_audio_changed") else fixture.ready() }
        assertEquals(RefinementExecutionResult.Failure("refinement_audio_changed"), fixture.worker().transcribe(request))
        assertEquals(2, fixture.native.resultsFreed)
    }

    @Test fun `capture during model loading prevents context allocation`() {
        val fixture = Fixture()
        fixture.duringModelLoad = { fixture.recording = true; fixture.captureListener!!() }
        assertEquals(RefinementExecutionResult.Deferred("refinement_recording_active"), fixture.worker().transcribe(request))
        assertEquals(0, fixture.native.contextsCreated)
    }

    @Test fun `cleanup exceptions remain typed and do not escape`() {
        for (error in listOf(IllegalStateException("private"), java.io.IOException("private"))) {
            val fixture = Fixture()
            fixture.closeError = error
            assertEquals(RefinementExecutionResult.Failure("refinement_cleanup_failed"), fixture.worker().transcribe(request))
            assertEquals(1, fixture.native.contextsFreed)
        }
    }

    @Test fun `JNI cancellation exception cannot escape onto capture notification thread`() {
        val fixture = Fixture()
        fixture.native.failCancel = true
        val escaped = java.util.concurrent.atomic.AtomicReference<Throwable?>()
        fixture.beforeWindow = { index -> if (index == 1) {
            fixture.recording = true
            val thread = Thread { try { fixture.captureListener!!() } catch (error: Throwable) { escaped.set(error) } }
            thread.start()
            thread.join(2000)
            assertFalse(thread.isAlive)
        } }
        assertEquals(RefinementExecutionResult.Deferred("refinement_recording_active"), fixture.worker().transcribe(request))
        assertNull(escaped.get())
        assertEquals(1, fixture.native.contextsFreed)
        assertEquals(1, fixture.native.runsFreed)
    }

    @Test fun `decoder consumes verified snapshot even if originals change and then revert`() {
        val fixture = Fixture()
        fixture.duringDecode = { originalFiles[0].writeBytes(byteArrayOf(9)) }
        fixture.afterDecode = { originalFiles[0].writeBytes(byteArrayOf(1)) }
        assertTrue(fixture.worker().transcribe(request) is RefinementExecutionResult.Completed)
        assertArrayEquals(byteArrayOf(1), fixture.decodedBytes)
    }

    @Test fun `source mutation between inspection and snapshot refuses model allocation`() {
        val fixture = Fixture()
        fixture.inspection = { originalFiles[0].writeBytes(byteArrayOf(9)); fixture.ready() }
        assertEquals(RefinementExecutionResult.Failure("refinement_audio_changed"), fixture.worker().transcribe(request))
        assertEquals(0, fixture.modelLoads)
    }

    @Test fun `real native recording ownership signals optional worker cancellation`() {
        val fixture = Fixture()
        fixture.useProcessRecordingPriority = true
        fixture.beforeWindow = { index -> if (index == 1) RecordingProcessLiveness.claim("worker-priority-test") }
        try {
            assertEquals(RefinementExecutionResult.Deferred("refinement_recording_active"), fixture.worker().transcribe(request))
            assertTrue(RecordingProcessLiveness.owns("worker-priority-test"))
            assertEquals(1, fixture.native.contextsFreed)
            assertEquals(1, fixture.native.runsFreed)
        } finally {
            RecordingProcessLiveness.release("worker-priority-test")
        }
    }

    @Test fun `another active snapshot owner defers execution without model allocation`() {
        val fixture = Fixture()
        val existing = RefinementAudioSnapshotStore(fixture.snapshotDirectory).create(audio) { false }
        try {
            assertEquals(RefinementExecutionResult.Deferred("refinement_worker_busy"), fixture.worker().transcribe(request))
            assertEquals(0, fixture.modelLoads)
            assertArrayEquals(byteArrayOf(1), existing.audio.segments.first().file.readBytes())
        } finally { existing.close() }
    }

    @Test fun `unsafe resources defer before inspecting input or loading models`() {
        val fixture = Fixture()
        fixture.resourceReason = "refinement_thermal_severe"
        assertEquals(RefinementExecutionResult.Deferred("refinement_thermal_severe"), fixture.worker().transcribe(request))
        assertTrue(fixture.inspections.isEmpty())
        assertEquals(0, fixture.modelLoads)
    }

    @Test fun `resource signal during model loading prevents context allocation`() {
        val fixture = Fixture()
        fixture.duringModelLoad = { fixture.resourceListener!!("refinement_memory_pressure") }
        assertEquals(RefinementExecutionResult.Deferred("refinement_memory_pressure"), fixture.worker().transcribe(request))
        assertEquals(0, fixture.native.contextsCreated)
        assertNull(fixture.resourceListener)
        assertNull(fixture.captureListener)
    }

    @Test fun `resource cancellation releases native ownership before returning deferred`() {
        val fixture = Fixture()
        fixture.native.failCancel = true
        fixture.beforeWindow = { index -> if (index == 1) fixture.resourceListener!!("refinement_battery_low") }
        assertEquals(RefinementExecutionResult.Deferred("refinement_battery_low"), fixture.worker().transcribe(request))
        assertEquals(1, fixture.native.contextsFreed)
        assertEquals(1, fixture.native.runsFreed)
        assertNull(fixture.resourceListener)
        assertTrue(fixture.decodedFiles.all { !it.exists() })
    }

    @Test fun `resource change during observer registration is checked before model load`() {
        val fixture = Fixture()
        fixture.duringResourceRegistration = { fixture.resourceReason = "refinement_power_save" }
        assertEquals(RefinementExecutionResult.Deferred("refinement_power_save"), fixture.worker().transcribe(request))
        assertEquals(0, fixture.modelLoads)
        assertNull(fixture.resourceListener)
    }

    @Test fun `capture takes priority over a concurrent resource signal`() {
        val fixture = Fixture()
        fixture.duringModelLoad = {
            fixture.resourceListener!!("refinement_memory_pressure")
            fixture.captureListener!!()
        }
        assertEquals(RefinementExecutionResult.Deferred("refinement_recording_active"), fixture.worker().transcribe(request))
        assertEquals(0, fixture.native.contextsCreated)
    }

    @Test fun `resource observer registration failure cleans capture observer`() {
        val fixture = Fixture()
        fixture.duringResourceRegistration = { throw IllegalStateException("private") }
        assertEquals(RefinementExecutionResult.Deferred("refinement_resources_unavailable"), fixture.worker().transcribe(request))
        assertEquals(0, fixture.modelLoads)
        assertNull(fixture.captureListener)
    }

    private inner class Fixture {
        val snapshotDirectory = temporary.newFolder()
        val native = ControlledRefinementNative()
        var modelLoads = 0
        var recording = false
        var useProcessRecordingPriority = false
        var windows = 2
        var beforeWindow: (Int) -> Unit = {}
        var duringModelLoad: () -> Unit = {}
        var closeError: Exception? = null
        var resourceReason: String? = null
        var resourceListener: ((String) -> Unit)? = null
        var duringResourceRegistration: () -> Unit = {}
        var duringDecode: () -> Unit = {}
        var afterDecode: () -> Unit = {}
        var decodedBytes: ByteArray? = null
        var decodedFiles = emptyList<File>()
        var captureListener: (() -> Unit)? = null
        val inspections = mutableListOf<Pair<String, String>>()
        var inspection: () -> RefinementAudioInventoryResult = { ready() }
        var decodedSegments = emptyList<Int>()
        fun ready() = RefinementAudioInventoryResult.Ready(audio, digest, listOf("c".repeat(64), "d".repeat(64)))
        fun worker() = RefinementPostSessionWorker(
            inspect = { meeting, expected -> inspections += meeting to expected; inspection() },
            modelProvider = { spec ->
                assertEquals(request.model, spec)
                WhisperModelProvider { modelLoads++; duringModelLoad(); ModelMaterializationResult.Ready(File("pinned.bin")) }
            },
            decoder = AacPcmDecoder { source, emit ->
                duringDecode()
                decodedBytes = source.segments.first().file.readBytes()
                decodedFiles = source.segments.map { it.file }
                decodedSegments = source.segments.map { it.index }
                var accepted = true
                for (index in 0 until windows) {
                    beforeWindow(index)
                    if (!emit(PcmWindow(index * 1024L, ShortArray(1024)))) { accepted = false; break }
                }
                afterDecode()
                if (accepted) AudioDecodeResult.Completed else AudioDecodeResult.Cancelled
            },
            native = native,
            isRecordingActive = { recording || (useProcessRecordingPriority && RecordingProcessLiveness.hasActiveSession()) },
            onRecordingStarted = { listener ->
                captureListener = listener
                val processObserver = if (useProcessRecordingPriority) RecordingProcessLiveness.observeStarts(listener) else null
                AutoCloseable { processObserver?.close(); captureListener = null; closeError?.let { throw it } }
            },
            snapshotDirectory = snapshotDirectory,
            resourcePauseReason = { resourceReason },
            onResourcesPaused = { listener ->
                duringResourceRegistration()
                resourceListener = listener
                AutoCloseable { resourceListener = null }
            },
        )
    }
}

private class ControlledRefinementNative : WhisperNativeApi {
    var contextsCreated = 0
    var failCancel = false
    var contextsFreed = 0
    var runsFreed = 0
    var resultsFreed = 0
    private var calls = 0
    val cancelledRuns = mutableListOf<Long>()
    override fun createContext(modelPath: String): Long { contextsCreated++; return 1L }
    override fun freeContext(handle: Long) { contextsFreed++ }
    override fun createRun() = 2L
    override fun cancelRun(handle: Long) { cancelledRuns += handle; if (failCancel) throw IllegalStateException("private") }
    override fun freeRun(handle: Long) { runsFreed++ }
    override fun transcribePcm(contextHandle: Long, runHandle: Long, pcm: ShortArray, windowStartMilliseconds: Long, languageHint: TranscriptionLanguageHint): Long = (++calls).toLong()
    override fun segmentCount(resultHandle: Long) = 1
    override fun segmentStartMilliseconds(resultHandle: Long, index: Int) = (resultHandle - 1) * 64
    override fun segmentEndMilliseconds(resultHandle: Long, index: Int) = resultHandle * 64
    override fun segmentText(resultHandle: Long, index: Int) = if (resultHandle == 1L) " first " else " second "
    override fun freeResult(handle: Long) { resultsFreed++ }
    override fun engineVersion() = "1.9.4"
    override fun lastErrorCode(): String? = null
}
