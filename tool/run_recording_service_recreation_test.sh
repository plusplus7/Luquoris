#!/usr/bin/env bash

set -euo pipefail

adb_bin="${LOQUIRIS_ADB:-adb}"
target_package="com.loquiris.debug"
test_package="com.loquiris.debug.test"
runner="androidx.test.runner.AndroidJUnitRunner"
phase_key="loquirisRecordingRecreationPhase"
nonce_key="loquirisRecordingRecreationNonce"
nonce="recording-recreation-$(date -u +%Y%m%dT%H%M%SZ)-$$"
prepare_class="com.loquiris.recording.RecordingServiceProcessRecreationPreparationInstrumentedTest"
recover_class="com.loquiris.recording.RecordingServiceProcessRecreationRecoveryInstrumentedTest"

restore_microphone_permission() {
  "$adb_bin" shell pm grant "$target_package" android.permission.RECORD_AUDIO >/dev/null 2>&1 || true
}
trap restore_microphone_permission EXIT

if ! "$adb_bin" shell pm path "$target_package" | grep -q '^package:'; then
  echo "Missing installed target package: $target_package" >&2
  echo "Install the debug and androidTest APKs before running this host-orchestrated test." >&2
  exit 2
fi
if ! "$adb_bin" shell pm path "$test_package" | grep -q '^package:'; then
  echo "Missing installed test package: $test_package" >&2
  echo "Install the debug and androidTest APKs before running this host-orchestrated test." >&2
  exit 2
fi

# Clear any process or foreground-notification residue from an interrupted prior
# host run without deleting the persisted recovery fixture.
"$adb_bin" shell am force-stop "$target_package"

prepare_output="$("$adb_bin" shell am instrument -w -r \
  -e "$phase_key" prepare \
  -e "$nonce_key" "$nonce" \
  -e class "$prepare_class" \
  "$test_package/$runner" 2>&1)"
printf '%s\n' "$prepare_output"
if ! grep -q 'INSTRUMENTATION_RESULT: shortMsg=Process crashed\.' <<<"$prepare_output"; then
  echo "Preparation did not terminate the owning service process as expected." >&2
  exit 1
fi

marker="$("$adb_bin" shell run-as "$target_package" \
  cat files/recording-service-recreation/ready.json)"
if ! grep -q "\"nonce\":\"$nonce\"" <<<"$marker"; then
  echo "Preparation marker does not contain the fresh host nonce." >&2
  exit 1
fi

"$adb_bin" shell pm revoke "$target_package" android.permission.RECORD_AUDIO

recover_output="$("$adb_bin" shell am instrument -w -r \
  -e "$phase_key" recover \
  -e "$nonce_key" "$nonce" \
  -e class "$recover_class" \
  "$test_package/$runner" 2>&1)"
printf '%s\n' "$recover_output"
if ! grep -q 'OK (1 test)' <<<"$recover_output"; then
  echo "Independent cold-process recovery did not pass." >&2
  exit 1
fi
