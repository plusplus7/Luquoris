package com.loquiris.transcription

import java.io.File
import java.nio.file.Files
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WhisperPostSessionEngineTest {
    @Test
    fun `forwards the requested language to every native window`() {
        val native = FakeNativeApi()

        engine(native = native).transcribe(
            "meeting-1",
            languageHint = TranscriptionLanguageHint.english,
        )

        assertEquals(
            listOf(TranscriptionLanguageHint.english, TranscriptionLanguageHint.english),
            native.languageHints,
        )
    }

    @Test
    fun `live reservation pauses post session inference and cancellation unblocks it`() {
        val live = WhisperInferenceArbiter.process.acquireLive { false }!!
        val cancellation = TranscriptionCancellation()
        val atWindow = CountDownLatch(1)
        val native = FakeNativeApi()
        val engine = engine(native, decoder = FakeDecoder { onWindow ->
            atWindow.countDown()
            onWindow(PcmWindow(0, ShortArray(16_000)))
        })
        val executor = Executors.newSingleThreadExecutor()
        try {
            val result = executor.submit<PostSessionTranscriptionResult> {
                engine.transcribe("meeting-1", cancellation)
            }
            assertTrue(atWindow.await(2, TimeUnit.SECONDS))
            cancellation.cancel()
            assertEquals(PostSessionTranscriptionResult.Cancelled, result.get(2, TimeUnit.SECONDS))
            assertEquals(0, native.resultsFreed)
        } finally {
            live.close()
            executor.shutdownNow()
        }
    }

    @Test
    fun `normalizes regressing native timestamps and releases every handle`() {
        val native = FakeNativeApi()
        val engine = engine(native = native)

        val result = engine.transcribe("meeting-1")

        val completed = result as PostSessionTranscriptionResult.Completed
        assertEquals(2, completed.segments.size)
        assertEquals(0L, completed.segments[0].startMilliseconds)
        assertEquals(900L, completed.segments[0].endMilliseconds)
        assertEquals(900L, completed.segments[1].startMilliseconds)
        assertEquals(900L, completed.segments[1].endMilliseconds)
        assertEquals(listOf("first", "second"), completed.segments.map(TranscriptionSegment::displayText))
        assertEquals(1, native.contextsFreed)
        assertEquals(1, native.runsFreed)
        assertEquals(2, native.resultsFreed)
    }

    @Test
    fun `cancellation reaches the active native run and returns a stable outcome`() {
        val cancellation = TranscriptionCancellation()
        val native = FakeNativeApi()
        val decoder =
            FakeDecoder { onWindow ->
                onWindow(PcmWindow(0, ShortArray(16_000)))
                cancellation.cancel()
                onWindow(PcmWindow(16_000, ShortArray(16_000)))
            }
        val engine = engine(native = native, decoder = decoder)

        val result = engine.transcribe("meeting-1", cancellation)

        assertEquals(PostSessionTranscriptionResult.Cancelled, result)
        assertTrue(native.cancelledRuns.isNotEmpty())
        assertEquals(1, native.contextsFreed)
        assertEquals(1, native.runsFreed)
        assertEquals(1, native.resultsFreed)
    }

    @Test
    fun `maps unknown native failures to one privacy-safe stable code`() {
        val native = FakeNativeApi(createContextResult = 0, errorCode = "native details must not escape")

        assertEquals(
            PostSessionTranscriptionResult.Failure("transcription_native_failed"),
            engine(native = native).transcribe("meeting-1"),
        )
    }

    @Test
    fun `does not misreport native inference failure as cancellation`() {
        val native =
            FakeNativeApi(
                transcribeResult = 0,
                errorCode = "transcription_native_inference_failed",
            )
        val decoder =
            object : AacPcmDecoder {
                override fun decode(
                    audio: AuthoritativeAudioResolution.Ready,
                    onWindow: (PcmWindow) -> Boolean,
                ): AudioDecodeResult =
                    if (onWindow(PcmWindow(0, ShortArray(16_000)))) {
                        AudioDecodeResult.Completed
                    } else {
                        AudioDecodeResult.Cancelled
                    }
            }

        val result = engine(native = native, decoder = decoder).transcribe("meeting-1")

        assertEquals(
            PostSessionTranscriptionResult.Failure("transcription_native_inference_failed"),
            result,
        )
        assertEquals(1, native.contextsFreed)
        assertEquals(1, native.runsFreed)
        assertEquals(0, native.resultsFreed)
    }

    @Test
    fun `transcribes a usable committed partial prefix and retains its warning`() {
        val audio = Files.createTempFile("loquiris-partial-audio", ".adts").toFile()
        val partial =
            AuthoritativeAudioResolution.Partial(
                segments = listOf(AuthoritativeAudioSegment(0, audio, 1, 0, 16_000)),
                totalSamples = 16_000,
                sampleRateHz = 16_000,
                codecSpecificData = listOf(byteArrayOf(1)),
                code = "transcription_audio_uncommitted_tail",
            )

        val result = engine(native = FakeNativeApi(), audioResolution = partial).transcribe("meeting-1")

        val completed = result as PostSessionTranscriptionResult.Completed
        assertEquals("transcription_audio_uncommitted_tail", completed.warningCode)
        assertEquals(2, completed.segments.size)
    }

    @Test
    fun `accepts successful native inference with no speech segments`() {
        val result =
            engine(native = FakeNativeApi(segmentCountResult = 0)).transcribe("meeting-1")

        val completed = result as PostSessionTranscriptionResult.Completed
        assertTrue(completed.segments.isEmpty())
    }

    @Test
    fun `maps an unavailable JNI library to a stable failure`() {
        val native = FakeNativeApi(createContextFailure = UnsatisfiedLinkError("private loader details"))

        assertEquals(
            PostSessionTranscriptionResult.Failure("transcription_native_unavailable"),
            engine(native = native).transcribe("meeting-1"),
        )
    }

    @Test
    fun `maps native allocation exhaustion to a stable failure`() {
        val native = FakeNativeApi(createContextFailure = OutOfMemoryError("private allocation details"))

        assertEquals(
            PostSessionTranscriptionResult.Failure("transcription_native_out_of_memory"),
            engine(native = native).transcribe("meeting-1"),
        )
    }
}

