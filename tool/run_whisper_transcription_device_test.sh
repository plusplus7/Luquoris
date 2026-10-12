#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
adb_bin="${LOQUIRIS_ADB:-adb}"
flutter_bin="${FLUTTER_BIN:-flutter}"
target_package="com.loquiris.debug"
test_package="com.loquiris.debug.test"
runner="androidx.test.runner.AndroidJUnitRunner"
test_class="com.loquiris.transcription.WhisperTranscriptionEvidenceInstrumentedTest"
expected_model="M2104K10AC"
expected_device="chopin"
apk_path="$project_root/build/app/outputs/apk/debug/app-debug.apk"
test_apk_path="$project_root/build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk"
report_path="$project_root/docs/evidence/phase-11-whisper-transcription-device.json"
build_commit="$(git -C "$project_root" rev-parse --verify HEAD)"

device_count="$($adb_bin devices | awk '$2 == "device" { count += 1 } END { print count + 0 }')"
if [[ "$device_count" != "1" ]]; then
  echo "whisper_device_test.device_count_invalid" >&2
  exit 2
fi
actual_model="$($adb_bin shell getprop ro.product.model | tr -d '\r')"
actual_device="$($adb_bin shell getprop ro.product.device | tr -d '\r')"
if [[ "$actual_model" != "$expected_model" || "$actual_device" != "$expected_device" ]]; then
  echo "Wrong acceptance device: model=$actual_model device=$actual_device" >&2
  exit 2
fi

(cd "$project_root" && "$flutter_bin" build apk --debug)
gradle_java_home="${LOQUIRIS_JAVA_HOME:-$("$flutter_bin" config --list | sed -n 's/^  jdk-dir: //p' | head -n 1)}"
(cd "$project_root/android" && env JAVA_HOME="$gradle_java_home" ./gradlew :app:assembleDebugAndroidTest)

if [[ ! -f "$apk_path" || -L "$apk_path" || ! -f "$test_apk_path" || -L "$test_apk_path" ]]; then
  echo "whisper_device_test.artifact_missing" >&2
  exit 2
fi
if command -v sha256sum >/dev/null 2>&1; then
  apk_sha256="$(sha256sum "$apk_path" | awk '{ print $1 }')"
else
  apk_sha256="$(shasum -a 256 "$apk_path" | awk '{ print $1 }')"
fi

$adb_bin install -r -t "$apk_path" >/dev/null
$adb_bin install -r -t "$test_apk_path" >/dev/null
installed_path="$($adb_bin shell pm path "$target_package" | sed -n 's/^package://p' | tr -d '\r')"
if [[ -z "$installed_path" ]]; then
  echo "whisper_device_test.target_package_missing" >&2
  exit 2
fi

instrumentation_output="$($adb_bin shell am instrument -w -r \
  -e installedApkSha256 "$apk_sha256" \
  -e buildCommit "$build_commit" \
  -e class "$test_class" \
  "$test_package/$runner" 2>&1)"
printf '%s\n' "$instrumentation_output"
if ! grep -q 'OK (1 test)' <<<"$instrumentation_output"; then
  echo "whisper_device_test.instrumentation_failed" >&2
  exit 1
fi

$adb_bin shell run-as "$target_package" \
  cat files/device-validation/phase-11-whisper-transcription-device.json >"$report_path"
python3 -m json.tool "$report_path" >/dev/null
printf '%s\n' "whisper_device_test.complete: $report_path"
