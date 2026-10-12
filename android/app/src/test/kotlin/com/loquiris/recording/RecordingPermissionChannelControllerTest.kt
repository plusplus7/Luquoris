package com.loquiris.recording

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingPermissionChannelControllerTest {
    @Test
    fun `already granted permission replies without opening a system request`() {
        var requests = 0
        val replies = mutableListOf<Map<String, Any?>>()
        val controller =
            RecordingPermissionChannelController(
                hasPermission = { true },
                requestPermission = { requests += 1 },
            )

        controller.handle(
            "requestMicrophonePermission",
            mapOf("v" to RecordingChannelContract.version),
            replies::add,
        )

        assertEquals(0, requests)
        assertEquals(true, replies.single()["ok"])
    }

    @Test
    fun `missing permission waits for the system result before replying`() {
        var requests = 0
        val replies = mutableListOf<Map<String, Any?>>()
        val controller =
            RecordingPermissionChannelController(
                hasPermission = { false },
                requestPermission = { requests += 1 },
            )

        controller.handle(
            "requestMicrophonePermission",
            mapOf("v" to RecordingChannelContract.version),
            replies::add,
        )

        assertEquals(1, requests)
        assertTrue(replies.isEmpty())

        assertTrue(controller.complete(granted = true))
        assertEquals(true, replies.single()["ok"])
    }

    @Test
    fun `denied system result returns the stable permission failure`() {
        val replies = mutableListOf<Map<String, Any?>>()
        val controller =
            RecordingPermissionChannelController(
                hasPermission = { false },
                requestPermission = {},
            )
        controller.handle(
            "requestMicrophonePermission",
            mapOf("v" to RecordingChannelContract.version),
            replies::add,
        )

        assertTrue(controller.complete(granted = false))

        val failure = replies.single()["failure"] as Map<*, *>
        assertEquals(false, replies.single()["ok"])
        assertEquals("recording_permission_denied", failure["code"])
    }

    @Test
    fun `a second in-flight request fails without replacing the first reply`() {
        val firstReplies = mutableListOf<Map<String, Any?>>()
        val secondReplies = mutableListOf<Map<String, Any?>>()
        val controller =
            RecordingPermissionChannelController(
                hasPermission = { false },
                requestPermission = {},
            )
        val arguments = mapOf("v" to RecordingChannelContract.version)

        controller.handle("requestMicrophonePermission", arguments, firstReplies::add)
        controller.handle("requestMicrophonePermission", arguments, secondReplies::add)

        assertTrue(firstReplies.isEmpty())
        val failure = secondReplies.single()["failure"] as Map<*, *>
        assertEquals("recording_permission_request_in_progress", failure["code"])
        assertTrue(controller.complete(granted = true))
        assertEquals(true, firstReplies.single()["ok"])
    }
}
