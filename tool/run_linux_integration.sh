#!/usr/bin/env bash
# Hard-block local Linux integration runs before `flutter drive` builds.
# Local Linux builds share `$XDG_DATA_HOME` (shared_preferences +
# path_provider backing store) and `$TMPDIR`/`/tmp` (pending-import
# handoff file) with any installed Pensine .deb/AppImage, so a local
# run leaks the test's "Integration Test Workspace" into the user's
# real workspaces.
#
# CI sets CI=true automatically (GitHub Actions). The in-test guard in
# `integration_test/test_helpers.dart::requireCIForNativeDesktop` fires
# as defense-in-depth if this script is bypassed.
set -euo pipefail

if [ "${CI:-}" != "true" ]; then
  cat >&2 <<'EOF'
ERROR: Linux integration tests are CI-only.

Local runs share data with any installed Pensine (shared_preferences,
path_provider, /tmp/pensine_incoming.pensine) and will leak the test's
fixtures into your real workspaces.

If you must run locally for debugging, accept the data pollution and
override:
  CI=true bash tool/run_linux_integration.sh <integration_test/foo.dart>
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
  -d linux
