#!/usr/bin/env bash
# One-shot installer for Android development in WSL2.
# Installs JDK 17, Android SDK (cmdline-tools, platform-tools, emulator,
# system image), Linux Flutter SDK, and build dependencies.
#
# Run in WSL2:  bash tool/setup_wsl_android.sh
# Then:         source ~/.bashrc
set -euo pipefail

ANDROID_API=35
SYSTEM_IMAGE="system-images;android-${ANDROID_API};google_apis;x86_64"
FLUTTER_VERSION="3.32.2"
ANDROID_HOME="$HOME/android-sdk"
FLUTTER_HOME="$HOME/flutter"

echo "=== Checking /dev/kvm ==="
if [ ! -e /dev/kvm ]; then
  echo "ERROR: /dev/kvm not found. Enable nested virtualization in WSL2."
  echo "Add to %USERPROFILE%\\.wslconfig:"
  echo "  [wsl2]"
  echo "  nestedVirtualization=true"
  echo "Then: wsl --shutdown and relaunch."
  exit 1
fi

echo "=== Installing system packages ==="
sudo apt-get update
sudo apt-get install -y \
  openjdk-17-jdk-headless \
  unzip wget curl git \
  ninja-build cmake clang pkg-config \
  libgtk-3-dev liblzma-dev libstdc++-12-dev \
  python3 openssl \
  libpulse0 libgl1-mesa-glx

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

echo "=== Installing Android SDK ==="
mkdir -p "$ANDROID_HOME/cmdline-tools"
if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
  CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
  CMDLINE_ZIP=$(mktemp)
  wget -q -O "$CMDLINE_ZIP" "$CMDLINE_URL"
  unzip -q "$CMDLINE_ZIP" -d "$ANDROID_HOME/cmdline-tools"
  mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  rm "$CMDLINE_ZIP"
fi

export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

yes | sdkmanager --licenses > /dev/null 2>&1 || true
sdkmanager --install \
  "platform-tools" \
  "emulator" \
  "platforms;android-${ANDROID_API}" \
  "build-tools;${ANDROID_API}.0.0" \
  "$SYSTEM_IMAGE"

echo "=== Installing Flutter SDK ==="
if [ ! -d "$FLUTTER_HOME" ]; then
  FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  wget -q -O - "$FLUTTER_URL" | tar xJ -C "$HOME"
fi

export PATH="$FLUTTER_HOME/bin:$PATH"

echo "=== Creating AVDs ==="
for PROFILE in pixel_7 pixel_tablet; do
  if ! avdmanager list avd -c 2>/dev/null | grep -q "^${PROFILE}$"; then
    echo "Creating AVD: $PROFILE"
    echo no | avdmanager create avd \
      --name "$PROFILE" \
      --package "$SYSTEM_IMAGE" \
      --device "$PROFILE" \
      --force
  else
    echo "AVD $PROFILE already exists, skipping"
  fi
done

echo "=== Writing environment to ~/.bashrc ==="
MARKER="# >>> pensine wsl android <<<"
if ! grep -q "$MARKER" ~/.bashrc 2>/dev/null; then
  cat >> ~/.bashrc << EOF

$MARKER
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=$ANDROID_HOME
export ANDROID_SDK_ROOT=$ANDROID_HOME
export FLUTTER_HOME=$FLUTTER_HOME
export PATH="\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/emulator:\$FLUTTER_HOME/bin:\$PATH"
# <<< pensine wsl android >>>
EOF
  echo "Environment variables appended to ~/.bashrc"
else
  echo "Environment already in ~/.bashrc, skipping"
fi

echo "=== Running flutter doctor ==="
flutter doctor --android-licenses <<< "y" 2>/dev/null || true
flutter doctor -v

echo ""
echo "Done. Run:  source ~/.bashrc"
echo "Then:       bash tool/boot_android_emulator.sh pixel_7"
