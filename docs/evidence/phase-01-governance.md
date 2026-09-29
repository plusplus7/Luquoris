# Phase Evidence: Governance and Baseline

## Scope

- OpenSpec change: `bootstrap-loquiris-offline-recorder`
- Task IDs: 1.1–1.5
- Commit/build identifier: repository has no initial commit
- Date and operator: 2026-09-28, Codex

## Completed

- Recorded the Fairy read-only reuse boundary and prohibited business/branding/history reuse.
- Adopted Apache-2.0 and added contribution, security, privacy, and model-acceptance policies.
- Established the initial fail-closed third-party-notice review workflow with no approved production entries.
- Pinned Flutter, Java, Android Gradle, Kotlin, SDK, and NDK versions and documented clean bootstrap prerequisites.
- Added a reusable evidence template that requires completion, commands/results, assumptions, risks, and next recommendation.

## Verification

| Command or procedure | Environment | Result | Evidence path |
|---|---|---|---|
| `rg -n "read-only|Prohibited reuse|Apache-2.0|fail-closed|Flutter \\| 3.44.0|Unverified assumptions" ...` plus non-empty license/security/privacy checks | macOS workspace | Exit 0; every required marker found | Command output in implementation session |
| `openspec validate bootstrap-loquiris-offline-recorder --type change --strict --json --no-interactive` | OpenSpec 1.3.1 | Passed with 0 issues before implementation | OpenSpec change |

## Unverified assumptions

- The Flutter/Android toolchain had not yet produced a build at governance verification time. Project-specific Flutter 3.44.0 and Temurin 17 were subsequently installed outside the repository for bootstrap verification.
- No dependency or model is yet approved for production.
- No physical-device behavior is claimed.

## Risks

- R-10, R-16, R-17, R-20, and R-25 remain open.

## Recommendation

- Proceed to Flutter/Android bootstrap only after the pinned SDKs are available and `flutter doctor -v` evidence is captured.
