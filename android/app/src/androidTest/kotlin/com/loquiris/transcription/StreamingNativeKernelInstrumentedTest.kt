package com.loquiris.transcription

import android.os.Process
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.loquiris.BuildConfig
import com.loquiris.recording.PcmCaptureFrame
import java.io.File
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** Real existing WAV only; catches absent JNI, empty inference and premature release. */
@RunWith(AndroidJUnit4::class)
class StreamingNativeKernelInstrumentedTest {
    @Test fun consumerKeepsCanonicalGapAcrossRealNativePause() {
        org.junit.Assume.assumeTrue("requires explicit native-spike debug build",
            BuildConfig.LOQUIRIS_STREAMING_NATIVE_SPIKE)
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val wav = File(context.filesDir, "streaming-native-spike-20261016/fixture.wav").readBytes()
        assertEquals("83440d4ccbd82dafd1a88346ab448e1dd309e408c598d665413b910cc92c40a7",
            MessageDigest.getInstance("SHA-256").digest(wav).joinToString("") { "%02x".format(it) })
        val ready = CountDownLatch(1)
        val failures = java.util.concurrent.CopyOnWriteArrayList<StreamingStopCause>()
        val owner = StreamingRemoteIdentity("native-consumer", UUID.randomUUID().toString())
        val binding = StreamingMessengerBinding(context, owner, "1".repeat(64),
            "com.loquiris.spike.StreamingNativeKernelProbeService",
            onFailure = { failures.add(it); ready.countDown() },
            onReply = { reply, _ -> if (reply is StreamingRemoteReply.Ready) ready.countDown() })
        val events = mutableListOf<StreamingCaptureEvent>()
        val consumer = StreamingPcmConsumer(binding.session, { events.addAll(it) }, failures::add)
        try {
            assertTrue(binding.bindRemote())
            assertTrue(ready.await(20, TimeUnit.SECONDS))
            assertTrue("native creation failed: $failures", failures.isEmpty())
            for (part in 0L..1L) {
                for (chunk in 0L until 20L) {
                    val offset = 44 + chunk.toInt() * 6400
                    consumer.consume(PcmCaptureFrame(part * 20 + chunk,
                        wav.copyOfRange(offset, offset + 6400), part * 100000 + chunk * 3200, part))
                }
                consumer.finishBoundary(if (part == 0L) StreamingBoundaryReason.PAUSE else StreamingBoundaryReason.STOP)
            }
            consumer.closeAsync().toCompletableFuture().get(10, TimeUnit.SECONDS)
            assertTrue("real native consumer failed: $failures", failures.isEmpty())
            val texts = events.filterIsInstance<StreamingCaptureText>()
            assertTrue(texts.any { it.rawText.isNotBlank() && !it.finalized })
            val final = texts.filter { it.rawText.isNotBlank() && it.finalized }
            assertEquals(2, final.size)
            assertEquals(listOf(64000L, 164000L), final.map { it.endSampleExclusive })
            assertNotEquals(final[0].utteranceId, final[1].utteranceId)
            assertEquals(listOf(StreamingCaptureGap(owner,
                events.filterIsInstance<StreamingCaptureGap>().single().sequence,
                64000, 100000, 1, StreamingBoundaryReason.PAUSE)), events.filterIsInstance<StreamingCaptureGap>())
            assertEquals(events.indices.map { it.toLong() }, events.map { it.sequence })
            assertTrue(events.all { it.owner == owner })
            val before = events.size
            consumer.consume(PcmCaptureFrame(40, ByteArray(6400), 164000, 1))
            assertEquals(before, events.size)
            assertTrue(binding.session.releaseAcknowledgement.toCompletableFuture().isDone)
        } finally {
            consumer.closeAsync().toCompletableFuture().get(10, TimeUnit.SECONDS)
            binding.closeBinding().toCompletableFuture().get(10, TimeUnit.SECONDS)
        }
    }

