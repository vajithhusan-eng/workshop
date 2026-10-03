#!/usr/bin/env bash
# Package Agora as a single-file AppImage.
#
# The Flutter bundle is already self-contained (its RPATH is $ORIGIN/lib), so
# packaging is: copy the bundle into an AppDir, drop in the desktop entry,
# metainfo and icon, and hand the directory to appimagetool.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
BINARY_NAME="agora"
RES="linux/runner/resources"
BUNDLE="build/linux/x64/release/bundle"
APPDIR="build/linux/x64/release/AppDir"
OUT_DIR="build"

if ! command -v appimagetool >/dev/null 2>&1; then
  echo "appimagetool not found on PATH." >&2
  echo "Install it from https://github.com/AppImage/AppImageKit/releases" >&2
  exit 1
fi

if [ "${1:-}" != "--skip-build" ]; then
  echo "==> flutter build linux --release"
  flutter build linux --release
fi

if [ ! -x "$BUNDLE/$BINARY_NAME" ]; then
  echo "no built bundle at $BUNDLE/$BINARY_NAME" >&2
  exit 1
fi

echo "==> assembling AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/share/metainfo" "$APPDIR/usr/share/icons/hicolor/512x512/apps"
cp -a "$BUNDLE/." "$APPDIR/"

install -m 0755 "$RES/AppRun" "$APPDIR/AppRun"
install -m 0644 "$RES/$BINARY_NAME.desktop" "$APPDIR/$BINARY_NAME.desktop"
# AppImageKit reads the icon named by the desktop entry, from the AppDir root.
install -m 0644 "$RES/$BINARY_NAME.png" "$APPDIR/$BINARY_NAME.png"
install -m 0644 "$RES/$BINARY_NAME.png" \
  "$APPDIR/usr/share/icons/hicolor/512x512/apps/$BINARY_NAME.png"
install -m 0644 "$RES/metainfo/dev.agora.agora.metainfo.xml" \
  "$APPDIR/usr/share/metainfo/dev.agora.agora.metainfo.xml"

VERSION=$(sed -n 's/^version: *//p' pubspec.yaml | cut -d+ -f1)
ARCH=$(uname -m)
OUT="$OUT_DIR/$BINARY_NAME-$VERSION-$ARCH.AppImage"

echo "==> appimagetool"
rm -f "$OUT"
ARCH="$ARCH" appimagetool --no-appstream "$APPDIR" "$OUT"

echo
echo "built $OUT"
ls -lh "$OUT"
