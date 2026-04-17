#!/usr/bin/env bash
# Orchestrates the iOS screenshot integration test:
#   1. Starts tool/screenshot_server.py in --mode ios on 127.0.0.1:8765.
#   2. Runs flutter drive, passing SCREENSHOT_HOST so the test POSTs to the
#      host (no cert needed — sim shares host loopback).
#   3. Tears the server down, preserving the test's exit code.
#
# Sidesteps `binding.takeScreenshot`, which hangs because the marble ticker
# calls setState every frame and Flutter's screenshot path waits for idle.
set -euo pipefail

UDID=${UDID:?UDID env var required (set by tool/boot_ios_simulator.sh)}
OUT_DIR=build/screenshots
PORT=8765

SERVER_PID=

cleanup() {
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

python3 tool/screenshot_server.py \
  --mode ios --udid "$UDID" \
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
  --device-id "$UDID" \
  --dart-define=SCREENSHOT_HOST="http://127.0.0.1:$PORT" || TEST_EXIT=$?
exit $TEST_EXIT
