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

# Window size comes from the XIB (`macos/Runner/Base.lproj/MainMenu.xib`
# contentRect), set to 1440x900 points — a Mac-App-Store-accepted size
# for the screenshot capture (Retina renders at 2880x1800 px).

SERVER_PID=

cleanup() {
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

# pyobjc isn't preinstalled on GHA macos-15 (neither Homebrew python3 nor
# /usr/bin/python3 ships it in practice). Set up a throwaway venv with
# just `pyobjc-framework-Quartz` so `_find_pensine_window_id` can use
# CGWindowList → screencapture -l <windowID> for clean window-region
# captures at the right Mac-App-Store resolution. Without this the server
# falls back to full-display capture and a passing TCC dialog lands in
# the screenshot.
VENV="${RUNNER_TEMP:-/tmp}/screenshot-venv"
if [ ! -d "$VENV" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet pyobjc-framework-Quartz
fi
"$VENV/bin/python" tool/screenshot_server.py \
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
