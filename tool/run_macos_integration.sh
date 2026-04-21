#!/usr/bin/env bash
# Belt-and-suspenders guard, same pattern as `run_windows_integration.sh`:
# blocks local runs before `flutter drive` builds. The in-test guard in
# `integration_test/test_helpers.dart::requireCIForNativeDesktop` is the
# second layer. The data-pollution risk is real — a local build shares
# `~/Library/Application Support/com.frenchcommando.pensine/` and
# `$TMPDIR/pensine_incoming.pensine` with any installed Pensine.app, so
# fixture workspaces would leak into your real boards.
#
# Primary runner: GitHub Actions `macos-15` (workflow sets CI=true).
# Local runs on a real Mac — or inside the OSX-KVM VM in `local/IOS/`,
# viability for `flutter drive -d macos` not yet measured — work with
# the `CI=true` override below, provided you're OK with the pollution.
set -euo pipefail

if [ "${CI:-}" != "true" ]; then
  cat >&2 <<'EOF'
ERROR: macOS integration tests are CI-only by default.

Primary runner is GHA `macos-15`. Local runs (real Mac, or the OSX-KVM
VM in local/IOS/ — viability for `flutter drive -d macos` untested)
are possible if you accept the data-pollution risk (shared
~/Library/Application Support + $TMPDIR with any installed Pensine
would leak test fixtures into your real boards).

To override and run anyway:
  CI=true bash tool/run_macos_integration.sh <integration_test/foo.dart>
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
  -d macos
