package com.loquiris.recording

import android.content.Context
import android.media.MediaPlayer
import kotlin.math.max
import kotlin.math.min

internal sealed interface SessionPlaybackSource {
    data class Ready(val path: String) : SessionPlaybackSource

    data class Unavailable(val code: String) : SessionPlaybackSource
}

internal interface SessionPlaybackPlayer {
    val currentPositionMilliseconds: Long
    val durationMilliseconds: Long
    val isPlaying: Boolean
    var onPrepared: (() -> Unit)?
    var onCompletion: (() -> Unit)?
    var onSeekComplete: (() -> Unit)?
    var onError: (() -> Unit)?

    fun setDataSource(path: String)
    fun prepareAsync()
    fun start()
    fun pause()
    fun seekTo(positionMilliseconds: Long)
    fun release()
}

private data class QueuedSeek(
    val positionMilliseconds: Long,
    val reply: (Map<String, Any?>) -> Unit,
)

private class AndroidSessionPlaybackPlayer(
    private val delegate: MediaPlayer = MediaPlayer(),
) : SessionPlaybackPlayer {
    override val currentPositionMilliseconds: Long
        get() = max(0, delegate.currentPosition).toLong()
    override val durationMilliseconds: Long
        get() = max(0, delegate.duration).toLong()
    override val isPlaying: Boolean
        get() = delegate.isPlaying
    override var onPrepared: (() -> Unit)? = null
    override var onCompletion: (() -> Unit)? = null
    override var onSeekComplete: (() -> Unit)? = null
    override var onError: (() -> Unit)? = null

    init {
        delegate.setOnPreparedListener { onPrepared?.invoke() }
        delegate.setOnCompletionListener { onCompletion?.invoke() }
        delegate.setOnSeekCompleteListener { onSeekComplete?.invoke() }
        delegate.setOnErrorListener { _, _, _ ->
            onError?.invoke()
            true
        }
    }

    override fun setDataSource(path: String) = delegate.setDataSource(path)
    override fun prepareAsync() = delegate.prepareAsync()
    override fun start() = delegate.start()
    override fun pause() = delegate.pause()

    override fun seekTo(positionMilliseconds: Long) {
        delegate.seekTo(positionMilliseconds, MediaPlayer.SEEK_CLOSEST)
    }

    override fun release() = delegate.release()
}

