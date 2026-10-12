#!/usr/bin/env bash

set -euo pipefail

adb_bin="${LOQUIRIS_ADB:-adb}"
target_package="com.loquiris.debug"
test_package="com.loquiris.debug.test"
runner="androidx.test.runner.AndroidJUnitRunner"
phase_key="loquirisDeviceRestartPhase"
nonce_key="loquirisRecordingRecreationNonce"
nonce="device-restart-$(date -u +%Y%m%dT%H%M%SZ)-$$"
prepare_class="com.loquiris.recording.RecordingDeviceRestartPreparationInstrumentedTest"
recover_class="com.loquiris.recording.RecordingDeviceRestartRecoveryInstrumentedTest"
task_temp_dir="$(mktemp -d)"
prepare_log="$task_temp_dir/prepare.log"

cleanup() {
  rm -rf "$task_temp_dir"
}
trap cleanup EXIT

if ! "$adb_bin" shell pm path "$target_package" | grep -q '^package:'; then
  echo "Missing installed target package: $target_package" >&2
  exit 2
fi
if ! "$adb_bin" shell pm path "$test_package" | grep -q '^package:'; then
  echo "Missing installed test package: $test_package" >&2
  exit 2
fi

# MIUI can retain a denied RECORD_AUDIO app-op across debug reinstalls even
# after PackageManager permission grant. Normalize both gates explicitly.
"$adb_bin" shell am force-stop "$target_package"
"$adb_bin" shell pm grant "$target_package" android.permission.RECORD_AUDIO
"$adb_bin" shell appops set --uid "$target_package" RECORD_AUDIO allow

"$adb_bin" shell am instrument -w -r \
  -e "$phase_key" prepare \
  -e "$nonce_key" "$nonce" \
  -e class "$prepare_class" \
  "$test_package/$runner" >"$prepare_log" 2>&1 &
prepare_pid=$!

marker=""
for _ in $(seq 1 90); do
  marker="$(
    "$adb_bin" shell run-as "$target_package" \
      cat files/recording-device-restart/ready.json 2>/dev/null || true
  )"
  if grep -Fq "\"nonce\":\"$nonce\"" <<<"$marker"; then
    break
  fi
  sleep 1
done
if ! grep -Fq "\"nonce\":\"$nonce\"" <<<"$marker"; then
  cat "$prepare_log" >&2
  echo "Preparation did not publish the fresh durable marker." >&2
  exit 1
fi

"$adb_bin" reboot
"$adb_bin" wait-for-device
for _ in $(seq 1 180); do
  if [[ "$("$adb_bin" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; then
    break
  fi
  sleep 1
done
if [[ "$("$adb_bin" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]]; then
  echo "Device did not finish booting within 180 seconds." >&2
  exit 1
fi

"$adb_bin" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
"$adb_bin" shell wm dismiss-keyguard >/dev/null 2>&1 || true
if [[ "$("$adb_bin" shell cmd user is-user-unlocked 2>/dev/null | tr -d '\r')" != "true" ]]; then
  echo "Device rebooted successfully but credential storage is locked; unlock once and rerun the recovery command." >&2
  echo "$adb_bin shell am instrument -w -r -e $phase_key recover -e $nonce_key $nonce -e class $recover_class $test_package/$runner" >&2
  exit 3
fi

wait "$prepare_pid" || true
cat "$prepare_log"
recover_output="$(
  "$adb_bin" shell am instrument -w -r \
    -e "$phase_key" recover \
    -e "$nonce_key" "$nonce" \
    -e class "$recover_class" \
    "$test_package/$runner" 2>&1
)"
echo "$recover_output"
if ! grep -q 'OK (1 test)' <<<"$recover_output"; then
  echo "Independent post-reboot recovery did not pass." >&2
  exit 1
fi
