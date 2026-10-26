package com.loquiris.transcription

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Parcel
import android.os.Process
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.loquiris.recording.PcmCaptureFrame
import java.util.UUID
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** Synthetic PCM only. No AudioRecord, model import or recorder/database access. */
@RunWith(AndroidJUnit4::class)
class StreamingRemoteProcessInstrumentedTest {
    @Test fun linkRegistrationFailureExplicitlyRejectsUnadoptedOwner() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val rejected = CountDownLatch(1)
        val failures = CopyOnWriteArrayList<StreamingStopCause>()
        val binding = StreamingMessengerBinding(context, StreamingRemoteIdentity("registration-fault", UUID.randomUUID().toString()), "0".repeat(64),
            "com.loquiris.spike.StreamingLinkFailureProbeService", onFailure = { failures.add(it); rejected.countDown() })
        try {
            assertTrue(binding.bindRemote())
            assertTrue("live sender must be explicitly rejected after registration failure", rejected.await(5, TimeUnit.SECONDS))
            binding.session.releaseAcknowledgement.toCompletableFuture().get(5, TimeUnit.SECONDS)
            assertEquals(listOf(StreamingStopCause.MEMORY), failures)
            assertNull(binding.session.submitRemote(PcmCaptureFrame(0, ByteArray(640), 0)))
        } finally { binding.closeBinding().toCompletableFuture().get(5, TimeUnit.SECONDS) }
    }

    @Test fun bundleRoundTripUsesRealParcelPrimitives() {
        val owner = StreamingRemoteIdentity("instrumented", UUID.randomUUID().toString())
        val command = StreamingRemoteCommand.Pcm(owner, 11, PcmCaptureFrame(4, byteArrayOf(1, 2, 3, 4), 20, 2))
        val parcel = Parcel.obtain()
        try {
            parcel.writeBundle(StreamingRemoteBundle.toRemoteBundle(StreamingRemoteWire.encodeRemoteCommand(command)))
            parcel.setDataPosition(0)
            val fields = requireNotNull(StreamingRemoteBundle.fromRemoteBundle(requireNotNull(parcel.readBundle())))
            val decoded = StreamingRemoteWire.decodeRemoteCommand(fields) as StreamingRemoteCommand.Pcm
            assertEquals(owner, decoded.owner)
            assertEquals(11L, decoded.requestId)
            assertEquals(20L, decoded.frame.canonicalStartSample)
            assertEquals(2L, decoded.frame.captureEpoch)
            assertArrayEquals(byteArrayOf(1, 2, 3, 4), decoded.frame.copyBytes())
        } finally { parcel.recycle() }
    }

    @Test fun syntheticPcmRoundTripsAcrossPrivateProcess() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val serviceName = "com.loquiris.spike.StreamingProcessProbeService"
        @Suppress("DEPRECATION")
        val info = context.packageManager.getServiceInfo(ComponentName(context.packageName, serviceName), PackageManager.GET_META_DATA)
        assertFalse(info.exported)
        assertEquals("${context.packageName}:streaming_probe", info.processName)
        val ready = CountDownLatch(1)
        var remotePid = 0
        val binding = StreamingMessengerBinding(context, StreamingRemoteIdentity("synthetic", UUID.randomUUID().toString()), "0".repeat(64), serviceName,
            onReply = { reply, pid -> if (reply is StreamingRemoteReply.Ready) { remotePid = pid; ready.countDown() } })
        try {
            assertTrue(binding.bindRemote())
            assertTrue("remote readiness", ready.await(5, TimeUnit.SECONDS))
            assertTrue(remotePid > 0)
            assertNotEquals(Process.myPid(), remotePid)
            for (sequence in 0L..1L) {
                val stage = requireNotNull(binding.session.submitRemote(PcmCaptureFrame(sequence, ByteArray(640), sequence * 320)))
                assertEquals(StreamingRemoteResult.Text("fixture:$sequence", false), stage.toCompletableFuture().get(5, TimeUnit.SECONDS))
            }
            binding.closeBinding().toCompletableFuture().get(5, TimeUnit.SECONDS)
            assertNull(binding.session.pendingFrame)
        } finally { binding.closeBinding().toCompletableFuture().get(5, TimeUnit.SECONDS) }
    }

    @Test fun confirmedChildDeathSettlesPendingWithoutKillingCaller() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val ready = CountDownLatch(1)
        val failures = CopyOnWriteArrayList<StreamingStopCause>()
        val failed = CountDownLatch(1)
        val originalPid = Process.myPid()
        val binding = StreamingMessengerBinding(context, StreamingRemoteIdentity("death-probe", UUID.randomUUID().toString()), "0".repeat(64),
            "com.loquiris.spike.StreamingProcessProbeService", onFailure = { failures.add(it); failed.countDown() },
            onReply = { reply, _ -> if (reply is StreamingRemoteReply.Ready) ready.countDown() })
        try {
            assertTrue(binding.bindRemote())
            assertTrue(ready.await(5, TimeUnit.SECONDS))
            val pcm = ByteArray(640).apply { this[0] = 7 } // Fixture-only trigger, not a production wire command.
            val pending = requireNotNull(binding.session.submitRemote(PcmCaptureFrame(0, pcm, 0)))
            assertEquals(StreamingRemoteResult.Failed(StreamingStopCause.ENGINE), pending.toCompletableFuture().get(5, TimeUnit.SECONDS))
            binding.closeBinding().toCompletableFuture().get(5, TimeUnit.SECONDS)
            assertEquals(originalPid, Process.myPid())
            assertTrue(failed.await(5, TimeUnit.SECONDS))
            assertEquals(listOf(StreamingStopCause.ENGINE), failures)
            assertNull(binding.session.submitRemote(PcmCaptureFrame(1, ByteArray(640), 320)))
        } finally { binding.closeBinding().toCompletableFuture().get(5, TimeUnit.SECONDS) }
    }

    @Test fun overlappingBindingsRejectNewOwnerWithoutStrandingEitherSession() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val ready = CountDownLatch(1)
        val rejected = CountDownLatch(1)
        val thirdSettled = CountDownLatch(1)
        val service = "com.loquiris.spike.StreamingProcessProbeService"
        val first = StreamingMessengerBinding(context, StreamingRemoteIdentity("first", UUID.randomUUID().toString()), "0".repeat(64), service,
            onReply = { reply, _ -> if (reply is StreamingRemoteReply.Ready) ready.countDown() })
        val second = StreamingMessengerBinding(context, StreamingRemoteIdentity("second", UUID.randomUUID().toString()), "0".repeat(64), service,
            onReply = { reply, _ -> if (reply is StreamingRemoteReply.Rejected) rejected.countDown() })
        val third = StreamingMessengerBinding(context, StreamingRemoteIdentity("third", UUID.randomUUID().toString()), "0".repeat(64), service,
            onReply = { reply, _ -> if (reply is StreamingRemoteReply.Ready || reply is StreamingRemoteReply.Rejected) thirdSettled.countDown() })
        try {
            assertTrue(first.bindRemote()); assertTrue(ready.await(5, TimeUnit.SECONDS))
            assertTrue(second.bindRemote()); assertTrue("second owner must get an explicit refusal", rejected.await(5, TimeUnit.SECONDS))
            second.session.releaseAcknowledgement.toCompletableFuture().get(5, TimeUnit.SECONDS)
            val decode = requireNotNull(first.session.submitRemote(PcmCaptureFrame(0, ByteArray(640), 0)))
            assertEquals(StreamingRemoteResult.Text("fixture:0", false), decode.toCompletableFuture().get(5, TimeUnit.SECONDS))
            // Register before closing: the next bind can run in ACK delivery,
            // before the old binding's queued unbind has run.
            val immediateRebind = first.session.releaseAcknowledgement.thenRun { assertTrue(third.bindRemote()) }
            first.closeBinding().toCompletableFuture().get(5, TimeUnit.SECONDS)
            immediateRebind.toCompletableFuture().get(5, TimeUnit.SECONDS)
            assertTrue("new binding must become ready or explicitly rejected, never hang", thirdSettled.await(5, TimeUnit.SECONDS))
            third.closeBinding().toCompletableFuture().get(5, TimeUnit.SECONDS)
        } finally {
            first.closeBinding().toCompletableFuture().get(5, TimeUnit.SECONDS)
            second.closeBinding().toCompletableFuture().get(5, TimeUnit.SECONDS)
            third.closeBinding().toCompletableFuture().get(5, TimeUnit.SECONDS)
        }
    }

    @Test fun unconfiguredRuntimeStaysUnavailable() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val unavailable = CountDownLatch(1)
        val binding = StreamingMessengerBinding(context, StreamingRemoteIdentity("unavailable", UUID.randomUUID().toString()), "a".repeat(64),
            onFailure = { if (it == StreamingStopCause.MODEL_UNAVAILABLE) unavailable.countDown() })
        try {
            assertTrue(binding.bindRemote())
            assertTrue(unavailable.await(5, TimeUnit.SECONDS))
            binding.session.releaseAcknowledgement.toCompletableFuture().get(5, TimeUnit.SECONDS)
            assertNull(binding.session.submitRemote(PcmCaptureFrame(0, ByteArray(640), 0)))
        } finally { binding.closeBinding().toCompletableFuture().get(5, TimeUnit.SECONDS) }
    }
}
