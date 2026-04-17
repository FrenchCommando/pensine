#!/usr/bin/env bash
# Records the Android preview walkthrough cleanly:
#   1. Starts `flutter drive` in the background and tails its log.
#   2. Waits until the driver reports "Connected to Flutter application"
#      (build/install/launch done) so the recording isn't dominated by
#      the build phase.
#   3. Records via `adb shell screenrecord --time-limit=N` — the time-limit
#      exit path is a clean shutdown that flushes the MP4 muxer's moov atom,
#      unlike the SIGINT-killed pattern that was producing first-frame-only
#      files in VLC.
#   4. Waits for the test to finish, pulls the file, propagates exit code.
#
# Lives in a single script because the GitHub action wrapping this runs each
# YAML script line as a separate `sh -c`, fragmenting multi-line bash.
set -euo pipefail

RECORD_SECONDS=${RECORD_SECONDS:-40}
DEVICE_PATH=/sdcard/preview.mp4
OUT=build/preview-android.mp4
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
  >"$LOG" 2>&1 &
DRIVE_PID=$!

while ! grep -q "Connected to Flutter application" "$LOG"; do
  if ! kill -0 "$DRIVE_PID" 2>/dev/null; then
    exit 1
  fi
  sleep 1
done

# Clean exit at --time-limit = finalized MP4 (no SIGINT).
adb shell screenrecord --time-limit="$RECORD_SECONDS" "$DEVICE_PATH"
adb pull "$DEVICE_PATH" "$OUT"

TEST_EXIT=0
wait "$DRIVE_PID" || TEST_EXIT=$?
exit $TEST_EXIT
