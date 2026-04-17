#!/usr/bin/env bash
# Canonical env for local WSL2 development.
# Sourced by setup_wsl_android.sh and the .bat wrapper.
# CI uses its own setup actions, so this file isn't used there.
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=$HOME/android-sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export FLUTTER_HOME=$HOME/flutter
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$FLUTTER_HOME/bin:$PATH"
