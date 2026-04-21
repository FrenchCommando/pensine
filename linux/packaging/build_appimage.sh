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

# --- AppDir layout expected by linuxdeploy.
APPDIR="$WORK/pensine.AppDir"
install -d "$APPDIR/usr/bin"
install -d "$APPDIR/usr/lib/pensine"
install -d "$APPDIR/usr/share/applications"
install -d "$APPDIR/usr/share/icons/hicolor/512x512/apps"
install -d "$APPDIR/usr/share/mime/packages"

cp -r "$BUNDLE_DIR/." "$APPDIR/usr/lib/pensine/"
# `Exec=pensine` in the .desktop expects $PATH — AppImage runtime puts
# AppDir/usr/bin on PATH, so a thin wrapper there starts the real binary
# from /usr/lib/pensine/ where its data/ and lib/ sit.
cat > "$APPDIR/usr/bin/pensine" <<'EOF'
#!/usr/bin/env bash
DIR="$(dirname "$(readlink -f "$0")")"
exec "$DIR/../lib/pensine/pensine" "$@"
EOF
chmod 755 "$APPDIR/usr/bin/pensine"

install -m 644 "$REPO_ROOT/linux/packaging/pensine.desktop" \
  "$APPDIR/usr/share/applications/pensine.desktop"
install -m 644 "$REPO_ROOT/linux/packaging/pensine-mime.xml" \
  "$APPDIR/usr/share/mime/packages/pensine.xml"
install -m 644 "$REPO_ROOT/assets/app_icon.png" \
  "$APPDIR/usr/share/icons/hicolor/512x512/apps/pensine.png"

# --- Download linuxdeploy + GTK plugin into $WORK.
TOOLS="$WORK/tools"
install -d "$TOOLS"
curl -sSL -o "$TOOLS/linuxdeploy" \
  https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
curl -sSL -o "$TOOLS/linuxdeploy-plugin-gtk" \
  https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh
chmod +x "$TOOLS/linuxdeploy" "$TOOLS/linuxdeploy-plugin-gtk"

# Some GHA runners have FUSE disabled; extract the linuxdeploy AppImage
# and run it directly to avoid the "please install fuse" error.
(cd "$TOOLS" && ./linuxdeploy --appimage-extract >/dev/null)
LDEPLOY="$TOOLS/squashfs-root/AppRun"

# --- Build the AppImage. LDAI_OUTPUT pins the output filename;
# linuxdeploy's default embeds version/arch awkwardly.
export LDAI_OUTPUT="$OUTPUT"
export VERSION="${VERSION}-${BUILD_NUMBER}"

PATH="$TOOLS:$PATH" "$LDEPLOY" \
  --appdir "$APPDIR" \
  --plugin gtk \
  --desktop-file "$APPDIR/usr/share/applications/pensine.desktop" \
  --icon-file "$REPO_ROOT/assets/app_icon.png" \
  --icon-filename pensine \
  --output appimage

echo "Built $OUTPUT"
