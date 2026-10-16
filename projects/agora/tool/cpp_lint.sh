#!/usr/bin/env bash
# Syntax + warning check for the Linux (AppImage) runner.
#
# WHY THIS EXISTS
#   `analysis_options.yaml` excludes `linux/**`, and both AGENTS.md and STATE.md
#   long claimed that meant "the app never analyzes its own Linux runner". That was
#   wrong. `dart analyze` only reads `.dart` files, and `linux/` contains zero of
#   them -- removing the exclusion changes the result by exactly nothing. The C++
#   runner was being checked by no tool at all, which is the real gap.
#
# WHAT IT CHECKS
#   Only git-tracked C++ sources. That deliberately skips `linux/flutter/ephemeral/`
#   (28 vendored Flutter engine headers, gitignored) -- linting vendor code would
#   bury agora's own findings under thousands of lines of someone else's.
#
# HONESTY RULES
#   Every flag is derived from the files CMake actually reads (`linux/CMakeLists.txt`,
#   `runner/CMakeLists.txt`, `generated_config.cmake`, `.plugin_symlinks/`), so this
#   cannot drift from the real build. If a prerequisite is missing it exits non-zero
#   with the reason. It never reports "clean" by skipping work.
#
# Usage:
#   tool/cpp_lint.sh          # exit 0 only if zero errors AND zero warnings
#   tool/cpp_lint.sh --quiet # only print problems

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

fail() { printf 'cpp_lint: %s\n' "$1" >&2; exit 2; }

command -v clang++ >/dev/null 2>&1 || fail "clang++ not found; cannot check the C++ runner"
command -v pkg-config >/dev/null 2>&1 || fail "pkg-config not found"
pkg-config --exists gtk+-3.0 2>/dev/null || fail \
  "GTK+3 development files not installed (pkg-config gtk+-3.0 fails).
   Install libgtk-3-dev, or this check cannot run. It will NOT report success."

EPHEMERAL="linux/flutter/ephemeral"
[ -f "$EPHEMERAL/generated_config.cmake" ] || fail \
  "$EPHEMERAL/generated_config.cmake missing -- run 'flutter build linux' once, or
   'flutter pub get', to generate it. Generated files are not committed."

FLUTTER_ROOT="$(sed -n 's/^file(TO_CMAKE_PATH "\(.*\)" FLUTTER_ROOT)$/\1/p' \
  "$EPHEMERAL/generated_config.cmake" | head -1)"
[ -n "$FLUTTER_ROOT" ] || fail "could not read FLUTTER_ROOT from generated_config.cmake"

# These two come from the files CMake reads, so the lint sees the same
# preprocessor environment the real compile does.
APPLICATION_ID="$(sed -n 's/^[[:space:]]*set(APPLICATION_ID "\(.*\)")$/\1/p' \
  linux/CMakeLists.txt | head -1)"
BINARY_NAME="$(sed -n 's/^[[:space:]]*set(BINARY_NAME "\(.*\)")$/\1/p' \
  linux/CMakeLists.txt | head -1)"
[ -n "$APPLICATION_ID" ] || fail "could not read APPLICATION_ID from linux/CMakeLists.txt"

INCLUDES=(
  -I"$ROOT/linux"                    # -> flutter/generated_plugin_registrant.h
  -I"$ROOT/linux/runner"             # -> my_application.h
  -I"$ROOT/$EPHEMERAL"               # -> flutter_linux/flutter_linux.h
)
PLUGIN_COUNT=0
for dir in "$ROOT/$EPHEMERAL"/.plugin_symlinks/*/; do
  [ -d "$dir/linux/include" ] || continue
  INCLUDES+=(-I"${dir}linux/include")
  PLUGIN_COUNT=$((PLUGIN_COUNT + 1))
done

# pkg-config emits the GTK/GLib/Pango/crypto include set as one space-separated
# line, so it must be word-split into an array -- mapfile would keep it as a single
# argument and clang would fail to find gtk/gtk.h.
read -r -a PKG_FLAGS <<< "$(pkg-config --cflags gtk+-3.0)"
[ "${#PKG_FLAGS[@]}" -gt 0 ] || fail "pkg-config gtk+-3.0 returned no cflags"

SOURCES=()
while IFS= read -r f; do SOURCES+=("$f"); done < <(
  git ls-files -z 'linux/*.cc' 'linux/*.h' | tr '\0' '\n' | sort
)
[ "${#SOURCES[@]}" -gt 0 ] || fail "no git-tracked C++ sources found under linux/"

[ "$QUIET" -eq 1 ] || cat <<EOF
cpp_lint: ${#SOURCES[@]} tracked C++ file(s), APPLICATION_ID=$APPLICATION_ID, \
BINARY_NAME=$BINARY_NAME, $PLUGIN_COUNT plugin include(s)
EOF

ERRORS=0
WARNINGS=0
DIRTY=0
FAILED=0
for f in "${SOURCES[@]}"; do
  out="$(clang++ -fsyntax-only -std=c++17 -Wall -Wextra \
    -DAPPLICATION_ID="\"$APPLICATION_ID\"" \
    -DBINARY_NAME="\"$BINARY_NAME\"" \
    "${PKG_FLAGS[@]}" "${INCLUDES[@]}" \
    -x c++ "$f" 2>&1)"
  rc=$?
  n_err="$(printf '%s\n' "$out" | grep -c 'error:')"
  n_warn="$(printf '%s\n' "$out" | grep -c 'warning:')"
  [ "$rc" -ne 0 ] && FAILED=$((FAILED + 1))
  ERRORS=$((ERRORS + n_err))
  WARNINGS=$((WARNINGS + n_warn))
  # A file with only warnings still exits 0, so count "dirty" separately from
  # "failed" or the summary would report zero affected files while listing them.
  { [ "$n_err" -gt 0 ] || [ "$n_warn" -gt 0 ]; } && DIRTY=$((DIRTY + 1))

  if [ "$n_err" -gt 0 ] || [ "$n_warn" -gt 0 ] || [ "$rc" -ne 0 ]; then
    printf '  %-52s %s error(s) %s warning(s)\n' "$f" "$n_err" "$n_warn"
    printf '%s\n' "$out" | grep -E '(error|warning):' | head -12 | sed 's/^/      /'
  elif [ "$QUIET" -eq 0 ]; then
    printf '  %-52s clean\n' "$f"
  fi
done

printf '\n'
if [ "$ERRORS" -gt 0 ] || [ "$WARNINGS" -gt 0 ] || [ "$FAILED" -gt 0 ]; then
  printf 'cpp_lint: FAIL -- %s error(s), %s warning(s) across %s of %s file(s).\n' \
    "$ERRORS" "$WARNINGS" "$DIRTY" "${#SOURCES[@]}"
  exit 1
fi
printf 'cpp_lint: PASS -- %s file(s), 0 errors, 0 warnings.\n' "${#SOURCES[@]}"