    @Test fun explicitFinishAfterNaturalEndpointRestartsLikeFreshStream() {
        org.junit.Assume.assumeTrue("requires explicit native-spike debug build",
            BuildConfig.LOQUIRIS_STREAMING_NATIVE_SPIKE)
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val wav = File(context.filesDir, "streaming-native-spike-20261016/fixture.wav").readBytes()
        assertEquals("83440d4ccbd82dafd1a88346ab448e1dd309e408c598d665413b910cc92c40a7",
            MessageDigest.getInstance("SHA-256").digest(wav).joinToString("") { "%02x".format(it) })
        val ready = CountDownLatch(1)
        val failures = java.util.concurrent.CopyOnWriteArrayList<StreamingStopCause>()
        val binding = StreamingMessengerBinding(context,
            StreamingRemoteIdentity("endpoint-gap", UUID.randomUUID().toString()), "1".repeat(64),
            "com.loquiris.spike.StreamingNativeKernelProbeService",
            onFailure = { failures.add(it); ready.countDown() },
            onReply = { reply, _ -> if (reply is StreamingRemoteReply.Ready) ready.countDown() })
        try {
            assertTrue(binding.bindRemote())
            assertTrue(ready.await(20, TimeUnit.SECONDS))
            assertTrue("native model creation failed: $failures", failures.isEmpty())
            val fresh = mutableListOf<StreamingRemoteResult.Text>()
            var ended = false
            for (chunk in 0L until 225L) {
                val offset = 44 + chunk.toInt() * 6400
                val result = requireNotNull(binding.session.submitRemote(PcmCaptureFrame(
                    chunk, wav.copyOfRange(offset, offset + 6400), chunk * 3200)))
                    .toCompletableFuture().get(10, TimeUnit.SECONDS)
                assertTrue(result is StreamingRemoteResult.Text)
                result as StreamingRemoteResult.Text
                if (chunk < 20) fresh.add(result)
                if (chunk >= 20 && result.endpoint && result.text.isNotBlank()) {
                    ended = true; break
                }
            }
            assertTrue("fixture must reach a nonempty natural endpoint", ended)
            assertEquals(20, fresh.size)
            assertTrue(fresh.last().text.isNotBlank())
            assertEquals(StreamingRemoteResult.Text("", true),
                requireNotNull(binding.session.finishRemoteUtterance()).toCompletableFuture().get(10, TimeUnit.SECONDS))
            val resumed = mutableListOf<StreamingRemoteResult.Text>()
            for (chunk in 0L until 20L) {
                val offset = 44 + chunk.toInt() * 6400
                val result = requireNotNull(binding.session.submitRemote(PcmCaptureFrame(
                    1000 + chunk, wav.copyOfRange(offset, offset + 6400), 1000000 + chunk * 3200, 1)))
                    .toCompletableFuture().get(10, TimeUnit.SECONDS)
                assertTrue(result is StreamingRemoteResult.Text)
                resumed.add(result as StreamingRemoteResult.Text)
            }
            // This compares different lifecycle paths: untouched first stream vs
            // explicit discontinuity after natural endpoint. Retained context is a bug.
            assertEquals("explicit boundary must behave like a fresh stream", fresh, resumed)
            binding.closeBinding().toCompletableFuture().get(10, TimeUnit.SECONDS)
        } finally { binding.closeBinding().toCompletableFuture().get(10, TimeUnit.SECONDS) }
    }

    @Test fun flushesUnfinishedFileUtteranceAndStartsFreshAfterGap() {
        org.junit.Assume.assumeTrue("requires explicit native-spike debug build",
            BuildConfig.LOQUIRIS_STREAMING_NATIVE_SPIKE)
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val wav = File(context.filesDir, "streaming-native-spike-20261016/fixture.wav").readBytes()
        assertEquals("83440d4ccbd82dafd1a88346ab448e1dd309e408c598d665413b910cc92c40a7",
            MessageDigest.getInstance("SHA-256").digest(wav).joinToString("") { "%02x".format(it) })
        val ready = CountDownLatch(1)
        val failures = java.util.concurrent.CopyOnWriteArrayList<StreamingStopCause>()
        val binding = StreamingMessengerBinding(context,
            StreamingRemoteIdentity("native-finish", UUID.randomUUID().toString()), "1".repeat(64),
            "com.loquiris.spike.StreamingNativeKernelProbeService",
            onFailure = { failures.add(it); ready.countDown() },
            onReply = { reply, _ -> if (reply is StreamingRemoteReply.Ready) ready.countDown() })
        try {
            assertTrue(binding.bindRemote())
            assertTrue(ready.await(20, TimeUnit.SECONDS))
            assertTrue("native model creation failed: $failures", failures.isEmpty())
            for (part in 0L..1L) {
                var last: StreamingRemoteResult = StreamingRemoteResult.Cancelled
                // Stop at 4 s, where this development fixture has a nonfinal hypothesis.
                for (chunk in 0L until 20L) {
                    val offset = 44 + chunk.toInt() * 6400
                    last = requireNotNull(binding.session.submitRemote(PcmCaptureFrame(
                        part * 20 + chunk, wav.copyOfRange(offset, offset + 6400),
                        part * 100000 + chunk * 3200, part))).toCompletableFuture().get(10, TimeUnit.SECONDS)
                    assertTrue("decode must succeed after explicit boundary: $last", last is StreamingRemoteResult.Text)
                }
                last as StreamingRemoteResult.Text
                assertTrue("prefix must exercise an unfinished hypothesis", last.text.isNotBlank())
                assertFalse(last.endpoint)
                val final = requireNotNull(binding.session.finishRemoteUtterance()).toCompletableFuture().get(10, TimeUnit.SECONDS)
                assertTrue(final is StreamingRemoteResult.Text)
                final as StreamingRemoteResult.Text
                assertTrue("flush must retain the unfinished text", final.text.isNotBlank())
                assertTrue(final.endpoint)
                assertEquals(StreamingRemoteResult.Text("", true),
                    requireNotNull(binding.session.finishRemoteUtterance()).toCompletableFuture().get(10, TimeUnit.SECONDS))
            }
            binding.closeBinding().toCompletableFuture().get(10, TimeUnit.SECONDS)
        } finally { binding.closeBinding().toCompletableFuture().get(10, TimeUnit.SECONDS) }
    }

