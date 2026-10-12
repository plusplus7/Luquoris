package com.loquiris.recording

import android.content.Context
import org.json.JSONObject

class SharedPreferencesRecordingStateStore(
    context: Context,
    preferencesName: String = DEFAULT_PREFERENCES_NAME,
) : RecordingStateStore {
    private val preferences = context.applicationContext.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)

    override fun load(): RecordingStateLoadResult {
        val encoded = try {
            preferences.getString(SNAPSHOT_KEY, null)
        } catch (_: RuntimeException) {
            return RecordingStateLoadResult.Unavailable("recording_state_load_failed")
        } ?: return RecordingStateLoadResult.Absent

        return try {
            val json = JSONObject(encoded)
            check(json.getInt("schemaVersion") == SCHEMA_VERSION) { "Unsupported recording state schema" }
            val snapshot =
                NativeRecordingSnapshot(
                    sessionId = if (json.isNull("sessionId")) null else json.getString("sessionId"),
                    state = NativeRecordingState.valueOf(json.getString("state")),
                    elapsedMilliseconds = json.getLong("elapsedMilliseconds"),
                    bytesWritten = json.getLong("bytesWritten"),
                    revision = json.getLong("revision"),
                )
            check(snapshot.revision < Long.MAX_VALUE) { "Recording state revision is exhausted" }
            RecordingStateLoadResult.Loaded(snapshot)
        } catch (_: Exception) {
            RecordingStateLoadResult.Corrupt("recording_state_corrupt")
        }
    }

    override fun save(snapshot: NativeRecordingSnapshot): Boolean =
        preferences
            .edit()
            .putString(
                SNAPSHOT_KEY,
                JSONObject()
                    .put("schemaVersion", SCHEMA_VERSION)
                    .put("sessionId", snapshot.sessionId ?: JSONObject.NULL)
                    .put("state", snapshot.state.name)
                    .put("elapsedMilliseconds", snapshot.elapsedMilliseconds)
                    .put("bytesWritten", snapshot.bytesWritten)
                    .put("revision", snapshot.revision)
                    .toString(),
            ).commit()

    companion object {
        private const val DEFAULT_PREFERENCES_NAME = "loquiris-recording-state"
        private const val SNAPSHOT_KEY = "authoritative_snapshot"
        private const val SCHEMA_VERSION = 1
    }
}
