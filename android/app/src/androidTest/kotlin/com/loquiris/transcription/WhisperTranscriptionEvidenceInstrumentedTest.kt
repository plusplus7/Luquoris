package com.loquiris.transcription

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Debug
import android.os.PowerManager
import android.os.SystemClock
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.loquiris.recording.PcmCaptureFrame
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import kotlin.math.max
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Single-run physical-device smoke evidence; not an accuracy, p95, UI, or long-run benchmark. */
@RunWith(AndroidJUnit4::class)
class WhisperTranscriptionEvidenceInstrumentedTest {
    @Test
    fun fixedAuthorizedFixtureProducesDeviceEvidence() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val arguments = InstrumentationRegistry.getArguments()
        val expectedApkSha256 = requireNotNull(arguments.getString("installedApkSha256"))
        val buildCommit = requireNotNull(arguments.getString("buildCommit"))
        val sourceApk = File(context.applicationInfo.sourceDir)
        val installedApkDigest = MessageDigest.getInstance("SHA-256")
        sourceApk.inputStream().buffered().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                installedApkDigest.update(buffer, 0, count)
            }
        }
        val installedApkSha256 =
            installedApkDigest
                .digest()
                .joinToString("") { byte -> "%02x".format(byte) }
        assertEquals(expectedApkSha256, installedApkSha256)

        val fixtureBytes =
            context.assets
                .open("flutter_assets/assets/benchmarks/audio/zh_en_mixed_v1.wav")
                .use { it.readBytes() }
        val fixtureSha256 =
            MessageDigest
                .getInstance("SHA-256")
                .digest(fixtureBytes)
                .joinToString("") { byte -> "%02x".format(byte) }
        assertEquals(
            "83440d4ccbd82dafd1a88346ab448e1dd309e408c598d665413b910cc92c40a7",
            fixtureSha256,
        )
        val dataMarker = "data".toByteArray()
        val dataOffset =
            fixtureBytes.indices.firstOrNull { index ->
                index + 8 <= fixtureBytes.size &&
                    fixtureBytes.copyOfRange(index, index + 4).contentEquals(dataMarker)
            } ?: error("WAV data chunk missing")
        val dataLength =
            ByteBuffer
                .wrap(fixtureBytes, dataOffset + 4, 4)
                .order(ByteOrder.LITTLE_ENDIAN)
                .int
        val pcmOffset = dataOffset + 8
        require(dataLength >= 0 && pcmOffset + dataLength <= fixtureBytes.size && dataLength % 2 == 0)
        val pcm = ShortArray(dataLength / 2)
        ByteBuffer
            .wrap(fixtureBytes, pcmOffset, dataLength)
            .order(ByteOrder.LITTLE_ENDIAN)
            .asShortBuffer()
            .get(pcm)
        val audioDurationMilliseconds = pcm.size * 1_000L / 16_000L
        assertEquals(45_000L, audioDurationMilliseconds)

        val batteryManager = context.getSystemService(BatteryManager::class.java)
        val powerManager = context.getSystemService(PowerManager::class.java)
        val batteryBefore =
            context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val energyBefore = batteryManager.getLongProperty(BatteryManager.BATTERY_PROPERTY_ENERGY_COUNTER)
        val chargeBefore = batteryManager.getLongProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
        val cpuBeforeMilliseconds = Debug.threadCpuTimeNanos() / 1_000_000L
        val pssBeforeKilobytes = Debug.getPss()
        val thermalBefore = powerManager.currentThermalStatus

        val materializationStarted = SystemClock.elapsedRealtimeNanos()
        val model = WhisperModelStore(context).materialize() as ModelMaterializationResult.Ready
        val materializationMilliseconds =
            (SystemClock.elapsedRealtimeNanos() - materializationStarted) / 1_000_000L

        val liveEvents = mutableListOf<LiveDraftRuntimeEvent>()
        var firstTextAtNanos = 0L
        val liveStartedAtNanos = SystemClock.elapsedRealtimeNanos()
        val liveEngine =
            WhisperDraftEngine(
                runId = "phase-11-device-smoke",
                modelProvider = WhisperModelStore(context),
                native = JniWhisperNativeApi,
                eventEmitter = { event ->
                    liveEvents.add(event)
                    if (
                        firstTextAtNanos == 0L &&
                            event is LiveDraftUpdated &&
                            event.segment.displayText.isNotBlank()
                    ) {
                        firstTextAtNanos = SystemClock.elapsedRealtimeNanos()
                    }
                },
            )
        assertEquals(LiveDraftStartResult.Started, liveEngine.start())
        val frameSamples = 320
        val maximumLiveFrames = minOf(pcm.size / frameSamples, 750)
        for (frameIndex in 0 until maximumLiveFrames) {
            val deadline = liveStartedAtNanos + frameIndex * 20_000_000L
            val remainingNanos = deadline - SystemClock.elapsedRealtimeNanos()
            if (remainingNanos > 0) {
                SystemClock.sleep(max(1L, remainingNanos / 1_000_000L))
            }
            val bytes = ByteArray(frameSamples * 2)
            ByteBuffer
                .wrap(bytes)
                .order(ByteOrder.LITTLE_ENDIAN)
                .asShortBuffer()
                .put(pcm, frameIndex * frameSamples, frameSamples)
            liveEngine.consume(PcmCaptureFrame(frameIndex.toLong(), bytes))
            if (firstTextAtNanos != 0L) break
        }
        assertTrue("No visible live draft was emitted", firstTextAtNanos != 0L)
        val firstTextLatencyMilliseconds = (firstTextAtNanos - liveStartedAtNanos) / 1_000_000L
        val liveUpdates = liveEvents.filterIsInstance<LiveDraftUpdated>()
        val liveDegradations = liveEvents.filterIsInstance<LiveDraftDegraded>()
        assertTrue(liveUpdates.any { it.segment.displayText.isNotBlank() })
        assertTrue(liveDegradations.none { it.code.startsWith("transcription_native_") })
        liveEngine.close()
        repeat(100) {
            if (JniWhisperNativeApi.activeHandleCounts() == NativeHandleCounts(0, 0, 0)) {
                return@repeat
            }
            SystemClock.sleep(50)
        }
        assertEquals(NativeHandleCounts(0, 0, 0), JniWhisperNativeApi.activeHandleCounts())
        val pssAfterLiveKilobytes = Debug.getPss()

        val native = JniWhisperNativeApi
        val contextHandle = native.createContext(model.file.absolutePath)
        assertTrue(native.lastErrorCode().orEmpty(), contextHandle != 0L)
        val runHandle = native.createRun()
        assertTrue(native.lastErrorCode().orEmpty(), runHandle != 0L)
        var resultHandle = 0L
        var postSegmentCount = 0
        var postVisibleText = false
        var postTimestampsMonotonic = true
        val postStartedAtNanos = SystemClock.elapsedRealtimeNanos()
        try {
            resultHandle = native.transcribePcm(contextHandle, runHandle, pcm, 0)
            assertTrue(native.lastErrorCode().orEmpty(), resultHandle != 0L)
            postSegmentCount = native.segmentCount(resultHandle)
            var previousEnd = 0L
            repeat(postSegmentCount) { index ->
                val start = native.segmentStartMilliseconds(resultHandle, index)
                val end = native.segmentEndMilliseconds(resultHandle, index)
                postTimestampsMonotonic =
                    postTimestampsMonotonic && start >= previousEnd && end >= start
                postVisibleText = postVisibleText || native.segmentText(resultHandle, index).isNotBlank()
                previousEnd = end
            }
        } finally {
            if (resultHandle != 0L) native.freeResult(resultHandle)
            native.freeRun(runHandle)
            native.freeContext(contextHandle)
        }
        val postElapsedMilliseconds =
            (SystemClock.elapsedRealtimeNanos() - postStartedAtNanos) / 1_000_000L
        assertTrue(postSegmentCount > 0)
        assertTrue(postVisibleText)
        assertTrue(postTimestampsMonotonic)
        assertEquals(NativeHandleCounts(0, 0, 0), native.activeHandleCounts())

        val cpuAfterMilliseconds = Debug.threadCpuTimeNanos() / 1_000_000L
        val pssAfterPostKilobytes = Debug.getPss()
        val thermalAfter = powerManager.currentThermalStatus
        val energyAfter = batteryManager.getLongProperty(BatteryManager.BATTERY_PROPERTY_ENERGY_COUNTER)
        val chargeAfter = batteryManager.getLongProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
        val batteryAfter =
            context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)

        val report =
            JSONObject()
                .put("schemaVersion", 1)
                .put("status", "passed")
                .put("scope", "single-run-device-smoke")
                .put(
                    "limitations",
                    JSONArray()
                        .put("One authorized mixed-language fixture; no CER, WER, or MER claim.")
                        .put("One run; not a p50/p95 latency or sustained-RTF benchmark.")
                        .put("No Flutter frame timing, microphone capture, durable database, restart, retry, or playback measurement.")
                        .put("PSS values are checkpoints, not continuously sampled peak PSS."),
                ).put(
                    "build",
                    JSONObject()
                        .put("commit", buildCommit)
                        .put("packageName", context.packageName)
                        .put("versionName", packageInfo.versionName)
                        .put("versionCode", packageInfo.longVersionCode)
                        .put("installedApkSha256", installedApkSha256),
                ).put(
                    "device",
                    JSONObject()
                        .put("manufacturer", Build.MANUFACTURER)
                        .put("model", Build.MODEL)
                        .put("device", Build.DEVICE)
                        .put("fingerprint", Build.FINGERPRINT)
                        .put("sdkInt", Build.VERSION.SDK_INT)
                        .put("supportedAbis", JSONArray(Build.SUPPORTED_ABIS.toList()))
                        .put("availableProcessors", Runtime.getRuntime().availableProcessors()),
                ).put(
                    "engine",
                    JSONObject()
                        .put("id", "whisper.cpp")
                        .put("version", native.engineVersion())
                        .put("modelId", WhisperModelStore.REVIEWED_BASE_Q5_MODEL.id)
                        .put("modelSha256", WhisperModelStore.REVIEWED_BASE_Q5_MODEL.sha256)
                        .put("modelBytes", WhisperModelStore.REVIEWED_BASE_Q5_MODEL.bytes)
                        .put("materializationMilliseconds", materializationMilliseconds),
                ).put(
                    "fixture",
                    JSONObject()
                        .put("id", "zh-en-mixed-v1")
                        .put("sha256", fixtureSha256)
                        .put("durationMilliseconds", audioDurationMilliseconds)
                        .put("sampleRateHz", 16_000)
                        .put("channels", 1)
                        .put("languageCoverage", JSONArray(listOf("zh-CN", "en", "zh-en-code-switching"))),
                ).put(
                    "liveDraft",
                    JSONObject()
                        .put("firstTextLatencyMilliseconds", firstTextLatencyMilliseconds)
                        .put("updateCount", liveUpdates.size)
                        .put("stableUpdateCount", liveUpdates.count { it.segment.stable })
                        .put("unstableUpdateCount", liveUpdates.count { !it.segment.stable })
                        .put("maximumReportedBacklogMilliseconds", liveUpdates.maxOfOrNull { it.backlogMilliseconds } ?: 0)
                        .put("degradationCodes", JSONArray(liveDegradations.map { it.code }.distinct())),
                ).put(
                    "postSession",
                    JSONObject()
                        .put("elapsedMilliseconds", postElapsedMilliseconds)
                        .put("realTimeFactor", postElapsedMilliseconds.toDouble() / audioDurationMilliseconds)
                        .put("segmentCount", postSegmentCount)
                        .put("visibleText", postVisibleText)
                        .put("timestampsMonotonic", postTimestampsMonotonic),
                ).put(
                    "resources",
                    JSONObject()
                        .put("threadCpuMilliseconds", cpuAfterMilliseconds - cpuBeforeMilliseconds)
                        .put("pssBeforeKilobytes", pssBeforeKilobytes)
                        .put("pssAfterLiveKilobytes", pssAfterLiveKilobytes)
                        .put("pssAfterPostKilobytes", pssAfterPostKilobytes)
                        .put(
                            "pssCheckpointMaximumKilobytes",
                            max(pssBeforeKilobytes, max(pssAfterLiveKilobytes, pssAfterPostKilobytes)),
                        ).put("thermalStatusBefore", thermalBefore)
                        .put("thermalStatusAfter", thermalAfter)
                        .put("batteryTemperatureTenthsCelsiusBefore", batteryBefore?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1))
                        .put("batteryTemperatureTenthsCelsiusAfter", batteryAfter?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1))
                        .put("energyCounterBefore", energyBefore)
                        .put("energyCounterAfter", energyAfter)
                        .put("chargeCounterMicroampereHoursBefore", chargeBefore)
                        .put("chargeCounterMicroampereHoursAfter", chargeAfter),
                ).put("nativeFailureCount", liveDegradations.count { it.code.startsWith("transcription_native_") })
                .put("activeNativeHandlesAfter", JSONObject().put("contexts", 0).put("runs", 0).put("results", 0))

        val output = File(context.filesDir, "device-validation/phase-11-whisper-transcription-device.json")
        assertTrue(output.parentFile?.mkdirs() != false)
        output.writeText(report.toString(2) + "\n")
        assertNotNull(JSONObject(output.readText()).getJSONObject("postSession"))
    }
}
