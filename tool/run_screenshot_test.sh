#!/usr/bin/env bash
# Orchestrates the Android screenshot integration test:
#   1. Mints a fresh self-signed cert/key for this run.
#   2. Starts tool/screenshot_server.py over HTTPS on 8765.
#   3. Runs flutter drive, passing the cert via --dart-define so the test
#      pins trust at runtime (no checked-in cert, no manifest changes).
#   4. Tears the server down, preserving the test's exit code.
#
# Lives in a single script because the GitHub action that wraps this
# (reactivecircus/android-emulator-runner) runs each YAML script line as a
# separate `sh -c`, so multi-line bash with shared variables won't work.
set -euo pipefail

OUT_DIR=build/screenshots
PORT=8765
mkdir -p "$OUT_DIR"

CERT_DIR=$(mktemp -d)
trap 'rm -rf "$CERT_DIR"' EXIT

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$CERT_DIR/key.pem" -out "$CERT_DIR/cert.pem" \
  -days 1 -subj "/CN=10.0.2.2" \
  -addext "subjectAltName=IP:10.0.2.2,IP:127.0.0.1"

CERT_B64=$(base64 -w0 "$CERT_DIR/cert.pem")

python3 tool/screenshot_server.py \
  --port "$PORT" --out "$OUT_DIR" \
  --cert "$CERT_DIR/cert.pem" --key "$CERT_DIR/key.pem" &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null || true; rm -rf "$CERT_DIR"' EXIT

# Wait for the server to bind before starting the test.
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if curl -sf --cacert "$CERT_DIR/cert.pem" "https://127.0.0.1:$PORT/health"; then
    break
  fi
  sleep 0.5
done

set +e
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  --dart-define=SCREENSHOT_CERT_B64="$CERT_B64"
TEST_EXIT=$?
set -e

kill $SERVER_PID 2>/dev/null || true
exit $TEST_EXIT
