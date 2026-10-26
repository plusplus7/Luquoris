# Remote transcription protocol v1

The adjacent strict JSON schemas and fixtures define request/result values.
Unknown fields, unknown schema versions, non-integral times, unsafe IDs, backwards
intervals and overlapping result segments are rejected. Server-generated IDs are
opaque. Media times are pause-free milliseconds from the beginning of captured
audio; files appear in recording order. File hashes cover committed encoded bytes.
The upload digest is SHA-256 over the UploadRequest JSON with sorted keys, ASCII
escaping and compact separators (no newline); it is distinct from native journal
inventory hashes. No wall-clock pause duration is inserted in the media timeline.

Every `/v1` route requires `Authorization: Bearer <client token>`. Tokens are
administrator-provisioned, unique per principal, at least 32 random characters and
only sent over HTTPS. Resource ownership comes from the token, never request data.
Revoke by removing/replacing the token in server configuration and restarting.
Secrets never appear in schemas, results, logs or backups.

`POST /v1/uploads` and `POST /v1/transcriptions` require `Idempotency-Key`
(1–128 ASCII letters/digits/underscore/hyphen). Keys are scoped to authenticated
owner and operation. Persist a unique key per upload or requested run; repeat it
on network retries. Identical requests return the same identity; conflicting
requests return 409. A user-requested re-run uses a new runId and job key.

Upload responses: `{schemaVersion,uploadId,state,audioManifestDigest,chunkBytes,
expiresAt,offsets}`. `offsets` maps fileId to durably confirmed bytes. Dates are UTC
epoch milliseconds. PUT `/v1/uploads/{id}/files/{fileId}?offset=<integer>` sends
raw bytes up to chunkBytes (default 1 MiB); response `{offset}` confirms the next
byte. Retry identical chunks or GET the upload to recover a lost acknowledgement.
A repeated chunk cannot cross the confirmed offset. Empty/oversize chunks fail.
Seal with POST `/v1/uploads/{id}/complete`; all declared bytes, hashes and audio
geometry must validate before the upload becomes immutable and usable by a job.

Job response: `{schemaVersion,jobId,uploadId,profileId,state,attempt,error,
expiresAt}`. States: queued/running/succeeded/failed/cancelled/expired.
`attempt` counts worker claims. `error` is null or a stable content-free code.
GET the job with bounded polling/backoff; GET `/result` only after succeeded.
DELETE cancels and invalidates even a completed result; it is idempotent.
Server-internal retries reuse identity; explicit client retry after a terminal
failure is a new run. Do not silently change the chosen profile on GPU failure.

Limits: 1024 files, 2 GiB/upload, 12 hours recorded duration, 1 MiB metadata body,
100000 result segments and 16000 characters/segment. Result speaker is null until
a diarization pipeline is implemented. Response parsers must apply these limits
before persistence. Errors use `{error:{code}}` (authentication may use the
framework's `{detail:{code}}`); never depend on localized error text.
401 requires credentials, 404 hides missing/other-owner resources, 409 means
conflict/incomplete/not-ready, 410 means expired, 413 means size/quota exceeded,
422 means malformed/invalid media or schema. Do not automatically retry 401/422.

Default upload expiry is 24h after the last acknowledged chunk. Terminal jobs and
results expire 24h after termination. Shared uploads are retained until all
referencing jobs expire; local original audio is independent of this policy.
GET `/v1/capabilities` returns actual limits, retentionSeconds and profile IDs.
No list endpoint exists: uploadId/jobId and client request keys are durable client
state. Schemas and fixtures must be consumed in Python, Dart and Kotlin tests.
