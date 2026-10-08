#!/usr/bin/env bash
set -euo pipefail

readonly TARGET_PACKAGE="com.loquiris"
readonly TARGET_MODEL="M2104K10AC"
readonly TARGET_DEVICE="chopin"
readonly HELPER_PACKAGE="com.loquiris.tools.footprint"
readonly HELPER_TEST_PACKAGE="com.loquiris.tools.footprint.test"
readonly ADB="${ADB_BIN:-adb}"

fail() {
  printf '%s\n' "$1" >&2
  exit "${2:-1}"
}

require_single_target_device() {
  local device_serials
  local device_count
  local serial
  local model
  local device
  local fingerprint
  device_serials="$($ADB devices -l | awk '$2 == "device" { print $1 }')"
  device_count="$(printf '%s\n' "$device_serials" | awk 'NF { count += 1 } END { print count + 0 }')"
  if [[ "$device_count" != "1" ]]; then
    fail "release_footprint.device_count_invalid" 65
  fi
  serial="$(printf '%s\n' "$device_serials" | awk 'NF { print; exit }')"
  model="$($ADB -s "$serial" shell getprop ro.product.model | tr -d '\r')"
  device="$($ADB -s "$serial" shell getprop ro.product.device | tr -d '\r')"
  fingerprint="$($ADB -s "$serial" shell getprop ro.build.fingerprint | tr -d '\r')"
  if [[ "$model" != "$TARGET_MODEL" || "$device" != "$TARGET_DEVICE" || -z "$fingerprint" ]]; then
    fail "release_footprint.target_identity_mismatch" 65
  fi
  DEVICE_SERIAL="$serial"
  DEVICE_MODEL="$model"
  DEVICE_FINGERPRINT="$fingerprint"
}

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
    return
  fi
  shasum -a 256 "$1" | awk '{ print $1 }'
}

require_regular_file() {
  [[ -f "$1" && ! -L "$1" ]] || fail "release_footprint.artifact_not_regular" 66
}

check_aab_symbols() {
  local aab_path="$1"
  local entries
  require_regular_file "$aab_path"
  if ! entries="$(unzip -Z1 "$aab_path" 2>/dev/null)"; then
    fail "release_footprint.aab_symbols_missing" 66
  fi
  printf '%s\n' "$entries" |
    grep -Eq '^BUNDLE-METADATA/.+/libflutter\.so\.(sym|dbg)$' ||
    fail "release_footprint.aab_symbols_missing" 66
  printf '%s\n' "$entries" |
    grep -Eq '^BUNDLE-METADATA/.+/libapp\.so\.(sym|dbg)$' ||
    fail "release_footprint.aab_symbols_missing" 66
}

resolve_apksigner() {
  local adb_path
  local sdk_root
  local candidate
  if [[ -n "${APKSIGNER_BIN:-}" ]]; then
    [[ -x "$APKSIGNER_BIN" ]] || fail "release_footprint.apksigner_missing" 69
    printf '%s\n' "$APKSIGNER_BIN"
    return
  fi
  if command -v apksigner >/dev/null 2>&1; then
    command -v apksigner
    return
  fi
  if [[ -x "$ADB" ]]; then
    adb_path="$ADB"
  else
    adb_path="$(command -v "$ADB" 2>/dev/null || true)"
  fi
  if [[ "$adb_path" == */platform-tools/adb ]]; then
    sdk_root="${adb_path%/platform-tools/adb}"
  else
    sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
  fi
  candidate="$(find "$sdk_root/build-tools" -mindepth 2 -maxdepth 2 \
    -type f -name apksigner -print 2>/dev/null | sort | tail -n 1)"
  [[ -n "$candidate" && -x "$candidate" ]] ||
    fail "release_footprint.apksigner_missing" 69
  printf '%s\n' "$candidate"
}

