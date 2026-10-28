#!/usr/bin/env bash
# End-to-end checks on an Android emulator (used by .github/workflows/ci.yml).
#
# 1. Runs the bridge/storage integration tests.
# 2. Runs the enforcement test while a background loop enables the
#    accessibility service through adb and keeps opening the Settings app,
#    which the test configures a blocking rule for.
set -euo pipefail

PACKAGE=dev.openblock.app
SERVICE="$PACKAGE/$PACKAGE.accessibility.OpenBlockAccessibilityService"

flutter test integration_test/bridge_test.dart

(
  # Wait for the test build to be (re)installed.
  sleep 20
  until adb shell pm list packages | grep -q "package:$PACKAGE"; do sleep 3; done
  adb shell settings put secure enabled_accessibility_services "$SERVICE"
  adb shell settings put secure accessibility_enabled 1
  for _ in $(seq 1 60); do
    sleep 5
    adb shell am start -W -a android.settings.SETTINGS >/dev/null 2>&1 || true
    sleep 3
    if adb shell dumpsys window windows 2>/dev/null | grep -q "ACCESSIBILITY_OVERLAY"; then
      echo "e2e: accessibility overlay is on screen"
    fi
  done
) &
LOOP_PID=$!
trap 'kill $LOOP_PID 2>/dev/null || true' EXIT

flutter test integration_test/enforcement_test.dart
