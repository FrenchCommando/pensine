#!/usr/bin/env bash
# Records the iOS preview walkthrough cleanly:
#   1. Starts `flutter drive` in the background and tails its log.
#   2. Waits until the driver reports "Connected to Flutter application"
#      (i.e. build/install/launch is done — recording shouldn't waste time
#      on the build phase).
#   3. Records for a fixed window using `timeout -s INT`, which simctl
#      treats as the proper end-of-recording signal — finalizes the moov
#      atom and produces a playable MP4.
#   4. Waits for the test to finish, propagates its exit code.
#
# Lives in a single script because reactivecircus/android-emulator-runner-style
# YAML script blocks fragment multi-line bash; same goes for our iOS step.
set -euo pipefail

UDID=${UDID:?UDID env var required}
RECORD_SECONDS=${RECORD_SECONDS:-40}
OUT=build/preview-ios.mp4
LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

mkdir -p build

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/preview_test.dart \
  --device-id "$UDID" \
  >"$LOG" 2>&1 &
DRIVE_PID=$!

# Wait until the driver attaches to the app (build/install/launch finished).
while ! grep -q "Connected to Flutter application" "$LOG"; do
  if ! kill -0 "$DRIVE_PID" 2>/dev/null; then
    cat "$LOG"
    exit 1
  fi
  sleep 1
done

# Clean SIGINT-on-timeout = simctl finalizes the file properly.
timeout -s INT "${RECORD_SECONDS}s" \
  xcrun simctl io "$UDID" recordVideo --codec=h264 "$OUT" || true

wait "$DRIVE_PID"
TEST_EXIT=$?
cat "$LOG"
exit $TEST_EXIT