sign_measurement_apk() {
  local apk_path="$1"
  local keytool
  local apksigner
  local keystore
  local password
  require_regular_file "$apk_path"
  keytool="${KEYTOOL_BIN:-$(command -v keytool 2>/dev/null || true)}"
  [[ -n "$keytool" && -x "$keytool" ]] ||
    fail "release_footprint.keytool_missing" 69
  apksigner="$(resolve_apksigner)"
  keystore="$(mktemp "${TMPDIR:-/tmp}/loquiris-measurement-signing.XXXXXX.p12")"
  rm -f "$keystore"
  password="$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')"
  if ! LOQUIRIS_MEASUREMENT_KEY_PASS="$password" "$keytool" \
    -genkeypair -noprompt -storetype PKCS12 -keystore "$keystore" \
    -storepass:env LOQUIRIS_MEASUREMENT_KEY_PASS \
    -keypass:env LOQUIRIS_MEASUREMENT_KEY_PASS \
    -alias loquiris-measurement -keyalg RSA -keysize 2048 -validity 1 \
    -dname "CN=Loquiris measurement-only local signing"; then
    rm -f "$keystore"
    fail "release_footprint.measurement_key_failed" 66
  fi
  if ! LOQUIRIS_MEASUREMENT_KEY_PASS="$password" "$apksigner" sign \
    --ks "$keystore" \
    --ks-pass env:LOQUIRIS_MEASUREMENT_KEY_PASS \
    --key-pass env:LOQUIRIS_MEASUREMENT_KEY_PASS \
    "$apk_path"; then
    rm -f "$keystore"
    fail "release_footprint.apk_signing_failed" 66
  fi
  rm -f "$keystore"
  "$apksigner" verify --verbose "$apk_path" >/dev/null ||
    fail "release_footprint.apk_signature_invalid" 66
}

uninstall_if_present() {
  local serial="$1"
  local package_name="$2"
  if $ADB -s "$serial" shell pm path "$package_name" 2>/dev/null | grep -q '^package:'; then
    $ADB -s "$serial" uninstall "$package_name" >/dev/null ||
      fail "release_footprint.uninstall_failed" 66
  fi
  if $ADB -s "$serial" shell pm path "$package_name" 2>/dev/null | grep -q '^package:'; then
    fail "release_footprint.preexisting_package_data" 66
  fi
}

if [[ "${1:-}" == "--check-aab-only" ]]; then
  [[ "$#" == "2" ]] || fail "release_footprint.usage" 64
  check_aab_symbols "$2"
  printf '%s\n' "release_footprint.aab_symbols_ready"
  exit 0
fi

if [[ "${1:-}" == "--sign-apk-only" ]]; then
  [[ "$#" == "2" ]] || fail "release_footprint.usage" 64
  sign_measurement_apk "$2"
  printf '%s\n' "release_footprint.apk_signed"
  exit 0
fi

require_single_target_device
if [[ "${1:-}" == "--check-device-only" ]]; then
  [[ "$#" == "1" ]] || fail "release_footprint.usage" 64
  printf '%s\n' "release_footprint.device_ready"
  exit 0
fi
[[ "$#" == "0" ]] || fail "release_footprint.usage" 64

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly FLUTTER="${FLUTTER_BIN:-flutter}"
readonly DART="${DART_BIN:-dart}"
readonly GRADLE_JAVA_HOME="${LOQUIRIS_JAVA_HOME:-$("$FLUTTER" config --list |
  sed -n 's/^  jdk-dir: //p' | head -n 1)}"
[[ -x "$GRADLE_JAVA_HOME/bin/java" ]] ||
  fail "release_footprint.java_toolchain_missing" 69
readonly APK_PATH="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-release.apk"
readonly AAB_PATH="$PROJECT_ROOT/build/app/outputs/bundle/release/app-release.aab"
readonly HELPER_APK="$PROJECT_ROOT/build/footprint-measurer/outputs/apk/debug/footprint-measurer-debug.apk"
readonly HELPER_TEST_APK="$PROJECT_ROOT/build/footprint-measurer/outputs/apk/androidTest/debug/footprint-measurer-debug-androidTest.apk"
readonly WORK_DIR="$PROJECT_ROOT/build/release-footprint"
readonly RAW_OUTPUT="$WORK_DIR/instrumentation.txt"
readonly INSTALLED_JSON="$WORK_DIR/installed.json"
readonly REPORT_JSON="$PROJECT_ROOT/docs/evidence/phase-10-release-footprint.json"

mkdir -p "$WORK_DIR"
rm -f "$APK_PATH" "$AAB_PATH" "$RAW_OUTPUT" "$INSTALLED_JSON"

(cd "$PROJECT_ROOT" && "$FLUTTER" build apk --release)
if ! (cd "$PROJECT_ROOT" && "$FLUTTER" build appbundle --release); then
  check_aab_symbols "$AAB_PATH"
fi
require_regular_file "$APK_PATH"
require_regular_file "$AAB_PATH"
check_aab_symbols "$AAB_PATH"
sign_measurement_apk "$APK_PATH"

