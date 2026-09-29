# Phase Evidence: Design System and Navigation Shell

## Scope

- OpenSpec change: `bootstrap-loquiris-offline-recorder`
- Task IDs: 3.1–3.7
- Commit/build identifier: repository has no initial commit; Flutter build `0.1.0+1`
- Date and operator: 2026-09-28, Codex

## Completed

- Added independent Loquiris Material 3 light and dark palettes, semantic status colors, typography, spacing, shape, and reduced-motion-aware tokens without Noctis or sleep-domain assets.
- Added adaptive page scaffolding, accessible critical controls, English and simplified Chinese ARB catalogs, system-locale behavior, and explicit in-app locale overrides.
- Added one Riverpod-provided GoRouter with URL-reconstructable meeting, recording, transcript, export, model/performance, and storage/privacy destinations plus a localized not-found state.
- Added a constraint-driven `StatefulShellRoute.indexedStack` navigation shell using a bottom navigation bar below 600 logical pixels and a navigation rail at wider sizes.
- Added fake-repository-driven loading, empty, typed-error, content, and multi-session recovery states. Recovery entry points only open committed meeting data and never restart microphone capture.
- Added a shared pinned-device widget-test harness, large-text and TalkBack semantic checks, constrained-width and landscape overflow regressions, and initial light/dark phone-portrait geometry goldens.

## Verification

| Command or procedure | Environment | Result | Evidence path |
|---|---|---|---|
| `flutter analyze --fatal-infos` | Flutter 3.44.0 / Dart 3.12.0, macOS | Passed; 0 issues | Command output in implementation session |
| `flutter test --test-randomize-ordering-seed=random` | Flutter host test runner | Passed; seed `3958676375`, 55 tests | `test/` |
| `flutter test test/accessibility/app_shell_accessibility_test.dart` | 320×640, 280×600, 640×320, and 720×1024 logical fixtures | Passed; 6 tests, including 200% text and 48 dp target checks | `test/accessibility/app_shell_accessibility_test.dart` |
| `flutter test --tags golden test/golden/app_shell_golden_test.dart` twice without update flags | Pinned Flutter host renderer | Passed twice; 2/2 each run | `test/golden/goldens/` |
| Manual inspection of both generated PNGs | Original pixel size | Passed; expected centered empty state, primary action, and compact navigation in both themes | `test/golden/goldens/` |
| Widget test hygiene script | Repository tests | Passed; no hard violations or overflow suppression | `test/` |
| Routing gate | `lib/` | Passed; exactly one router, no named Navigator mixing, no identity in `extra` | `lib/routing/` |
| ARB parity and i18n bans | `lib/l10n/` and `lib/` | Passed; 23 English/Chinese keys in parity and directional-geometry checks clean | `lib/l10n/` |
| Riverpod legacy-provider, design-token, and widget-composition gates | `lib/` | Passed | `lib/` |

## Unverified assumptions

- The committed goldens are the stable Ahem/geometry lane. They verify theme surfaces, control placement, and mirroring-sensitive structure, but they do not verify real Chinese or English glyph shaping.
- A real-font golden lane is intentionally not claimed because Loquiris has not selected or bundled a redistributable bilingual font. Platform-font appearance remains subject to physical-device review and the later license audit.
- Automated semantics tests prove selected labels, roles, actions, live regions, and target sizes. They do not replace manual TalkBack, Switch Access, or Accessibility Scanner runs on the target Android device.
- All routed feature surfaces except the meeting-library shell remain explicit placeholders for later OpenSpec tasks.
- Locale override state is process-local in this phase. Persisting user settings belongs with the local settings/database implementation.

## Risks

- Long Chinese labels and OEM font metrics can differ from Ahem geometry; retain the 200% constrained-width tests and add the real-font/device lane once font policy is decided.
- The recovery UI currently consumes the minimal pre-domain `SessionSummary`; task 4 replaces it with the persisted lifecycle model without changing the no-auto-microphone rule.
- Navigation branch persistence is provided by `StatefulShellRoute.indexedStack`, but feature-specific scroll/form restoration must be verified as those screens replace placeholders.
- Visual review was host-rendered only; no claim is made about target-device color calibration, display cutouts, TalkBack behavior, or HyperOS font rendering.

## Recommendation

- Proceed to phase 4 domain modeling and Drift persistence while preserving the service boundary and URL identities established here.
- Add a real-font golden lane only after selecting a redistributable bilingual font and recording its license in `THIRD_PARTY_NOTICES.md`.
- Keep physical-device accessibility and font rendering as signed release evidence rather than inferring them from host widget tests.