    @Test fun filePcmProducesTextInPrivateProcessAndReleases() {
        org.junit.Assume.assumeTrue("requires explicit native-spike debug build",
            BuildConfig.LOQUIRIS_STREAMING_NATIVE_SPIKE)
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val wav = File(context.filesDir, "streaming-native-spike-20261016/fixture.wav").readBytes()
        assertEquals("83440d4ccbd82dafd1a88346ab448e1dd309e408c598d665413b910cc92c40a7",
            MessageDigest.getInstance("SHA-256").digest(wav).joinToString("") { "%02x".format(it) })
        // This pinned fixture has a 44-byte PCM16/16-kHz/mono WAV header.
        assertEquals(1440044, wav.size)
        val ready = CountDownLatch(1)
        val failures = java.util.concurrent.CopyOnWriteArrayList<StreamingStopCause>()
        var remotePid = 0
        val binding = StreamingMessengerBinding(context,
            StreamingRemoteIdentity("native-file", UUID.randomUUID().toString()), "1".repeat(64),
            "com.loquiris.spike.StreamingNativeKernelProbeService",
            onFailure = { failures.add(it); ready.countDown() },
            onReply = { reply, pid -> if (reply is StreamingRemoteReply.Ready) {
                remotePid = pid; ready.countDown()
            } })
        try {
            assertTrue(binding.bindRemote())
            assertTrue("verified native model must become ready", ready.await(20, TimeUnit.SECONDS))
            assertTrue("native model creation failed: $failures", failures.isEmpty())
            assertNotEquals(Process.myPid(), remotePid)
            assertTrue(remotePid > 0)
            var nonempty = 0
            var endpoints = 0
            for (sequence in 0L until 225L) {
                val offset = 44 + sequence.toInt() * 6400
                val pending = requireNotNull(binding.session.submitRemote(PcmCaptureFrame(
                    sequence, wav.copyOfRange(offset, offset + 6400), sequence * 3200)))
                val result = pending.toCompletableFuture().get(10, TimeUnit.SECONDS)
                assertTrue("real decode must not fail: $result", result is StreamingRemoteResult.Text)
                result as StreamingRemoteResult.Text
                if (result.text.isNotBlank()) nonempty++
                if (result.endpoint) endpoints++
            }
            assertTrue("real inference must produce text", nonempty > 0)
            assertTrue("fixture must exercise endpoint reset", endpoints > 0)
            println("native_file_probe chunks=225 samples=720000 nonempty=$nonempty endpoints=$endpoints remotePid=$remotePid callerPid=${Process.myPid()}")
            binding.closeBinding().toCompletableFuture().get(10, TimeUnit.SECONDS)
            assertTrue(binding.session.releaseAcknowledgement.toCompletableFuture().isDone)
            assertNull(binding.session.pendingFrame)
            assertNull(binding.session.submitRemote(PcmCaptureFrame(225, ByteArray(6400), 720000)))
        } finally { binding.closeBinding().toCompletableFuture().get(10, TimeUnit.SECONDS) }
    }
}
