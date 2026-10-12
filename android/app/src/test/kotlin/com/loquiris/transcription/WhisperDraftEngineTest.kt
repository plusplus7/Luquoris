package com.loquiris.transcription

import com.loquiris.recording.PcmCaptureFrame
import java.io.File
import java.util.concurrent.Executor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WhisperDraftEngineTest {
    @Test
    fun `forwards the requested language to native draft inference`() {
        val native = DraftNativeApi()
        val engine = WhisperDraftEngine(
            "draft-1",
            readyModel(),
            native,
            {},
            languageHint = TranscriptionLanguageHint.chinese,
            sampleRateHz = 1_000,
            windowSamples = 4,
            strideSamples = 2,
        )

        engine.start()
        engine.consume(pcmFrame(0, 1, 2))
        engine.consume(pcmFrame(1, 3, 4))

        assertEquals(listOf(TranscriptionLanguageHint.chinese), native.languageHints)
        engine.close()
    }

    @Test
    fun `owner close during materialization never allocates a context`() {
        val native = DraftNativeApi()
        lateinit var engine: WhisperDraftEngine
        engine = WhisperDraftEngine(
            "draft-1",
            WhisperModelProvider {
                engine.close()
                readyModel().materialize()
            },
            native,
            {},
        )
        assertEquals(LiveDraftStartResult.Failure("transcription_live_closed"), engine.start())
        assertEquals(0, native.createdContexts)
    }

    @Test
    fun `dropped frames preserve media time and never splice noncontiguous PCM`() {
        val native = DraftNativeApi()
        val engine = WhisperDraftEngine(
            "draft-1", readyModel(), native, {},
            sampleRateHz = 1_000, windowSamples = 4, strideSamples = 2,
        )
        engine.start()
        engine.consume(pcmFrame(0, 1, 2))
        engine.consume(pcmFrame(3, 7, 8))
        engine.consume(pcmFrame(4, 9, 10))
        assertEquals(listOf(listOf<Short>(7, 8, 9, 10)), native.windows)
        assertEquals(listOf(6L), native.windowStartsMilliseconds)
        engine.close()
    }

    @Test
    fun `only one live model may hold a shared arbiter`() {
        val arbiter = WhisperInferenceArbiter()
        val native = DraftNativeApi()
        val first = WhisperDraftEngine("draft-1", readyModel(), native, {}, arbiter = arbiter)
        val second = WhisperDraftEngine("draft-2", readyModel(), native, {}, arbiter = arbiter)
        try {
            assertEquals(LiveDraftStartResult.Started, first.start())
            assertTrue(second.start() is LiveDraftStartResult.Failure)
            assertEquals(1, native.createdContexts)
        } finally {
            first.close()
            second.close()
        }
    }

    @Test
    fun `fixed rolling window and stride keep one decode in flight`() {
        val native = DraftNativeApi()
        val events = mutableListOf<LiveDraftRuntimeEvent>()
        val engine =
            WhisperDraftEngine(
                runId = "draft-1",
                modelProvider = readyModel(),
                native = native,
                eventEmitter = events::add,
                sampleRateHz = 1_000,
                windowSamples = 4,
                strideSamples = 2,
                stableHorizonMilliseconds = 1,
                cleanupExecutor = Executor { it.run() },
            )
        assertEquals(LiveDraftStartResult.Started, engine.start())

        engine.consume(pcmFrame(0, 1, 2))
        engine.consume(pcmFrame(1, 3, 4))
        engine.consume(pcmFrame(2, 5, 6))

        assertEquals(listOf(listOf<Short>(1, 2, 3, 4), listOf<Short>(3, 4, 5, 6)), native.windows)
        assertEquals(listOf(0L, 2L), native.windowStartsMilliseconds)
        assertEquals(1, native.maximumActiveDecodes)
        assertTrue(events.filterIsInstance<LiveDraftUpdated>().isNotEmpty())
        engine.close()
        assertEquals(1, native.cancelCalls)
        assertEquals(1, native.freedRuns)
        assertEquals(1, native.freedContexts)
    }

    @Test
    fun `queue drops and sequence gaps emit privacy safe incomplete degradation`() {
        val native = DraftNativeApi()
        val events = mutableListOf<LiveDraftRuntimeEvent>()
        val engine =
            WhisperDraftEngine(
                runId = "draft-1",
                modelProvider = readyModel(),
                native = native,
                eventEmitter = events::add,
                sampleRateHz = 1_000,
                windowSamples = 4,
                strideSamples = 2,
            )
        engine.start()

        engine.onBacklog(queuedFrames = 3, droppedFrames = 2)
        engine.consume(pcmFrame(0, 1, 2))
        engine.consume(pcmFrame(2, 5, 6))

        val degraded = events.filterIsInstance<LiveDraftDegraded>()
        assertEquals(
            listOf("transcription_live_backlog", "transcription_live_pcm_gap"),
            degraded.map { it.code },
        )
        assertTrue(degraded.all { it.incomplete })
        assertTrue(degraded.all { it.backlogMilliseconds >= 0 })
        assertFalse(degraded.toString().contains("/data/"))
        engine.close()
    }

    @Test
    fun `model failure never opens native context and reports stable degradation`() {
        val native = DraftNativeApi()
        val events = mutableListOf<LiveDraftRuntimeEvent>()
        val engine =
            WhisperDraftEngine(
                runId = "draft-1",
                modelProvider = WhisperModelProvider { ModelMaterializationResult.Failure("model_sha256_mismatch") },
                native = native,
                eventEmitter = events::add,
                windowSamples = 4,
                strideSamples = 2,
            )

        assertEquals(
            LiveDraftStartResult.Failure("transcription_model_hash_mismatch"),
            engine.start(),
        )
        assertEquals(0, native.createdContexts)
        assertEquals(
            "transcription_model_hash_mismatch",
            events.filterIsInstance<LiveDraftDegraded>().single().code,
        )
    }
}

