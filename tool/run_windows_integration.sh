#!/usr/bin/env bash
# Hard-block local Windows integration runs before `flutter drive` even
# builds. Local builds share `%APPDATA%`, `%TEMP%`, and the
# shared_preferences registry hive with the installed Pensine, so a local
# run leaks the test's "Integration Test Workspace" into the user's real
# boards.
#
# CI sets CI=true automatically (GitHub Actions). The in-test guard in
# `integration_test/test_helpers.dart::requireCIOnWindows` fires as
# defense-in-depth if someone bypasses this script.
set -euo pipefail

if [ "${CI:-}" != "true" ]; then
  cat >&2 <<'EOF'
ERROR: Windows integration tests are CI-only.

Local runs share data with the installed Pensine app (%APPDATA%, %TEMP%,
shared_preferences) and will leak the test's fixtures into your real
workspaces.

If you must run locally for debugging, accept the data pollution and
override:
  CI=true bash tool/run_windows_integration.sh <integration_test/foo.dart>
EOF
  exit 1
fi

if [ $# -lt 1 ]; then
  echo "Usage: $0 <integration_test_target.dart>" >&2
  exit 2
fi

exec flutter drive \
  --driver=test_driver/integration_test.dart \
  --target="$1" \
  -d windows
