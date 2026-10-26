# Recording choices in the current development build

Before starting a new meeting, select one of the available processing choices:

- **Post-session transcription** saves the original recording first and requests
  a complete pass once finalized audio is durably available. Its model, runtime
  and settings are stored with this meeting before recording starts.
- **Recording only** saves original audio without requesting transcription for
  this meeting. It does not need a transcription model to start.
- **Live draft + refinement** is currently disabled. A qualified streaming model
  pair and working native streaming adapter are still required. The older
  experimental near-real-time path is not presented as this new capability.

These choices apply to the new meeting. They do not silently rewrite the older
global timing preference or change historical meetings. Language and speaker
guidance remain separate setup choices.

If configuration cannot be saved, capture has not started. Retry, or explicitly
choose recording only. If native startup has an unknown outcome, do not issue
another start: inspect the recording/recovery state first. Microphone permission
and storage-preflight errors retain their normal explanations and safe retry.

When multiple completed transcript versions exist, open **Transcript versions**
from the transcript editor or an available-version notice. Review provenance and
coverage, then choose the version to use. A newly available refined version does
not replace the current selection automatically. Corrections stay with the
version on which they were made; bookmarks keep their recording-time anchors.

A paused complete pass can be resumed explicitly after its resource condition is
resolved. Recording always has priority. None of these controls certify streaming
quality, latency, long-run battery use or release approval.
