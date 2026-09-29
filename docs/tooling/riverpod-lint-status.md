# Riverpod lint plugin status

`riverpod_lint` is intentionally not enabled in the bootstrap toolchain.

On Flutter 3.44.0 / Dart 3.12.0, a clean `dart analyze` with the first-party `plugins:` configuration for `riverpod_lint` 3.1.4 loaded `analysis_server_plugin` 0.3.14 and then remained idle without diagnostics for more than five minutes. Clearing and rebuilding the plugin-manager AOT cache did not change the result. The same source tree completed analysis in under five seconds when the plugin block was removed.

This matches an open class of Dart analysis-server plugin hangs. The project keeps Riverpod 3, strict very_good_analysis, architecture/import scripts, and normal compile/test gates, but refuses a plugin configuration that can hang CI indefinitely.

Re-evaluate the plugin only after upgrading to a Dart/Flutter release with a verified upstream fix. A re-evaluation must use a timed cold-cache and warm-cache analyzer test before the dependency is restored.

Reference: <https://github.com/dart-lang/sdk/issues/63538>
