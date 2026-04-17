#!/usr/bin/env bash
# Run this INSIDE the macOS VM (via SSH: ssh -p 2222 user@localhost).
# Installs Homebrew, Flutter, and Xcode CLI tools for iOS testing.
# Xcode itself must be downloaded manually from developer.apple.com
# (requires Apple ID) and installed before running this script.
set -euo pipefail

FLUTTER_VERSION="3.32.2"

echo "=== Installing Homebrew ==="
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "=== Installing Flutter ==="
FLUTTER_HOME="$HOME/flutter"
if [ ! -d "$FLUTTER_HOME" ]; then
  curl -fsSL \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar xJ -C "$HOME"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"
flutter precache --ios

echo "=== Accepting Xcode licenses ==="
sudo xcodebuild -license accept

echo "=== Installing CocoaPods ==="
sudo gem install cocoapods

echo "=== Running flutter doctor ==="
flutter doctor -v

echo ""
echo "Done. To run iOS screenshot test:"
echo "  1. Clone or mount the pensine repo in the VM"
echo "  2. source local/wsl_env.sh  (adjust paths for macOS)"
echo "  3. bash tool/boot_ios_simulator.sh"
echo "  4. bash tool/run_ios_screenshot_test.sh"
