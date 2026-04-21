#!/usr/bin/env bash
# Packages the Flutter Linux release bundle into an AppImage.
#
# Uses linuxdeploy + linuxdeploy-plugin-gtk (both self-contained AppImages
# downloaded into a tmp dir; nothing checked in). The GTK plugin bundles
# GDK/GIO schemas, GTK themes, and pulls in transitive .so deps that the
# stock linuxdeploy misses.
#
# Usage:
#   linux/packaging/build_appimage.sh <version> <build_number> <output_appimage_path>
set -euo pipefail

VERSION=${1:?version required}
BUILD_NUMBER=${2:?build number required}
OUTPUT=${3:?output AppImage path required}

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BUNDLE_DIR="$REPO_ROOT/build/linux/x64/release/bundle"
if [ ! -d "$BUNDLE_DIR" ]; then
  echo "Bundle not found at $BUNDLE_DIR — run 'flutter build linux --release' first" >&2
  exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# --- AppDir layout.
#
# Flutter's Linux bundle is pinned together: the binary locates its
# flutter_assets/icudtl.dat via `/proc/self/exe` + `./data`, and finds
# libflutter_linux_gtk.so + libapp.so + plugin .so's via the binary's
# RPATH `$ORIGIN/lib` (set in linux/CMakeLists.txt). These three pieces
# (binary, data/, lib/) have to stay siblings.
#
# Simplest AppDir layout that preserves the sibling relationship *and*
# makes linuxdeploy trace the binary's system-lib deps: drop the whole
# bundle flat into `usr/bin/`. linuxdeploy scans `usr/bin/*` by default,
# picks up `pensine` as the main ELF, and follows its dependencies into
# `usr/lib/` where linuxdeploy-plugin-gtk bundles GTK/glib/gdk libraries.
# The AppImage runtime's default AppRun adds `usr/lib/` to LD_LIBRARY_PATH
# so those system libs are found at launch.
APPDIR="$WORK/pensine.AppDir"
install -d "$APPDIR/usr/bin"
install -d "$APPDIR/usr/share/applications"
install -d "$APPDIR/usr/share/icons/hicolor/512x512/apps"
install -d "$APPDIR/usr/share/mime/packages"

cp -r "$BUNDLE_DIR/." "$APPDIR/usr/bin/"

# linuxdeploy rejects icons that aren't at a freedesktop canonical size
# (8, 16, 22, 24, 32, 36, 42, 48, 64, 72, 96, 128, 160, 192, 256, 384,
# 480, 512). Our source `assets/app_icon.png` is 1024x1024 — reuse the
# 512x512 variant flutter_launcher_icons already generated under the
# macOS asset catalog. Cross-platform-folder but it's the same byte
# stream: pubspec.yaml's flutter_launcher_icons writes it from the same
# source, and regenerating via tool/generate_icon.* keeps it in sync.
ICON_512="$REPO_ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"

install -m 644 "$REPO_ROOT/linux/packaging/pensine.desktop" \
  "$APPDIR/usr/share/applications/pensine.desktop"
install -m 644 "$REPO_ROOT/linux/packaging/pensine-mime.xml" \
  "$APPDIR/usr/share/mime/packages/pensine.xml"
install -m 644 "$ICON_512" \
  "$APPDIR/usr/share/icons/hicolor/512x512/apps/pensine.png"

# --- Download tools into $WORK.
# Three separate tools:
#   linuxdeploy              — orchestrator (AppImage)
#   linuxdeploy-plugin-gtk   — pulls in GTK themes, schemas, transitive deps (bash script)
#   linuxdeploy-plugin-appimage — assembles the final .AppImage (AppImage; NOT bundled in linuxdeploy)
# `linuxdeploy --output appimage` looks up `linuxdeploy-plugin-appimage`
# on PATH at runtime — forgetting this one gives a cryptic "no plugin
# found for 'appimage'" error deep in the build.
TOOLS="$WORK/tools"
install -d "$TOOLS"
curl -sSL -o "$TOOLS/linuxdeploy" \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
curl -sSL -o "$TOOLS/linuxdeploy-plugin-gtk" \
  https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh
curl -sSL -o "$TOOLS/linuxdeploy-plugin-appimage" \
  https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/releases/download/continuous/linuxdeploy-plugin-appimage-x86_64.AppImage
chmod +x "$TOOLS/linuxdeploy" "$TOOLS/linuxdeploy-plugin-gtk" "$TOOLS/linuxdeploy-plugin-appimage"

# APPIMAGE_EXTRACT_AND_RUN=1 tells the AppImage runtime to extract-and-run
# instead of mount-via-FUSE — works on systems without a usable FUSE
# setup (some container runners, hardened sandboxes). The env var
# propagates to child AppImages (the plugin-appimage we just downloaded)
# so both linuxdeploy itself and the plugin extract cleanly.
# libfuse2 still needs to be installed on the host — the AppImage's
# ELF launcher links against libfuse.so.2 at load time regardless of
# whether FUSE mount is actually used.
export APPIMAGE_EXTRACT_AND_RUN=1

# --- Build the AppImage. LDAI_OUTPUT pins the output filename;
# linuxdeploy's default embeds version/arch awkwardly.
export LDAI_OUTPUT="$OUTPUT"
export VERSION="${VERSION}-${BUILD_NUMBER}"

PATH="$TOOLS:$PATH" "$TOOLS/linuxdeploy" \
  --appdir "$APPDIR" \
  --plugin gtk \
  --desktop-file "$APPDIR/usr/share/applications/pensine.desktop" \
  --icon-file "$ICON_512" \
  --icon-filename pensine \
  --output appimage

echo "Built $OUTPUT"