private fun readyModel(): WhisperModelProvider {
    val model = File.createTempFile("loquiris-draft-model", ".bin").apply { deleteOnExit() }
    return WhisperModelProvider { ModelMaterializationResult.Ready(model) }
}

private fun pcmFrame(
    sequence: Long,
    vararg samples: Int,
): PcmCaptureFrame {
    val bytes = ByteArray(samples.size * 2)
    samples.forEachIndexed { index, sample ->
        bytes[index * 2] = (sample and 0xff).toByte()
        bytes[index * 2 + 1] = ((sample ushr 8) and 0xff).toByte()
    }
    return PcmCaptureFrame(sequence, bytes)
}

private class DraftNativeApi : WhisperNativeApi {
    val windows = mutableListOf<List<Short>>()
    val windowStartsMilliseconds = mutableListOf<Long>()
    val languageHints = mutableListOf<TranscriptionLanguageHint>()
    var maximumActiveDecodes = 0
        private set
    var createdContexts = 0
        private set
    var cancelCalls = 0
        private set
    var freedRuns = 0
        private set
    var freedContexts = 0
        private set
    private var activeDecodes = 0
    private var resultSequence = 10L
    private val resultStarts = mutableMapOf<Long, Long>()

    override fun createContext(modelPath: String): Long {
        createdContexts += 1
        return 1
    }

    override fun freeContext(handle: Long) {
        freedContexts += 1
    }

    override fun createRun(): Long = 2

    override fun cancelRun(handle: Long) {
        cancelCalls += 1
    }

    override fun freeRun(handle: Long) {
        freedRuns += 1
    }

    override fun transcribePcm(
        contextHandle: Long,
        runHandle: Long,
        pcm: ShortArray,
        windowStartMilliseconds: Long,
        languageHint: TranscriptionLanguageHint,
    ): Long {
        activeDecodes += 1
        maximumActiveDecodes = maxOf(maximumActiveDecodes, activeDecodes)
        windows += pcm.toList()
        windowStartsMilliseconds += windowStartMilliseconds
        languageHints += languageHint
        val result = resultSequence++
        resultStarts[result] = windowStartMilliseconds
        activeDecodes -= 1
        return result
    }

    override fun segmentCount(resultHandle: Long): Int = 1

    override fun segmentStartMilliseconds(
        resultHandle: Long,
        index: Int,
    ): Long = checkNotNull(resultStarts[resultHandle])

    override fun segmentEndMilliseconds(
        resultHandle: Long,
        index: Int,
    ): Long = checkNotNull(resultStarts[resultHandle]) + 2

    override fun segmentText(
        resultHandle: Long,
        index: Int,
    ): String = "draft $resultHandle"

    override fun freeResult(handle: Long) = Unit

    override fun engineVersion(): String = "1.9.4"

    override fun lastErrorCode(): String? = null
}