(cd "$PROJECT_ROOT/android" && env JAVA_HOME="$GRADLE_JAVA_HOME" ./gradlew \
  :footprint-measurer:assembleDebug \
  :footprint-measurer:assembleDebugAndroidTest)
require_regular_file "$HELPER_APK"
require_regular_file "$HELPER_TEST_APK"

readonly APK_SHA256="$(hash_file "$APK_PATH")"
readonly COMMIT_ID="$(cd "$PROJECT_ROOT" && git rev-parse --verify HEAD)"
readonly BUILD_ID="${COMMIT_ID}-${APK_SHA256:0:12}"

uninstall_if_present "$DEVICE_SERIAL" "$TARGET_PACKAGE"
uninstall_if_present "$DEVICE_SERIAL" "$HELPER_TEST_PACKAGE"
uninstall_if_present "$DEVICE_SERIAL" "$HELPER_PACKAGE"

cleanup_helper() {
  $ADB -s "$DEVICE_SERIAL" uninstall "$HELPER_TEST_PACKAGE" >/dev/null 2>&1 || true
  $ADB -s "$DEVICE_SERIAL" uninstall "$HELPER_PACKAGE" >/dev/null 2>&1 || true
}
trap cleanup_helper EXIT

$ADB -s "$DEVICE_SERIAL" install "$APK_PATH" >/dev/null ||
  fail "release_footprint.target_install_failed" 66
readonly INSTALLED_PACKAGE_PATH="$($ADB -s "$DEVICE_SERIAL" shell pm path "$TARGET_PACKAGE" | tr -d '\r')"
[[ "$INSTALLED_PACKAGE_PATH" == package:* ]] ||
  fail "release_footprint.target_package_missing" 66
readonly VERSION_CODE="$($ADB -s "$DEVICE_SERIAL" shell dumpsys package "$TARGET_PACKAGE" |
  sed -n 's/.*versionCode=\([0-9][0-9]*\).*/\1/p' | head -n 1)"
[[ "$VERSION_CODE" =~ ^[1-9][0-9]*$ ]] ||
  fail "release_footprint.target_version_invalid" 66

$ADB -s "$DEVICE_SERIAL" install "$HELPER_APK" >/dev/null ||
  fail "release_footprint.helper_install_failed" 66
$ADB -s "$DEVICE_SERIAL" install "$HELPER_TEST_APK" >/dev/null ||
  fail "release_footprint.helper_test_install_failed" 66
$ADB -s "$DEVICE_SERIAL" shell appops set "$HELPER_PACKAGE" GET_USAGE_STATS allow
$ADB -s "$DEVICE_SERIAL" shell appops get "$HELPER_PACKAGE" GET_USAGE_STATS |
  grep -q 'allow' || fail "release_footprint.usage_stats_not_granted" 66

if ! $ADB -s "$DEVICE_SERIAL" shell am instrument -w -r \
  -e targetPackage "$TARGET_PACKAGE" \
  -e buildId "$BUILD_ID" \
  -e installedApkSha256 "$APK_SHA256" \
  -e deviceSerial "$DEVICE_SERIAL" \
  -e cleanInstall true \
  "$HELPER_TEST_PACKAGE/androidx.test.runner.AndroidJUnitRunner" >"$RAW_OUTPUT"; then
  fail "release_footprint.instrumentation_failed" 66
fi

(cd "$PROJECT_ROOT" && "$DART" run \
  tool/release_size/android_storage_measurement_adapter.dart \
  --instrumentation-output "build/release-footprint/instrumentation.txt" \
  --package-name "$TARGET_PACKAGE" \
  --version-code "$VERSION_CODE" \
  --build-id "$BUILD_ID" \
  --device-serial "$DEVICE_SERIAL" \
  --device-model "$DEVICE_MODEL" \
  --build-fingerprint "$DEVICE_FINGERPRINT" \
  --installed-apk-sha256 "$APK_SHA256" \
  --clean-install-verified true \
  --output "build/release-footprint/installed.json")

(cd "$PROJECT_ROOT" && "$DART" run tool/check_release_footprint.dart \
  --apk "universal=build/app/outputs/flutter-apk/app-release.apk" \
  --aab "build/app/outputs/bundle/release/app-release.aab" \
  --installed-measurement "build/release-footprint/installed.json" \
  --output "docs/evidence/phase-10-release-footprint.json")

printf '%s\n' "release_footprint.complete"
