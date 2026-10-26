# Refinement identity v1

The new `RefinementIdentity` is a prerequisite for durable scheduling, not a
scheduler installation or a completed task 5.2 claim. Legacy transcription
identities are unchanged.

The namespace is UUIDv5(`NAMESPACE_URL`,
`loquiris:refinement-identity:v1`): `b32de874-afc4-5a06-8f31-e3c23022bbe8`.
Run and job IDs use standard UUIDv5 over compact UTF-8 JSON arrays with no extra
whitespace, in this exact order:

1. `loquiris.refinement.v1`
2. `job` or `run`
3. Owning meeting ID
4. Complete authoritative audio inventory SHA-256
5. `refinement`
6. Engine ID
7. Exact engine version
8. Original frozen model ID
9. Model version
10. Bundle SHA-256
11. Integer parameter schema version
12. Canonical parameter JSON as a string
13. Original frozen manifest JSON as a string

JSON strings preserve Unicode and distinguish delimiters structurally. The
frozen manifest bytes deliberately remain exact, consistent with persisted role
profile equality. Reformatting a profile is a different frozen request; decoding
parameter key order is already canonicalized before this identity boundary.

No local catalog alias, wall-clock time, current completeness, or availability
of an optional live source enters identity. Restored jobs can themselves have
remapped IDs, so the eventual scheduler must first locate a semantically matching
retained job and reuse it rather than relying exclusively on re-derived UUIDs.

Independent Python `json.dumps(ensure_ascii=False, separators=(',', ':'))` and
`uuid.uuid5` vectors for `modelBundleFixture()`, meeting `meeting-中文`, audio
digest 64 lowercase `a` characters, runtime `1.0.0`, and canonical parameters
`{"languageHint":"mixed","parameterVersion":1}`:

- Job: `da2c6b7b-896e-5ea4-a1f8-846766bc2184`
- Run: `e55ae492-66b5-58bf-817f-be3a0a2714e8`

Four tests assert these vectors, repeat determinism, input separation, parameter
key normalization, frozen profile identity, and invalid ownership/hash rejection.

## Restored model binding

New paired writes now accept an original snapshot model ID different from the
local catalog foreign key only after checking the exact engine/version/digest
tuple and the catalog's version, source, byte count, engine ID, license ID,
license snapshot path, and active capability/mode sets. Deleted catalog records
or capability/mode entries do not authorize new work. The frozen snapshot is
not rewritten. Historical reads remain independent of current asset/catalog
availability. Fourteen real-database writer tests pass; independent review found
no Important issue in this binding slice. Asset integrity, supported execution,
catalog registration, and scheduling remain separate checks.
