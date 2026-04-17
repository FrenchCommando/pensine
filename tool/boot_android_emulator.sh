#!/usr/bin/env bash
# Boots an Android emulator by AVD name, waits for boot, sets up the status bar.
# Usage (in WSL2):  bash tool/boot_android_emulator.sh pixel_7
#                   bash tool/boot_android_emulator.sh pixel_tablet
#
# After boot, run the screenshot test the same way CI does:
#   bash tool/run_screenshot_test.sh
set -euo pipefail

AVD_NAME=${1:?AVD name required (e.g. pixel_7, pixel_tablet)}

# Kill any running emulator first.
if adb devices 2>/dev/null | grep -q "emulator-"; then
  echo "Killing existing emulator..."
  adb emu kill 2>/dev/null || true
  sleep 2
fi

echo "Booting AVD: $AVD_NAME"
emulator -avd "$AVD_NAME" -no-window -no-audio -gpu swiftshader_indirect &
EMULATOR_PID=$!

# Wait for device to appear and finish booting (up to 120s).
echo "Waiting for device..."
adb wait-for-device

TIMEOUT=120
ELAPSED=0
while [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "ERROR: Emulator did not finish booting within ${TIMEOUT}s"
    kill "$EMULATOR_PID" 2>/dev/null || true
    exit 1
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done

echo "Emulator booted in ${ELAPSED}s"

echo "Setting up status bar..."
bash tool/setup_android_status_bar.sh

echo "Ready. Emulator PID: $EMULATOR_PID"
echo "Run:  bash tool/run_screenshot_test.sh"
