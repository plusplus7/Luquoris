package com.loquiris.recording

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SessionPlaybackChannelControllerTest {
    @Test
    fun `load replies only after asynchronous preparation`() {
        val player = FakePlaybackPlayer()
        val controller = controllerWith(player)
        val replies = mutableListOf<Map<String, Any?>>()

        controller.handle("load", arguments(owner = "detail-1", session = "meeting-1"), replies::add)

        assertTrue(replies.isEmpty())
        assertTrue(player.prepareAsyncCalled)
        player.finishPrepare()
        assertEquals("ready", snapshot(replies.single())["state"])
    }

    @Test
    fun `seek replies only after the player confirms its position`() {
        val player = FakePlaybackPlayer(durationMilliseconds = 10_000)
        val controller = controllerWith(player)
        controller.handle("load", arguments(owner = "detail-1", session = "meeting-1")) {}
        player.finishPrepare()
        val replies = mutableListOf<Map<String, Any?>>()

        controller.handle(
            "seek",
            arguments(owner = "detail-1") + ("positionMilliseconds" to 4_000),
            replies::add,
        )

        assertTrue(replies.isEmpty())
        player.finishSeek()
        assertEquals(4_000L, snapshot(replies.single())["positionMilliseconds"])
    }

    @Test
    fun `consecutive seeks wait for the matching native completion`() {
        val player = FakePlaybackPlayer(durationMilliseconds = 10_000)
        val controller = controllerWith(player)
        controller.handle("load", arguments(owner = "detail-1", session = "meeting-1")) {}
        player.finishPrepare()
        val firstReplies = mutableListOf<Map<String, Any?>>()
        val secondReplies = mutableListOf<Map<String, Any?>>()

        controller.handle(
            "seek",
            arguments(owner = "detail-1") + ("positionMilliseconds" to 1_000),
            firstReplies::add,
        )
        controller.handle(
            "seek",
            arguments(owner = "detail-1") + ("positionMilliseconds" to 2_000),
            secondReplies::add,
        )

        assertEquals(
            "playback_seek_superseded",
            (firstReplies.single()["failure"] as Map<*, *>)["code"],
        )
        assertTrue(secondReplies.isEmpty())
        assertEquals(listOf(1_000L), player.seekTargets)

        player.finishSeek()

        assertTrue(secondReplies.isEmpty())
        assertEquals(listOf(1_000L, 2_000L), player.seekTargets)

        player.finishSeek()

        assertEquals(2_000L, snapshot(secondReplies.single())["positionMilliseconds"])
    }

    @Test
    fun `stale owner release cannot close a replacement player`() {
        val first = FakePlaybackPlayer()
        val second = FakePlaybackPlayer()
        val players = ArrayDeque(listOf(first, second))
        val controller =
            SessionPlaybackChannelController(
                resolveSource = { SessionPlaybackSource.Ready("/private/playback.m4a") },
                playerFactory = { players.removeFirst() },
            )
        controller.handle("load", arguments(owner = "detail-1", session = "meeting-1")) {}
        first.finishPrepare()
        controller.handle("load", arguments(owner = "detail-2", session = "meeting-2")) {}
        second.finishPrepare()
        val replies = mutableListOf<Map<String, Any?>>()

        controller.handle("release", arguments(owner = "detail-1"), replies::add)

        assertEquals(1, first.releaseCount)
        assertEquals(0, second.releaseCount)
        assertTrue(replies.single()["ok"] == true)
    }

    @Test
    fun `prepare failure releases the allocated native player`() {
        val player = FakePlaybackPlayer(prepareFailure = true)
        val controller = controllerWith(player)
        val replies = mutableListOf<Map<String, Any?>>()

        controller.handle("load", arguments(owner = "detail-1", session = "meeting-1"), replies::add)

        assertEquals(1, player.releaseCount)
        assertFalse(replies.single()["ok"] as Boolean)
    }
}

private fun controllerWith(player: FakePlaybackPlayer) =
    SessionPlaybackChannelController(
        resolveSource = { SessionPlaybackSource.Ready("/private/playback.m4a") },
        playerFactory = { player },
    )

private fun arguments(
    owner: String,
    session: String? = null,
): Map<String, Any?> =
    buildMap {
        put("v", SessionPlaybackChannelContract.version)
        put("ownerId", owner)
        if (session != null) put("sessionId", session)
    }

private fun snapshot(response: Map<String, Any?>): Map<*, *> = response["snapshot"] as Map<*, *>

private class FakePlaybackPlayer(
    override val durationMilliseconds: Long = 10_000,
    private val prepareFailure: Boolean = false,
) : SessionPlaybackPlayer {
    override var currentPositionMilliseconds: Long = 0
    override var isPlaying: Boolean = false
    override var onPrepared: (() -> Unit)? = null
    override var onCompletion: (() -> Unit)? = null
    override var onSeekComplete: (() -> Unit)? = null
    override var onError: (() -> Unit)? = null
    var prepareAsyncCalled = false
    var releaseCount = 0
    private var seekTarget = 0L
    val seekTargets = mutableListOf<Long>()

    override fun setDataSource(path: String) = Unit

    override fun prepareAsync() {
        if (prepareFailure) error("prepare failed")
        prepareAsyncCalled = true
    }

    fun finishPrepare() {
        onPrepared?.invoke()
    }

    override fun start() {
        isPlaying = true
    }

    override fun pause() {
        isPlaying = false
    }

    override fun seekTo(positionMilliseconds: Long) {
        seekTarget = positionMilliseconds
        seekTargets += positionMilliseconds
    }

    fun finishSeek() {
        currentPositionMilliseconds = seekTarget
        onSeekComplete?.invoke()
    }

    override fun release() {
        releaseCount += 1
    }
}
