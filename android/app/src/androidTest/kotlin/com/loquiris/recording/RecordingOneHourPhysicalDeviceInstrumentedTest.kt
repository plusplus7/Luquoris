package com.loquiris.recording

import android.app.ActivityManager
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class RecordingOneHourPhysicalDeviceInstrumentedTest {
    @get:Rule
    val permissions = RecordingInstrumentedTestHarness.permissions()

    @Test
    fun recordsContinuouslyForOneHourAndFinalizesDurableSegments() {
        val arguments = InstrumentationRegistry.getArguments()
        assumeTrue(
            "one-hour physical-device run requires explicit host opt-in",
            arguments.getString(OPT_IN_ARGUMENT) == "true",
        )

        val context = RecordingInstrumentedTestHarness.context
        assertEquals("one-hour evidence must run on the selected acceptance model", TARGET_MODEL, Build.MODEL)
        assertEquals("one-hour evidence must run on the selected acceptance device", TARGET_DEVICE, Build.DEVICE)
        val observer = RecordingOneHourRunObserver(context)
        val sessionId = "one-hour-${System.currentTimeMillis()}"
        var failure: Throwable? = null

        RecordingInstrumentedTestHarness.reset()
        try {
            assertFalse(
                "acceptance device must be manually unlocked before starting the one-hour run",
                context.getSystemService(KeyguardManager::class.java).isKeyguardLocked,
            )
            RecordingInstrumentedTestHarness.launchMainActivity()
            RecordingInstrumentedTestHarness.startAndAwaitRecording(sessionId)
            RecordingInstrumentedTestHarness.pressHome()
            RecordingInstrumentedTestHarness.turnScreenOff()
            assertTrue(
                "screen did not become non-interactive for the locked/background run",
                RecordingInstrumentedTestHarness.waitUntil {
                    !context.getSystemService(PowerManager::class.java).isInteractive
                },
            )

            val startedAtElapsedRealtime = SystemClock.elapsedRealtime()
            observer.record(minute = 0, snapshot = RecordingInstrumentedTestHarness.requireSnapshot())
            observer.persist(sessionId = sessionId, status = "running")

            for (minute in 1..REQUIRED_MINUTES) {
                val remaining =
                    startedAtElapsedRealtime + minute * SAMPLE_INTERVAL_MILLIS -
                        SystemClock.elapsedRealtime()
                if (remaining > 0L) SystemClock.sleep(remaining)
                observer.record(
                    minute = minute,
                    snapshot = RecordingInstrumentedTestHarness.requireSnapshot(),
                )
                observer.persist(sessionId = sessionId, status = "running")
                if (context.getSystemService(PowerManager::class.java).isInteractive) {
                    RecordingInstrumentedTestHarness.turnScreenOff()
                    assertTrue(
                        "screen could not be returned to non-interactive state at minute $minute",
                        RecordingInstrumentedTestHarness.waitUntil {
                            !context.getSystemService(PowerManager::class.java).isInteractive
                        },
                    )
                }
            }

            val beforeStop = RecordingInstrumentedTestHarness.requireSnapshot()
            assertTrue(
                "one-hour run did not retain sufficient screen-off coverage",
                observer.samples().count { !it.screenInteractive } >= REQUIRED_SCREEN_OFF_SAMPLES,
            )
            assertTrue(
                "recording media duration did not reach one hour: ${beforeStop.elapsedMilliseconds}",
                beforeStop.elapsedMilliseconds >= REQUIRED_DURATION_MILLIS,
            )
            assertTrue(
                "one-hour stop command was not accepted",
                RecordingForegroundService.stop(context, sessionId, "one-hour-stop"),
            )
            assertTrue(
                "one-hour recording did not finalize cleanly",
                RecordingInstrumentedTestHarness.waitUntil(timeoutMilliseconds = FINALIZATION_TIMEOUT_MILLIS) {
                    val snapshot = RecordingInstrumentedTestHarness.requireSnapshot()
                    snapshot.state == NativeRecordingState.finalized &&
                        !RecordingProcessLiveness.owns(sessionId) &&
                        RecordingInstrumentedTestHarness.activeNotifications().isEmpty()
                },
            )

            val finalized = RecordingInstrumentedTestHarness.requireSnapshot()
            val integrity = verifyDurableSegments(context, sessionId, finalized.elapsedMilliseconds)
            assertEquals(NativeRecordingState.finalized, finalized.state)
            assertTrue("finalized byte count regressed", finalized.bytesWritten >= beforeStop.bytesWritten)
            observer.persist(
                sessionId = sessionId,
                status = "passed",
                finalSnapshot = finalized,
                integrity = integrity,
            )
        } catch (caught: Throwable) {
            failure = caught
            observer.persist(
                sessionId = sessionId,
                status = "failed",
                failure = caught.javaClass.simpleName,
            )
            throw caught
        } finally {
            if (failure != null) {
                val snapshot = runCatching { RecordingInstrumentedTestHarness.requireSnapshot() }.getOrNull()
                if (
                    snapshot?.sessionId == sessionId &&
                    snapshot.state in PersistedRecordingStateMachine.activeStates &&
                    RecordingProcessLiveness.owns(sessionId)
                ) {
                    RecordingForegroundService.stop(context, sessionId, "one-hour-failure-cleanup")
                    RecordingInstrumentedTestHarness.waitUntil(
                        timeoutMilliseconds = FINALIZATION_TIMEOUT_MILLIS,
                    ) {
                        !RecordingProcessLiveness.owns(sessionId)
                    }
                }
            }
            RecordingInstrumentedTestHarness.wakeScreen()
        }
    }

    private fun verifyDurableSegments(
        context: Context,
        sessionId: String,
        finalizedMediaDurationMilliseconds: Long,
    ): RecordingOneHourIntegrity {
        val directory = AppPrivateRecordingStorage.sessionDirectory(context, sessionId)
        val loaded = AtomicRecordingSegmentManifestStore(directory).load()
        assertTrue(
            "one-hour segment manifest is corrupt or missing: $loaded",
            loaded is RecordingSegmentManifestDecodeResult.Success,
        )
        val manifest = (loaded as RecordingSegmentManifestDecodeResult.Success).manifest
        assertEquals(sessionId, manifest.sessionId)
        assertTrue("one-hour run did not exercise logical segment rollover", manifest.segments.size > 1)

        var committedFrames = 0L
        var committedBytes = 0L
        var committedSamples = 0L
        manifest.segments.forEach { segment ->
            assertEquals(
                "manifest segment sample offset does not match the preceding durable prefix: ${segment.index}",
                committedSamples,
                segment.startSample,
            )
            val data = File(directory, segment.dataFileName)
            val journal = File(directory, segment.journalFileName)
            assertTrue("missing segment data file: ${segment.dataFileName}", data.isFile && data.length() > 0L)
            assertTrue("missing segment journal: ${segment.journalFileName}", journal.isFile && journal.length() > 0L)
            val recovered = RecordingCommittedPrefixRecovery.recover(data.readBytes(), journal.readBytes())
            assertTrue("segment has no durable committed frames: ${segment.index}", recovered.committedFrames > 0)
            assertEquals(
                "segment contains bytes outside its durable committed prefix: ${segment.index}",
                0,
                recovered.uncommittedOrInvalidBytes,
            )
            assertEquals(data.length(), recovered.committedBytes.toLong())
            committedFrames += recovered.committedFrames
            committedBytes += recovered.committedBytes
            committedSamples += recovered.committedSamples
        }
        val expectedFileNames =
            manifest.segments
                .flatMap { listOf(it.dataFileName, it.journalFileName) }
                .plus(AtomicRecordingSegmentManifestStore.MANIFEST_FILE_NAME)
                .toSet()
        val actualFileNames = directory.listFiles().orEmpty().map(File::getName).toSet()
        assertEquals("recording directory contains orphan or missing authoritative files", expectedFileNames, actualFileNames)
        val committedDurationMilliseconds = committedSamples * 1_000L / manifest.sampleRateHz
        val durationDeltaMilliseconds =
            kotlin.math.abs(committedDurationMilliseconds - finalizedMediaDurationMilliseconds)
        assertTrue(
            "durable audio duration differs from finalized media time by $durationDeltaMilliseconds ms",
            durationDeltaMilliseconds <= MAX_DURATION_DELTA_MILLIS,
        )
        return RecordingOneHourIntegrity(
            segmentCount = manifest.segments.size,
            committedFrames = committedFrames,
            committedBytes = committedBytes,
            committedSamples = committedSamples,
            committedDurationMilliseconds = committedDurationMilliseconds,
            durationDeltaMilliseconds = durationDeltaMilliseconds,
        )
    }

    private companion object {
        const val OPT_IN_ARGUMENT = "loquirisOneHour"
        const val TARGET_MODEL = "M2104K10AC"
        const val TARGET_DEVICE = "chopin"
        const val REQUIRED_MINUTES = 60
        const val REQUIRED_SCREEN_OFF_SAMPLES = 60
        const val SAMPLE_INTERVAL_MILLIS = 60_000L
        const val REQUIRED_DURATION_MILLIS = REQUIRED_MINUTES * SAMPLE_INTERVAL_MILLIS
        const val FINALIZATION_TIMEOUT_MILLIS = 60_000L
        const val MAX_DURATION_DELTA_MILLIS = 1_000L
    }
}

