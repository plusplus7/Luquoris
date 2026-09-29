# Pinned Toolchain

The bootstrap target is pinned for reproducible local and CI setup:

| Component | Version |
|---|---:|
| Flutter | 3.44.0 stable, revision `559ffa3f75e7402d65a8def9c28389a9b2e6fe42` |
| Dart | Flutter-bundled SDK from the pinned revision |
| Java | 17 |
| Android Gradle Plugin | 9.0.1 |
| Gradle | 9.1.0 |
| Kotlin | 2.3.20 |
| Android compile SDK | 36 |
| Android target SDK | 36 |
| Android minimum SDK | 29 |
| Android NDK | 28.2.13676358 |

## Clean bootstrap

1. Install the exact Flutter stable revision outside the repository and put its `bin` on PATH.
2. Install JDK 17 and configure Flutter to use it for Android builds.
3. Install Android SDK platforms 35/36, matching build tools, and NDK 28.2.13676358; accept Android SDK licenses explicitly.
4. Run `flutter doctor -v` and preserve output in phase evidence.
5. Run `flutter pub get`, deterministic code generation, formatting, analysis, tests, and Android builds using committed lock/wrapper files.

Local SDK paths, signing keys, model weights, and secrets must not be committed. The implementation environment uses project-specific cached Flutter 3.44.0 and Temurin 17 installations rather than changing the system SDK defaults.
