#!/usr/bin/env bash

set -euo pipefail

adb_bin="${LOQUIRIS_ADB:-adb}"
target_package="com.loquiris.debug"
test_package="com.loquiris.debug.test"
runner="androidx.test.runner.AndroidJUnitRunner"
test_class="com.loquiris.recording.RecordingOneHourPhysicalDeviceInstrumentedTest"
expected_model="M2104K10AC"
expected_device="chopin"
instrumentation_active=false

print_device_report() {
  set +e
  report_output="$("$adb_bin" shell run-as "$target_package" \
    cat files/device-validation/recording-one-hour.json 2>&1)"
  report_status=$?
  set -e
  printf '%s\n' "$report_output"
  return "$report_status"
}

stop_on_interruption() {
  trap - INT TERM
  if [[ "$instrumentation_active" == true ]]; then
    echo "Interrupted: force-stopping Loquiris to release the microphone; durable segments remain recoverable." >&2
    "$adb_bin" shell am force-stop "$target_package" >/dev/null 2>&1 || true
  fi
  print_device_report || true
  exit 130
}
trap stop_on_interruption INT TERM

if ! "$adb_bin" shell pm path "$target_package" | grep -q '^package:'; then
  echo "Missing installed target package: $target_package" >&2
  exit 2
fi
if ! "$adb_bin" shell pm path "$test_package" | grep -q '^package:'; then
  echo "Missing installed test package: $test_package" >&2
  exit 2
fi

actual_model="$("$adb_bin" shell getprop ro.product.model | tr -d '\r')"
actual_device="$("$adb_bin" shell getprop ro.product.device | tr -d '\r')"
if [[ "$actual_model" != "$expected_model" || "$actual_device" != "$expected_device" ]]; then
  echo "Wrong acceptance device: model=$actual_model device=$actual_device" >&2
  echo "Expected: model=$expected_model device=$expected_device" >&2
  exit 2
fi

"$adb_bin" shell pm grant "$target_package" android.permission.RECORD_AUDIO
"$adb_bin" shell pm grant "$target_package" android.permission.POST_NOTIFICATIONS

instrumentation_active=true
set +e
instrumentation_output="$("$adb_bin" shell am instrument -w -r \
  -e loquirisOneHour true \
  -e class "$test_class" \
  "$test_package/$runner" 2>&1)"
instrumentation_status=$?
set -e
instrumentation_active=false
printf '%s\n' "$instrumentation_output"
print_device_report || true
if [[ "$instrumentation_status" -ne 0 ]] || ! grep -q 'OK (1 test)' <<<"$instrumentation_output"; then
  "$adb_bin" shell am force-stop "$target_package" >/dev/null 2>&1 || true
  echo "One-hour physical-device instrumentation did not pass." >&2
  exit 1
fi
