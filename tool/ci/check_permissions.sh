#!/usr/bin/env bash
# Fails if a release APK requests permissions OpenBlock must not have.
set -euo pipefail
APK="$1"
AAPT2=$(ls -d "$ANDROID_HOME"/build-tools/*/ | sort -V | tail -1)aapt2
PERMISSIONS=$("$AAPT2" dump permissions "$APK")
echo "$PERMISSIONS"
for forbidden in android.permission.INTERNET android.permission.QUERY_ALL_PACKAGES android.permission.SYSTEM_ALERT_WINDOW; do
  if echo "$PERMISSIONS" | grep -q "$forbidden"; then
    echo "::error::$APK requests $forbidden"
    exit 1
  fi
done
echo "Permissions OK"
