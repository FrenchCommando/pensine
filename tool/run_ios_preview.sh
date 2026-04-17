#!/usr/bin/env bash
# Records the iOS preview walkthrough cleanly:
#   1. Starts `flutter drive` in the background and tails its log.
#   2. Waits until the driver reports "Connected to Flutter application"
#      (i.e. build/install/launch is done — recording shouldn't waste time
#      on the build phase).
#   3. Records for a fixed window, then sends SIGINT and waits for simctl
#      to exit — simctl treats SIGINT as a clean shutdown, which finalizes
#      the moov atom and produces a playable MP4. The `wait` is critical:
#      exiting the shell before simctl finishes flushing truncates the file.
#   4. Waits for the test to finish, propagates its exit code.
#
# macOS runners don't have GNU `timeout`, so we do the "send signal after
# N seconds" dance manually.
set -euo pipefail

UDID=${UDID:?UDID env var required}
RECORD_SECONDS=${RECORD_SECONDS:-40}
OUT=build/preview-ios.mp4
LOG=$(mktemp)

cleanup() {
  cat "$LOG" 2>/dev/null || true
  rm -f "$LOG"
}
trap cleanup EXIT

mkdir -p build

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/preview_test.dart \
  --device-id "$UDID" \
  >"$LOG" 2>&1 &
DRIVE_PID=$!

while ! grep -q "Connected to Flutter application" "$LOG"; do
  if ! kill -0 "$DRIVE_PID" 2>/dev/null; then
    exit 1
  fi
  sleep 1
done

xcrun simctl io "$UDID" recordVideo --codec=h264 "$OUT" &
REC_PID=$!
sleep "$RECORD_SECONDS"
kill -INT "$REC_PID" 2>/dev/null || true
wait "$REC_PID" 2>/dev/null || true

TEST_EXIT=0
wait "$DRIVE_PID" || TEST_EXIT=$?
exit $TEST_EXIT
