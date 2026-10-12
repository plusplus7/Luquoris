package com.loquiris.transcription

import com.loquiris.recording.PcmInferenceConsumer

data class LiveDraftRequest(
    val runId: String,
    val meetingId: String,
    val modelId: String,
    val languageHint: TranscriptionLanguageHint,
    val parameterVersion: Int,
)

class LivePcmInferenceRegistry {
    private class PendingStart(val request: LiveDraftRequest) {
        var cancellationCode: String? = null
    }

    private data class ActiveDraft(
        val request: LiveDraftRequest,
        val session: LiveDraftSession,
    )

    private val lock = Any()
    private val pendingStarts = mutableSetOf<PendingStart>()
    private val thermalBlockedMeetings = mutableSetOf<String>()
    private val draftsByRunId = mutableMapOf<String, ActiveDraft>()
    private val runIdByMeetingId = mutableMapOf<String, String>()
    private val captureBindings =
        mutableMapOf<String, (PcmInferenceConsumer?) -> Unit>()

    fun start(
        request: LiveDraftRequest,
        factory: () -> LiveDraftSession,
    ): LiveDraftStartResult {
        val pending = PendingStart(request)
        synchronized(lock) {
            if (request.meetingId in thermalBlockedMeetings) {
                return LiveDraftStartResult.Failure(TRANSCRIPTION_LIVE_THERMAL)
            }
            if (draftsByRunId.containsKey(request.runId)) {
                return LiveDraftStartResult.Started
            }
            pendingStarts.add(pending)
        }

        val session: LiveDraftSession
        val startResult: LiveDraftStartResult
        try {
            session = factory()
            startResult = session.start()
        } catch (failure: Throwable) {
            synchronized(lock) { pendingStarts.remove(pending) }
            throw failure
        }
        if (startResult is LiveDraftStartResult.Failure) {
            synchronized(lock) { pendingStarts.remove(pending) }
            session.close()
            return startResult
        }

        var duplicate = false
        var cancellationCode: String? = null
        var replaced: ActiveDraft? = null
        synchronized(lock) {
            pendingStarts.remove(pending)
            cancellationCode = pending.cancellationCode
            if (cancellationCode != null) {
                // A stop won while the model was being materialized.
            } else if (draftsByRunId.containsKey(request.runId)) {
                duplicate = true
            } else {
                val replacedRunId = runIdByMeetingId.put(request.meetingId, request.runId)
                if (replacedRunId != null) {
                    replaced = draftsByRunId.remove(replacedRunId)
                }
                draftsByRunId[request.runId] = ActiveDraft(request, session)
                captureBindings[request.meetingId]?.invoke(session)
            }
        }

        cancellationCode?.let { code ->
            session.degrade(code)
            session.close()
            return LiveDraftStartResult.Failure(code)
        }
        if (duplicate) {
            session.close()
            return LiveDraftStartResult.Started
        }
        replaced?.let {
            it.session.degrade(TRANSCRIPTION_LIVE_REPLACED)
            it.session.close()
        }
        return LiveDraftStartResult.Started
    }

    fun stopDraft(runId: String) {
        val removed = synchronized(lock) {
            pendingStarts.filter { it.request.runId == runId }.forEach {
                it.cancellationCode = "transcription_live_closed"
            }
            removeRun(runId)
        } ?: return
        removed.session.close()
    }

    fun bindCapture(
        meetingId: String,
        replaceConsumer: (PcmInferenceConsumer?) -> Unit,
    ) {
        synchronized(lock) {
            // Binding callbacks only swap the fan-out's atomic consumer; never run inference.
            captureBindings.put(meetingId, replaceConsumer)?.invoke(null)
            replaceConsumer(runIdByMeetingId[meetingId]?.let(draftsByRunId::get)?.session)
        }
    }

    fun unbindCapture(
        meetingId: String,
        degradationCode: String,
    ) {
        val binding: ((PcmInferenceConsumer?) -> Unit)?
        val removed: ActiveDraft?
        synchronized(lock) {
            pendingStarts.filter { it.request.meetingId == meetingId }.forEach {
                it.cancellationCode = degradationCode
            }
            binding = captureBindings.remove(meetingId)
            thermalBlockedMeetings.remove(meetingId)
            val runId = runIdByMeetingId.remove(meetingId)
            removed = runId?.let(draftsByRunId::remove)
            binding?.invoke(null)
        }
        removed?.let {
            it.session.degrade(degradationCode)
            it.session.close()
        }
    }

    fun degradeForThermal(meetingId: String) {
        val removed = synchronized(lock) {
            thermalBlockedMeetings.add(meetingId)
            pendingStarts.filter { it.request.meetingId == meetingId }.forEach {
                it.cancellationCode = TRANSCRIPTION_LIVE_THERMAL
            }
            removeMeeting(meetingId)
        } ?: return
        removed.session.degrade(TRANSCRIPTION_LIVE_THERMAL)
        removed.session.close()
    }

    fun closeOwner() {
        val drafts: List<ActiveDraft>
        val bindings: List<(PcmInferenceConsumer?) -> Unit>
        synchronized(lock) {
            pendingStarts.forEach { it.cancellationCode = TRANSCRIPTION_LIVE_CHANNEL_CLOSED }
            drafts = draftsByRunId.values.toList()
            bindings =
                drafts
                    .mapNotNull { captureBindings[it.request.meetingId] }
                    .distinct()
            draftsByRunId.clear()
            runIdByMeetingId.clear()
            bindings.forEach { it(null) }
        }
        drafts.forEach {
            it.session.degrade(TRANSCRIPTION_LIVE_CHANNEL_CLOSED)
            it.session.close()
        }
    }

    private fun removeRun(runId: String): ActiveDraft? =
        synchronized(lock) {
            val removed = draftsByRunId.remove(runId) ?: return@synchronized null
            runIdByMeetingId.remove(removed.request.meetingId, runId)
            captureBindings[removed.request.meetingId]?.invoke(null)
            removed
        }

    private fun removeMeeting(meetingId: String): ActiveDraft? =
        synchronized(lock) {
            val runId = runIdByMeetingId.remove(meetingId) ?: return@synchronized null
            captureBindings[meetingId]?.invoke(null)
            draftsByRunId.remove(runId)
        }

    companion object {
        val process = LivePcmInferenceRegistry()

        private const val TRANSCRIPTION_LIVE_CHANNEL_CLOSED =
            "transcription_live_channel_closed"
        private const val TRANSCRIPTION_LIVE_REPLACED = "transcription_live_replaced"
        private const val TRANSCRIPTION_LIVE_THERMAL = "transcription_live_thermal"
    }
}