private fun engine(
    native: FakeNativeApi,
    decoder: AacPcmDecoder =
        FakeDecoder { onWindow ->
            onWindow(PcmWindow(0, ShortArray(16_000)))
            onWindow(PcmWindow(16_000, ShortArray(16_000)))
        },
    audioResolution: AuthoritativeAudioResolution? = null,
): WhisperPostSessionEngine {
    val model = Files.createTempFile("loquiris-model", ".bin").toFile()
    val audio = Files.createTempFile("loquiris-audio", ".adts").toFile()
    val segment = AuthoritativeAudioSegment(0, audio, 1, 0, 32_000)
    return WhisperPostSessionEngine(
        audioProvider =
            AuthoritativeAudioProvider {
                audioResolution
                    ?: AuthoritativeAudioResolution.Ready(
                        listOf(segment),
                        32_000,
                        16_000,
                        listOf(byteArrayOf(1)),
                    )
            },
        modelProvider = WhisperModelProvider { ModelMaterializationResult.Ready(model) },
        decoder = decoder,
        native = native,
    )
}

private class FakeDecoder(
    private val action: ((PcmWindow) -> Boolean) -> Unit,
) : AacPcmDecoder {
    override fun decode(
        audio: AuthoritativeAudioResolution.Ready,
        onWindow: (PcmWindow) -> Boolean,
    ): AudioDecodeResult {
        action(onWindow)
        return AudioDecodeResult.Completed
    }
}

private class FakeNativeApi(
    private val createContextResult: Long = 11,
    private val errorCode: String? = null,
    private val transcribeResult: Long? = null,
    private val segmentCountResult: Int = 1,
    private val createContextFailure: Throwable? = null,
) : WhisperNativeApi {
    var contextsFreed = 0
    var runsFreed = 0
    var resultsFreed = 0
    val cancelledRuns = mutableListOf<Long>()
    val languageHints = mutableListOf<TranscriptionLanguageHint>()
    private var transcriptionCalls = 0

    override fun createContext(modelPath: String): Long =
        createContextFailure?.let { throw it } ?: createContextResult

    override fun freeContext(handle: Long) {
        contextsFreed += 1
    }

    override fun createRun(): Long = 22

    override fun cancelRun(handle: Long) {
        cancelledRuns += handle
    }

    override fun freeRun(handle: Long) {
        runsFreed += 1
    }

    override fun transcribePcm(
        contextHandle: Long,
        runHandle: Long,
        pcm: ShortArray,
        windowStartMilliseconds: Long,
        languageHint: TranscriptionLanguageHint,
    ): Long {
        languageHints += languageHint
        transcriptionCalls += 1
        return transcribeResult ?: (30 + transcriptionCalls).toLong()
    }

    override fun segmentCount(resultHandle: Long): Int = segmentCountResult

    override fun segmentStartMilliseconds(
        resultHandle: Long,
        index: Int,
    ): Long = if (resultHandle == 31L) 0 else 700

    override fun segmentEndMilliseconds(
        resultHandle: Long,
        index: Int,
    ): Long = if (resultHandle == 31L) 900 else 800

    override fun segmentText(
        resultHandle: Long,
        index: Int,
    ): String = if (resultHandle == 31L) " first " else " second "

    override fun freeResult(handle: Long) {
        resultsFreed += 1
    }

    override fun engineVersion(): String = "1.9.4"

    override fun lastErrorCode(): String? = errorCode
}
