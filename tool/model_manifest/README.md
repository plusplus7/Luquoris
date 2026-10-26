# Manifest contracts

The v1 schema and parser retain single-file identity semantics. V1's SHA-256
remains the weight-file digest; exposing a singleton inventory does not rehash
legacy durable jobs or installed models.

V2 uses `artifacts` instead of `artifactPath`. Each role occurs at most once and
all artifact paths belong to `models/<id>/`. License snapshots belong to
`models/licenses/`. Every artifact records its own immutable source and license,
separately from the bundle source/license and native runtime approval.

V2 sources currently support HTTPS `.../resolve/<revision>/<file>`,
`.../blob/<revision>/<file>`, and
`https://raw.githubusercontent.com/<owner>/<repo>/<revision>/<file>`.
Revisions are lowercase 40- or 64-hex commit/content identifiers; credentials,
queries, fragments, branch names, and unversioned URLs are rejected. This
syntactic pin is not redistribution approval or proof of the upstream bytes.
Import must still compare every byte length and digest.

The bundle SHA-256 covers UTF-8 bytes of a compact JSON array sorted by path's
Dart string lexical ordering. Each entry has exactly these keys in this order:
`path`, `role`, `bytes`, `sha256`. No whitespace or trailing newline is emitted.
Strings use Dart `jsonEncode` escaping; non-ASCII characters remain UTF-8, not
ASCII escapes. Byte lengths are positive portable integers up to 2^53−1; the
checked total must remain in that range and equal bundle `bytes`.

Fixed vectors live in `model_bundle_manifest_test.dart`. The ASCII encoder/token
vector hashes to
`d2531478b5050f8ca5375c97cb2e94aff565e057f4ef4ae4c2c79a5c9b41a1c8`;
the UTF-8 `编码器.onnx` variant hashes to
`3ccbc6215c91484d88ff4a88ccfd5962bc63a142dd7c83e8219f6b0e4551d059`.

V2 requires exact `runtime.engineVersion` in addition to engine and format.
Adapters must enforce that compatibility before recognizer allocation. A parsed
manifest is not a loaded/qualified model. Until task 3.2 upgrades single-file
consumers, no v2 manifest is included in application model inputs.
