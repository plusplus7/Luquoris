#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

failed=0

report() {
  printf 'privacy gate: %s\n' "$1" >&2
  failed=1
}

if ! dart run tool/release_privacy_policy.dart; then
  report 'structured manifest or resolved dependency policy failed'
fi

if find lib -type f -name '*.dart' -print0 | xargs -0 grep -En \
  "^[[:space:]]*import[[:space:]]+['\"]package:(http|dio|chopper|retrofit|graphql|web_socket_channel|firebase_|sentry|google_mobile_ads|applovin|max|appsflyer|amplitude|mixpanel|posthog|appmetrica)"; then
  report 'network, telemetry, advertising, or remote-config import under lib/'
fi

if find lib -type f -name '*.dart' -print0 | \
  xargs -0 grep -En "['\"]https?://"; then
  report 'runtime URL literal under lib/'
fi

if find android -type f \( -name '*.gradle' -o -name '*.gradle.kts' \) \
  -print0 | xargs -0 grep -Eni \
  '(firebase|crashlytics|sentry|google-mobile-ads|applovin|appsflyer|amplitude|mixpanel|posthog|appmetrica|segment-analytics|okhttp|retrofit)'; then
  report 'forbidden native dependency or plugin under android/'
fi

if (( failed != 0 )); then
  exit 1
fi

if [[ "${1:-}" == "--source-only" ]]; then
  printf 'privacy gate: source dependency and manifest policy passed\n'
  exit 0
fi

apk_path="${1:-build/app/outputs/flutter-apk/app-release.apk}"
if [[ ! -f "$apk_path" ]]; then
  printf 'privacy gate: release APK not found: %s\n' "$apk_path" >&2
  exit 2
fi

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$sdk_root" && -n "${HOME:-}" && -d "$HOME/Library/Android/sdk" ]]; then
  sdk_root="$HOME/Library/Android/sdk"
fi
if [[ -z "$sdk_root" || ! -d "$sdk_root/build-tools" ]]; then
  printf 'privacy gate: Android SDK build-tools not found\n' >&2
  exit 2
fi

aapt_path="$(find "$sdk_root/build-tools" -type f -name aapt2 | sort | tail -n 1)"
if [[ -z "$aapt_path" ]]; then
  printf 'privacy gate: aapt2 not found\n' >&2
  exit 2
fi

badging="$($aapt_path dump badging "$apk_path")"
if grep -Eq "uses-permission: name='android.permission.(INTERNET|ACCESS_NETWORK_STATE)'" <<<"$badging"; then
  printf 'privacy gate: release APK contains a forbidden network permission\n' >&2
  exit 1
fi

printf 'privacy gate: release APK contains no network permissions\n'
