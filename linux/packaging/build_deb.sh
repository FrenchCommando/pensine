#!/usr/bin/env bash
# Packages the Flutter Linux release bundle into a .deb.
#
# Assumes `flutter build linux --release` has already produced
# build/linux/x64/release/bundle/ (binary + data + lib).
#
# Install layout (standard for Flutter Linux apps):
#   /usr/lib/pensine/                   — Flutter bundle (pensine binary + data + lib)
#   /usr/bin/pensine                    — shim symlink into /usr/lib/pensine/pensine
#   /usr/share/applications/pensine.desktop
#   /usr/share/icons/hicolor/512x512/apps/pensine.png
#   /usr/share/mime/packages/pensine.xml  — registers .pensine → application/x-pensine
#
# Usage:
#   linux/packaging/build_deb.sh <version> <build_number> <output_deb_path>
set -euo pipefail

VERSION=${1:?version required}
BUILD_NUMBER=${2:?build number required}
OUTPUT=${3:?output .deb path required}

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BUNDLE_DIR="$REPO_ROOT/build/linux/x64/release/bundle"
if [ ! -d "$BUNDLE_DIR" ]; then
  echo "Bundle not found at $BUNDLE_DIR — run 'flutter build linux --release' first" >&2
  exit 1
fi

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

# --- Filesystem tree under $STAGE (what dpkg-deb will pack).
install -d "$STAGE/DEBIAN"
install -d "$STAGE/usr/lib/pensine"
install -d "$STAGE/usr/bin"
install -d "$STAGE/usr/share/applications"
install -d "$STAGE/usr/share/icons/hicolor/512x512/apps"
install -d "$STAGE/usr/share/mime/packages"

cp -r "$BUNDLE_DIR/." "$STAGE/usr/lib/pensine/"
ln -sf /usr/lib/pensine/pensine "$STAGE/usr/bin/pensine"

install -m 644 "$REPO_ROOT/linux/packaging/pensine.desktop" \
  "$STAGE/usr/share/applications/pensine.desktop"
install -m 644 "$REPO_ROOT/linux/packaging/pensine-mime.xml" \
  "$STAGE/usr/share/mime/packages/pensine.xml"
# Reuse the 512x512 variant flutter_launcher_icons generates for macOS
# (same source, same byte stream; regenerating via tool/generate_icon.*
# keeps it in sync). Matches the hicolor/512x512 directory name, so
# desktop environments that trust the directory name render crisply.
install -m 644 "$REPO_ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png" \
  "$STAGE/usr/share/icons/hicolor/512x512/apps/pensine.png"

# --- Installed-Size: KB, excluding DEBIAN/. dpkg-deb's default is correct
# but Lintian warns if the field is missing, so compute it explicitly.
INSTALLED_SIZE=$(du -sk --exclude=DEBIAN "$STAGE" | awk '{print $1}')

cat > "$STAGE/DEBIAN/control" <<EOF
Package: pensine
Version: ${VERSION}-${BUILD_NUMBER}
Section: utils
Priority: optional
Architecture: amd64
Installed-Size: ${INSTALLED_SIZE}
Depends: libgtk-3-0, libglib2.0-0, libstdc++6, libc6
Maintainer: Martial Ren <martialren@gmail.com>
Homepage: https://frenchcommando.github.io/pensine/site/
Description: A fun, visual notes app where ideas float as marbles.
 Pensine is a multi-board notes app with thoughts, to-do lists,
 flashcards and step trackers. Local-only storage, no account.
EOF

# Update icon/MIME/desktop caches on install+uninstall so the app shows up
# in the launcher and .pensine files get the right MIME type without
# requiring a re-login.
cat > "$STAGE/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ -x /usr/bin/update-desktop-database ]; then
  update-desktop-database -q /usr/share/applications || true
fi
if [ -x /usr/bin/update-mime-database ]; then
  update-mime-database /usr/share/mime || true
fi
if [ -x /usr/bin/gtk-update-icon-cache ]; then
  gtk-update-icon-cache -q /usr/share/icons/hicolor || true
fi
EOF
chmod 755 "$STAGE/DEBIAN/postinst"

cat > "$STAGE/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
if [ -x /usr/bin/update-desktop-database ]; then
  update-desktop-database -q /usr/share/applications || true
fi
if [ -x /usr/bin/update-mime-database ]; then
  update-mime-database /usr/share/mime || true
fi
if [ -x /usr/bin/gtk-update-icon-cache ]; then
  gtk-update-icon-cache -q /usr/share/icons/hicolor || true
fi
EOF
chmod 755 "$STAGE/DEBIAN/postrm"

# --fakeroot avoids the requirement that root owns every staged file.
dpkg-deb --root-owner-group --build "$STAGE" "$OUTPUT"
echo "Built $OUTPUT"
