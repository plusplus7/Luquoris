package com.loquiris.spike

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.provider.MediaStore
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class RealSpeechAacQualityInstrumentedTest {
    @Test
    fun authorizedFiveMinuteSpeechSurvivesLoquirisAacRoundTrip() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val arguments = InstrumentationRegistry.getArguments()
        assumeTrue(
            "Real-speech input is read only when this test class is selected explicitly",
            arguments.getString("class") == javaClass.name,
        )
        val context = instrumentation.targetContext
        val input = File(context.cacheDir, PRIVATE_INPUT_NAME)
        check(input.isFile && input.length() > 0L) {
            "Authorized real-speech input was not staged in the app-private cache"
        }
        val output = File(context.cacheDir, "authorized-real-speech-loquiris-64k.m4a")
        var primaryFailure: Throwable? = null
        try {
            val report = RealSpeechAacQualitySpike().run(input, output)
            val reportJson = report.toJson()
            File(context.filesDir, REPORT_NAME).writeText(reportJson)
            arguments.getString("additionalTestOutputDir")?.let { outputPath ->
                val outputDirectory = File(outputPath)
                check(outputDirectory.mkdirs() || outputDirectory.isDirectory)
                File(outputDirectory, REPORT_NAME).writeText(reportJson)
                if (arguments.getString(EXPORT_DERIVED_FIXTURE_ARGUMENT) == "true") {
                    output.copyTo(File(outputDirectory, OUTPUT_NAME), overwrite = true)
                }
            }

            assertTrue(report.sourceDurationMilliseconds >= 300_000L)
            assertEquals(48_000, report.sourceSampleRateHz)
            assertEquals(2, report.sourceChannelCount)
            assertEquals(16_000, report.referenceSampleRateHz)
            assertEquals(1, report.referenceChannelCount)
            assertTrue(report.referenceSamples >= 4_800_000)
            assertTrue(report.encodedAccessUnits > 0)
            assertEquals(2, report.encoderAudioObjectType)
            assertEquals(16_000, report.encoderSampleRateHz)
            assertEquals(1, report.encoderChannelConfiguration)
            assertTrue(report.encoderAudioSpecificConfigHex.isNotEmpty())
            assertTrue(report.referenceCoverage >= 0.99)
            assertTrue(report.decodedToReferenceSampleRatio in 0.99..1.01)
            assertTrue(report.correlation >= 0.95)
            assertTrue(report.signalToNoiseRatioDb >= 15.0)
            assertTrue(report.outputBytes > 0L)

            if (arguments.getString(PUBLISH_LISTENING_COPY_ARGUMENT) == "true") {
                assertEquals("content", publishForAuthorizedListening(context, output).scheme)
            }
        } catch (failure: Throwable) {
            primaryFailure = failure
            throw failure
        } finally {
            val cleanupFailure =
                finishCodecLifecycle(
                    primaryFailure = primaryFailure,
                    stop = {
                        check(input.delete() || !input.exists()) {
                            "Could not delete app-private real-speech input"
                        }
                    },
                    release = {
                        check(output.delete() || !output.exists()) {
                            "Could not delete app-private real-speech output"
                        }
                    },
                )
            if (primaryFailure == null && cleanupFailure != null) throw cleanupFailure
        }
    }

    private fun publishForAuthorizedListening(
        context: Context,
        output: File,
    ): Uri {
        val resolver = context.contentResolver
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        resolver.delete(
            collection,
            "${MediaStore.MediaColumns.DISPLAY_NAME} = ? AND ${MediaStore.MediaColumns.RELATIVE_PATH} = ?",
            arrayOf(OUTPUT_NAME, "Download/"),
        )
        val values =
            ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, OUTPUT_NAME)
                put(MediaStore.MediaColumns.MIME_TYPE, "audio/mp4")
                put(MediaStore.MediaColumns.RELATIVE_PATH, "Download")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
        val uri = checkNotNull(resolver.insert(collection, values))
        try {
            resolver.openOutputStream(uri, "w").use { destination ->
                checkNotNull(destination)
                output.inputStream().use { source -> source.copyTo(destination) }
            }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            check(resolver.update(uri, values, null, null) == 1)
            return uri
        } catch (failure: Throwable) {
            throw finishPublishedMediaRollback(failure) { resolver.delete(uri, null, null) }
        }
    }

    companion object {
        private const val PRIVATE_INPUT_NAME = "authorized-real-speech-input.aac"
        private const val EXPORT_DERIVED_FIXTURE_ARGUMENT = "loquirisExportDerivedFixture"
        private const val PUBLISH_LISTENING_COPY_ARGUMENT = "loquirisPublishListeningCopy"
        private const val REPORT_NAME = "real-speech-aac-quality-report.json"
        private const val OUTPUT_NAME = "Loquiris-real-speech-64k-test.m4a"
    }
}
