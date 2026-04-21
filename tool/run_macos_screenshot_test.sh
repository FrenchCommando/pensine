#!/usr/bin/env bash
# Orchestrates the macOS screenshot integration test:
#   1. Starts tool/screenshot_server.py in --mode macos on 127.0.0.1:8765.
#   2. Runs flutter drive -d macos against integration_test/screenshot_test.dart,
#      passing SCREENSHOT_HOST so the test POSTs to the loopback server.
#   3. Tears the server down, preserving the test's exit code.
#
# Same shape as run_ios_screenshot_test.sh but no simulator/UDID dance —
# `flutter drive -d macos` launches the app as a native process and the
# server shells to `screencapture` on the host.
set -euo pipefail

OUT_DIR=build/screenshots
PORT=8765

SERVER_PID=

cleanup() {
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

python3 tool/screenshot_server.py \
  --mode macos \
  --port "$PORT" --out "$OUT_DIR" &
SERVER_PID=$!

for _ in {1..10}; do
  if curl -sf "http://127.0.0.1:$PORT/health"; then
    break
  fi
  sleep 0.5
done

TEST_EXIT=0
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  -d macos \
  --dart-define=SCREENSHOT_HOST="http://127.0.0.1:$PORT" || TEST_EXIT=$?
exit $TEST_EXIT