internal data class RecordingOneHourIntegrity(
    val segmentCount: Int,
    val committedFrames: Long,
    val committedBytes: Long,
    val committedSamples: Long,
    val committedDurationMilliseconds: Long,
    val durationDeltaMilliseconds: Long,
)

internal data class RecordingOneHourSample(
    val minute: Int,
    val wallClockEpochMilliseconds: Long,
    val elapsedRealtimeMilliseconds: Long,
    val mediaElapsedMilliseconds: Long,
    val bytesWritten: Long,
    val revision: Long,
    val notificationCount: Int,
    val processPssKilobytes: Int,
    val batteryPercent: Int,
    val batteryPlugged: Int,
    val batteryTemperatureTenthsCelsius: Int,
    val thermalStatus: Int,
    val availableBytes: Long,
    val screenInteractive: Boolean,
)

internal class RecordingOneHourRunObserver(
    private val context: Context,
) {
    private val observed = mutableListOf<RecordingOneHourSample>()
    private val reportDirectory = File(context.filesDir, REPORT_DIRECTORY)
    private var observedSessionId: String? = null

    fun samples(): List<RecordingOneHourSample> = observed.toList()

    fun record(
        minute: Int,
        snapshot: NativeRecordingSnapshot,
    ) {
        assertEquals("recording left active state at minute $minute", NativeRecordingState.recording, snapshot.state)
        val expectedSessionId = observedSessionId
        if (expectedSessionId == null) {
            observedSessionId = snapshot.sessionId
        } else {
            assertEquals("unexpected session switch at minute $minute", expectedSessionId, snapshot.sessionId)
        }
        val notificationCount = RecordingInstrumentedTestHarness.activeNotifications().size
        assertEquals("foreground notification count at minute $minute", 1, notificationCount)
        assertTrue("service liveness was lost at minute $minute", RecordingProcessLiveness.owns(snapshot.sessionId))
        val screenInteractive = context.getSystemService(PowerManager::class.java).isInteractive

        val previous = observed.lastOrNull()
        if (previous != null) {
            assertTrue(
                "media time did not advance at minute $minute: ${previous.mediaElapsedMilliseconds} -> ${snapshot.elapsedMilliseconds}",
                snapshot.elapsedMilliseconds > previous.mediaElapsedMilliseconds,
            )
            assertTrue(
                "canonical bytes did not advance at minute $minute: ${previous.bytesWritten} -> ${snapshot.bytesWritten}",
                snapshot.bytesWritten > previous.bytesWritten,
            )
            assertTrue(
                "snapshot revision regressed at minute $minute: ${previous.revision} -> ${snapshot.revision}",
                snapshot.revision >= previous.revision,
            )
        }
        val battery = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        observed +=
            RecordingOneHourSample(
                minute = minute,
                wallClockEpochMilliseconds = System.currentTimeMillis(),
                elapsedRealtimeMilliseconds = SystemClock.elapsedRealtime(),
                mediaElapsedMilliseconds = snapshot.elapsedMilliseconds,
                bytesWritten = snapshot.bytesWritten,
                revision = snapshot.revision,
                notificationCount = notificationCount,
                processPssKilobytes = processPssKilobytes(),
                batteryPercent = battery?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1,
                batteryPlugged = battery?.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1) ?: -1,
                batteryTemperatureTenthsCelsius =
                    battery?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1) ?: -1,
                thermalStatus = context.getSystemService(PowerManager::class.java).currentThermalStatus,
                availableBytes = context.filesDir.usableSpace,
                screenInteractive = screenInteractive,
            )
    }

    fun persist(
        sessionId: String,
        status: String,
        finalSnapshot: NativeRecordingSnapshot? = null,
        integrity: RecordingOneHourIntegrity? = null,
        failure: String? = null,
    ) {
        val report =
            JSONObject()
                .put("schemaVersion", 1)
                .put("status", status)
                .put("evidenceClass", "preliminary-exploratory")
                .put("acceptanceEligible", false)
                .put("acceptanceIneligibilityReason", "ambient_temperature_not_measured")
                .put("sessionId", sessionId)
                .put("deviceModel", Build.MODEL)
                .put("deviceProduct", Build.PRODUCT)
                .put("deviceName", Build.DEVICE)
                .put("hardware", Build.HARDWARE)
                .put("socManufacturer", Build.SOC_MANUFACTURER)
                .put("socModel", Build.SOC_MODEL)
                .put("deviceFingerprint", Build.FINGERPRINT)
                .put("buildDisplay", Build.DISPLAY)
                .put("buildIncremental", Build.VERSION.INCREMENTAL)
                .put("securityPatch", Build.VERSION.SECURITY_PATCH)
                .put("sdkInt", Build.VERSION.SDK_INT)
                .put("totalRamBytes", totalRamBytes())
                .put("totalPrivateStorageBytes", context.filesDir.totalSpace)
                .put("batteryHealth", batteryHealth())
                .put("ambientTemperatureCelsius", JSONObject.NULL)
                .put("ambientTemperatureSource", "not-measured")
                .put(
                    "testConfiguration",
                    JSONObject()
                        .put("captureMode", "recording-only")
                        .put("screenOffRequested", true)
                        .put("minimumScreenOffSamples", 60)
                        .put("sampleCountExpected", 61)
                        .put("acousticMaterial", "ambient-uncontrolled"),
                )
                .put("requiredDurationMilliseconds", REQUIRED_DURATION_MILLIS)
                .put("sampleIntervalMilliseconds", SAMPLE_INTERVAL_MILLIS)
                .put("screenInteractiveSampleCount", observed.count(RecordingOneHourSample::screenInteractive))
                .put("samples", JSONArray(observed.map(::sampleJson)))
        finalSnapshot?.let {
            report.put(
                "finalSnapshot",
                JSONObject()
                    .put("state", it.state.name)
                    .put("elapsedMilliseconds", it.elapsedMilliseconds)
                    .put("bytesWritten", it.bytesWritten)
                    .put("revision", it.revision),
            )
        }
        integrity?.let {
            report.put(
                "integrity",
                JSONObject()
                    .put("segmentCount", it.segmentCount)
                    .put("committedFrames", it.committedFrames)
                    .put("committedBytes", it.committedBytes)
                    .put("committedSamples", it.committedSamples)
                    .put("committedDurationMilliseconds", it.committedDurationMilliseconds)
                    .put("durationDeltaMilliseconds", it.durationDeltaMilliseconds),
            )
        }
        failure?.let { report.put("failureClass", it) }
        writeSynced(report.toString(2).toByteArray())
    }

    private fun processPssKilobytes(): Int =
        context
            .getSystemService(ActivityManager::class.java)
            .getProcessMemoryInfo(intArrayOf(Process.myPid()))
            .single()
            .totalPss

    private fun totalRamBytes(): Long =
        ActivityManager.MemoryInfo().also {
            context.getSystemService(ActivityManager::class.java).getMemoryInfo(it)
        }.totalMem

    private fun batteryHealth(): Int =
        context
            .registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            ?.getIntExtra(BatteryManager.EXTRA_HEALTH, -1)
            ?: -1

    private fun sampleJson(sample: RecordingOneHourSample) =
        JSONObject()
            .put("minute", sample.minute)
            .put("wallClockEpochMilliseconds", sample.wallClockEpochMilliseconds)
            .put("elapsedRealtimeMilliseconds", sample.elapsedRealtimeMilliseconds)
            .put("mediaElapsedMilliseconds", sample.mediaElapsedMilliseconds)
            .put("bytesWritten", sample.bytesWritten)
            .put("revision", sample.revision)
            .put("notificationCount", sample.notificationCount)
            .put("processPssKilobytes", sample.processPssKilobytes)
            .put("batteryPercent", sample.batteryPercent)
            .put("batteryPlugged", sample.batteryPlugged)
            .put("batteryTemperatureTenthsCelsius", sample.batteryTemperatureTenthsCelsius)
            .put("thermalStatus", sample.thermalStatus)
            .put("availableBytes", sample.availableBytes)
            .put("screenInteractive", sample.screenInteractive)

    private fun writeSynced(bytes: ByteArray) {
        if (!reportDirectory.exists()) {
            assertTrue("unable to create one-hour report directory", reportDirectory.mkdirs())
            assertTrue(
                "unable to sync one-hour report parent directory",
                AndroidRecordingFileOperations.syncDirectory(checkNotNull(reportDirectory.parentFile)),
            )
        }
        val temporary = File(reportDirectory, "$REPORT_FILE.tmp")
        val destination = File(reportDirectory, REPORT_FILE)
        assertTrue(
            "unable to sync one-hour temporary report",
            AndroidRecordingFileOperations.writeAndSync(temporary, bytes),
        )
        assertTrue(
            "unable to atomically publish one-hour report",
            AndroidRecordingFileOperations.atomicReplace(temporary, destination),
        )
        assertTrue(
            "unable to sync one-hour report directory",
            AndroidRecordingFileOperations.syncDirectory(reportDirectory),
        )
    }

    private companion object {
        const val REPORT_DIRECTORY = "device-validation"
        const val REPORT_FILE = "recording-one-hour.json"
        const val REQUIRED_DURATION_MILLIS = 3_600_000L
        const val SAMPLE_INTERVAL_MILLIS = 60_000L
    }
}
