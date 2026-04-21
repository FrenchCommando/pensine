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

# Pins the Pensine window to 1440x900 points via MainFlutterWindow.swift
# so screencapture produces a Mac-App-Store-accepted resolution. Env vars
# set here propagate to the child process `flutter drive` launches.
export PENSINE_WINDOW_SIZE=1440x900

SERVER_PID=

cleanup() {
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

# Pin to system /usr/bin/python3 — it ships with `pyobjc-framework-Quartz`
# (required for `_find_pensine_window_id`). GHA macos-15's bare `python3`
# usually resolves to Homebrew Python, which lacks pyobjc out of the box,
# so `from Quartz import ...` would fall back to full-display capture and
# screenshots would be the wrong resolution for Mac App Store validation.
PYTHON=${PYTHON:-/usr/bin/python3}
"$PYTHON" tool/screenshot_server.py \
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