class SessionPlaybackChannelController internal constructor(
    private val resolveSource: (String) -> SessionPlaybackSource,
    private val playerFactory: () -> SessionPlaybackPlayer,
) : AutoCloseable {
    constructor(context: Context) : this(
        resolveSource = { requestedSessionId ->
            val directory =
                AppPrivateRecordingStorage.sessionDirectory(
                    context.applicationContext,
                    requestedSessionId,
                )
            when (val artifact = RecordingM4aArtifactResolver().resolve(directory)) {
                is RecordingM4aArtifactResolveResult.Ready ->
                    SessionPlaybackSource.Ready(artifact.file.path)
                is RecordingM4aArtifactResolveResult.Unavailable ->
                    SessionPlaybackSource.Unavailable(artifact.code)
            }
        },
        playerFactory = ::AndroidSessionPlaybackPlayer,
    )

    private var player: SessionPlaybackPlayer? = null
    private var sessionId: String? = null
    private var ownerId: String? = null
    private var state = SessionPlaybackState.ready
    private var preparing = false
    private var pendingLoadReply: ((Map<String, Any?>) -> Unit)? = null
    private var seekInFlight = false
    private var pendingSeekReply: ((Map<String, Any?>) -> Unit)? = null
    private var queuedSeek: QueuedSeek? = null

    fun handle(
        method: String,
        arguments: Any?,
        reply: (Map<String, Any?>) -> Unit,
    ) {
        val values = arguments as? Map<*, *>
        if (values == null) {
            reply(failure("playback_channel_invalid"))
            return
        }
        if (values["v"] != SessionPlaybackChannelContract.version) {
            reply(failure("playback_channel_version_unsupported"))
            return
        }
        when (method) {
            "load" -> load(values["sessionId"] as? String, values["ownerId"] as? String, reply)
            "current" -> reply(current(values["ownerId"] as? String))
            "play" -> reply(play(values["ownerId"] as? String))
            "pause" -> reply(pause(values["ownerId"] as? String))
            "seek" ->
                seek(
                    values["ownerId"] as? String,
                    values["positionMilliseconds"] as? Number,
                    reply,
                )
            "release" -> release(values["ownerId"] as? String, reply)
            else -> reply(failure("playback_channel_method_unknown"))
        }
    }

    private fun load(
        requestedSessionId: String?,
        requestedOwnerId: String?,
        reply: (Map<String, Any?>) -> Unit,
    ) {
        if (requestedSessionId.isNullOrBlank()) {
            reply(failure("playback_session_invalid"))
            return
        }
        if (requestedOwnerId.isNullOrBlank()) {
            reply(failure("playback_owner_invalid"))
            return
        }
        closeActive("playback_load_replaced")
        val source =
            try {
                resolveSource(requestedSessionId)
            } catch (_: Exception) {
                reply(failure("playback_artifact_resolve_failed"))
                return
            }
        if (source is SessionPlaybackSource.Unavailable) {
            reply(failure(source.code))
            return
        }
        source as SessionPlaybackSource.Ready
        val prepared =
            try {
                playerFactory()
            } catch (_: Exception) {
                reply(failure("playback_prepare_failed"))
                return
            }
        player = prepared
        sessionId = requestedSessionId
        ownerId = requestedOwnerId
        state = SessionPlaybackState.ready
        preparing = true
        pendingLoadReply = reply
        prepared.onPrepared = {
            if (player === prepared) {
                preparing = false
                pendingLoadReply?.let { completion ->
                    pendingLoadReply = null
                    completion(current(requestedOwnerId))
                }
            }
        }
        prepared.onCompletion = {
            if (player === prepared) state = SessionPlaybackState.completed
        }
        prepared.onSeekComplete = {
            if (player === prepared) {
                seekInFlight = false
                val queued = queuedSeek
                queuedSeek = null
                if (queued != null) {
                    startSeek(prepared, queued.positionMilliseconds, queued.reply)
                } else {
                    pendingSeekReply?.let { completion ->
                        pendingSeekReply = null
                        completion(current(requestedOwnerId))
                    }
                }
            }
        }
        prepared.onError = {
            if (player === prepared) closeActive("playback_prepare_failed")
        }
        try {
            prepared.setDataSource(source.path)
            prepared.prepareAsync()
        } catch (_: Exception) {
            closeActive("playback_prepare_failed")
        }
    }

    private fun current(requestedOwnerId: String?): Map<String, Any?> {
        ownershipFailure(requestedOwnerId)?.let { return it }
        if (preparing) return failure("playback_preparing")
        val activePlayer = player ?: return failure("playback_not_loaded")
        val activeSessionId = sessionId ?: return failure("playback_not_loaded")
        return try {
            SessionPlaybackChannelContract.snapshot(
                SessionPlaybackSnapshot(
                    sessionId = activeSessionId,
                    state = state,
                    positionMilliseconds = activePlayer.currentPositionMilliseconds,
                    durationMilliseconds = activePlayer.durationMilliseconds,
                ),
            )
        } catch (_: IllegalStateException) {
            failure("playback_state_unavailable")
        }
    }

    private fun play(requestedOwnerId: String?): Map<String, Any?> {
        ownershipFailure(requestedOwnerId)?.let { return it }
        if (preparing) return failure("playback_preparing")
        val activePlayer = player ?: return failure("playback_not_loaded")
        return try {
            if (state == SessionPlaybackState.completed) activePlayer.seekTo(0)
            activePlayer.start()
            state = SessionPlaybackState.playing
            current(requestedOwnerId)
        } catch (_: IllegalStateException) {
            failure("playback_start_failed")
        }
    }

    private fun pause(requestedOwnerId: String?): Map<String, Any?> {
        ownershipFailure(requestedOwnerId)?.let { return it }
        if (preparing) return failure("playback_preparing")
        val activePlayer = player ?: return failure("playback_not_loaded")
        return try {
            if (activePlayer.isPlaying) activePlayer.pause()
            state = SessionPlaybackState.paused
            current(requestedOwnerId)
        } catch (_: IllegalStateException) {
            failure("playback_pause_failed")
        }
    }

    private fun seek(
        requestedOwnerId: String?,
        value: Number?,
        reply: (Map<String, Any?>) -> Unit,
    ) {
        ownershipFailure(requestedOwnerId)?.let {
            reply(it)
            return
        }
        if (preparing) {
            reply(failure("playback_preparing"))
            return
        }
        val activePlayer = player
        if (activePlayer == null) {
            reply(failure("playback_not_loaded"))
            return
        }
        if (value == null || value.toLong() < 0) {
            reply(failure("playback_position_invalid"))
            return
        }
        val target = try {
            min(value.toLong(), activePlayer.durationMilliseconds)
        } catch (_: IllegalStateException) {
            reply(failure("playback_seek_failed"))
            return
        }
        if (seekInFlight) {
            pendingSeekReply?.let { pending ->
                pendingSeekReply = null
                pending(failure("playback_seek_superseded"))
            }
            queuedSeek?.reply?.invoke(failure("playback_seek_superseded"))
            queuedSeek = QueuedSeek(target, reply)
            return
        }
        startSeek(activePlayer, target, reply)
    }

    private fun startSeek(
        activePlayer: SessionPlaybackPlayer,
        target: Long,
        reply: (Map<String, Any?>) -> Unit,
    ) {
        seekInFlight = true
        pendingSeekReply = reply
        try {
            if (state == SessionPlaybackState.completed) state = SessionPlaybackState.ready
            activePlayer.seekTo(target)
        } catch (_: IllegalStateException) {
            seekInFlight = false
            pendingSeekReply = null
            reply(failure("playback_seek_failed"))
        }
    }

    private fun release(
        requestedOwnerId: String?,
        reply: (Map<String, Any?>) -> Unit,
    ) {
        if (!requestedOwnerId.isNullOrBlank() && requestedOwnerId == ownerId) {
            closeActive("playback_released")
        }
        reply(SessionPlaybackChannelContract.released())
    }

    private fun ownershipFailure(requestedOwnerId: String?): Map<String, Any?>? =
        when {
            requestedOwnerId.isNullOrBlank() -> failure("playback_owner_invalid")
            requestedOwnerId != ownerId -> failure("playback_owner_mismatch")
            else -> null
        }

    override fun close() {
        closeActive("playback_released")
    }

    private fun closeActive(pendingFailureCode: String) {
        val loadReply = pendingLoadReply
        val seekReply = pendingSeekReply
        val queuedSeekReply = queuedSeek?.reply
        pendingLoadReply = null
        pendingSeekReply = null
        queuedSeek = null
        preparing = false
        seekInFlight = false
        val activePlayer = player
        player = null
        sessionId = null
        ownerId = null
        state = SessionPlaybackState.ready
        runCatching { activePlayer?.release() }
        loadReply?.invoke(failure(pendingFailureCode))
        seekReply?.invoke(failure(pendingFailureCode))
        queuedSeekReply?.invoke(failure(pendingFailureCode))
    }

    private fun failure(code: String): Map<String, Any?> =
        SessionPlaybackChannelContract.failure(code)
}
