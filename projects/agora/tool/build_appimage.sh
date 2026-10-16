#!/usr/bin/env bash
# Package Agora as a single-file AppImage.
#
# The Flutter bundle is already self-contained (its RPATH is $ORIGIN/lib), so
# packaging is: copy the bundle into an AppDir, drop in the desktop entry,
# metainfo and icon, and hand the directory to appimagetool.
set -euo pipefail

# A `pip install --user` leaves console-script shims in ~/.local/bin that shadow
# working system binaries. After a Python upgrade they keep resolving on PATH but
# die with "ModuleNotFoundError", which surfaces as a confusing cmake traceback
# from `flutter build linux`. Prefer a binary that actually runs over one that
# merely resolves, and say so rather than failing silently.
for tool in cmake ninja; do
  if command -v "$tool" >/dev/null 2>&1 && ! "$tool" --version >/dev/null 2>&1; then
    if [ -x "/usr/bin/$tool" ] && /usr/bin/"$tool" --version >/dev/null 2>&1; then
      echo "note: '$tool' on PATH is broken (stale user shim); using /usr/bin/$tool" >&2
      PATH="/usr/bin:$PATH"
      export PATH
    else
      echo "'$tool' on PATH does not run and /usr/bin/$tool is not usable" >&2
      exit 1
    fi
  fi
done

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
# appimagetool is itself an AppImage and normally runs from a FUSE mount, which
# containers and hardened sessions deny ("mount failed: Operation not permitted").
# The standard escape hatch runs it from a self-extracted copy instead.
if ! ARCH="$ARCH" appimagetool --no-appstream "$APPDIR" "$OUT"; then
  echo "==> appimagetool failed (no usable FUSE?); retrying with APPIMAGE_EXTRACT_AND_RUN=1"
  ARCH="$ARCH" APPIMAGE_EXTRACT_AND_RUN=1 appimagetool --no-appstream "$APPDIR" "$OUT"
fi

# A portable bundle alongside the AppImage. An AppImage type-2 mounts itself
# through FUSE, and on systems where that is unavailable — Ubuntu 24.04 ships
# kernel.apparmor_restrict_unprivileged_userns=1, containers deny the mount, and
# NoNewPrivs=1 nullifies fusermount's setuid bit — the single-file artifact
# cannot start at all. The tarball has no runtime dependency beyond the libraries
# already bundled next to the binary (the bundle's RPATH is $ORIGIN/lib), so it
# runs anywhere the AppImage would have.
PORTABLE="build/${BINARY_NAME}-${VERSION}-${ARCH}"
TARBALL="${PORTABLE}.tar.gz"
rm -rf "$PORTABLE" "$TARBALL"
cp -r "$BUNDLE" "$PORTABLE"
tar -czf "$TARBALL" -C build "$(basename "$PORTABLE")"
rm -rf "$PORTABLE"

echo
echo "built $OUT"
ls -lh "$OUT" "$TARBALL"
echo
echo "Run it:"
echo "  ./$(basename "$OUT")"
echo "      needs FUSE; if it prints 'Cannot mount AppImage', use one of:"
echo "  APPIMAGE_EXTRACT_AND_RUN=1 ./$(basename "$OUT")"
echo "  tar -xzf $(basename "$TARBALL") && ./$(basename "$PORTABLE")/$(basename "$BINARY_NAME")"
